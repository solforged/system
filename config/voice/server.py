#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12,<3.14"
# dependencies = ["parakeet-mlx>=0.7,<0.8", "numpy"]
# ///
"""Local speech-to-text server for push-to-talk dictation.

POST /transcribe takes a WAV body and answers {"text", "raw", "ms", "clip"};
with ?partial=1 it transcribes a recording still in progress, without keeping
the clip or logging it. GET /health names the loaded model.

Run it as `server.py [--config PATH]`; settings come from PATH (default
$XDG_CONFIG_HOME/voice/config.toml) and reload when the file changes, except
host and port, which apply at startup. Recent clips and their transcripts stay in $XDG_CACHE_HOME/voice/clips
so bench.py can compare engines on real speech.
"""

import argparse
import io
import json
import os
import re
import sys
import time
import tomllib
import wave
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

import mlx.core as mx
import numpy as np
from huggingface_hub import snapshot_download
from huggingface_hub.errors import LocalEntryNotFoundError
from parakeet_mlx import from_pretrained
from parakeet_mlx.audio import get_logmel
from parakeet_mlx.boost import lift, words
from parakeet_mlx.parakeet import Beam, DecodingConfig, Greedy

HOME = Path.home()
DEFAULT_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "voice/config.toml"
CLIPS = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "voice/clips"
KEEP_CLIPS = 300
# Longer recordings are decoded in overlapping chunks to bound memory.
CHUNK_SECONDS = 120.0

DEFAULTS = {
    "host": "127.0.0.1",
    "port": 8178,
    "model": "mlx-community/parakeet-tdt-0.6b-v3",
    "beam_size": 5,
    "boost_weight": 4.0,
    "boost": [],
    "replace": {},
    "names": [],
    # Parakeet's own register: capitalised sentences that end in a full stop.
    "style": {"lowercase_start": False, "final_period": True},
}

# A transcript's first word when it is plainly capitalised, as Parakeet starts
# every sentence. "I", acronyms and mixed case ("P99", "GitHub") never match.
FIRST_WORD = re.compile(r"^([A-Z][a-z]+)(?=[^\w-]|$)")
FINAL_PERIOD = re.compile(r"(?<!\.)\.$")


def load_dictionary() -> frozenset[str]:
    """Lowercase English words, to tell "Tell" (a word) from "Omarchy" (a name)."""
    try:
        with open("/usr/share/dict/words") as words:
            return frozenset(word.strip() for word in words if word.strip().islower())
    except OSError:
        return frozenset()


DICTIONARY = load_dictionary()


def ordinary(word: str) -> bool:
    """Whether a word is in the dictionary, which lists "run" but not "running"."""
    word = word.lower()
    stems = {word, word.removesuffix("s"), word.removesuffix("es"), word.removesuffix("ed"), word.removesuffix("d")}
    if word.endswith("ing"):
        stem = word.removesuffix("ing")
        stems |= {stem, stem + "e", stem[:-1]}  # "making", "running"
    if word.endswith("ies"):
        stems.add(word.removesuffix("ies") + "y")
    return any(stem in DICTIONARY for stem in stems)


def local_model(repo: str) -> str:
    """The cached copy of a Hugging Face model, downloaded only when missing, so
    a restart needs no network."""
    try:
        return snapshot_download(repo, local_files_only=True)
    except LocalEntryNotFoundError:
        return snapshot_download(repo)


def log(*parts):
    print(time.strftime("%H:%M:%S"), *parts, file=sys.stderr, flush=True)


class Engine:
    """The loaded model and the decoding settings derived from the config file."""

    def __init__(self, config: Path = DEFAULT_CONFIG):
        self.config = config
        self.mtime = None
        self.settings = dict(DEFAULTS)
        self.model = None
        self.model_name = None
        self.decoding = DecodingConfig()
        self.replacements = []
        self.names = set()

    def refresh(self):
        try:
            mtime = self.config.stat().st_mtime
        except FileNotFoundError:
            mtime = 0
        if mtime == self.mtime and self.model is not None:
            return
        self.mtime = mtime
        settings = dict(DEFAULTS)
        if mtime:
            try:
                settings |= tomllib.loads(self.config.read_text())
            except (OSError, tomllib.TOMLDecodeError) as error:
                log(f"keeping previous settings; {self.config} is unreadable: {error}")
                return
        self.settings = settings
        if settings["model"] != self.model_name:
            started = time.perf_counter()
            self.model = from_pretrained(local_model(settings["model"]))
            self.model_name = settings["model"]
            log(f"loaded {self.model_name} in {time.perf_counter() - started:.1f}s")
        boost = {word: float(settings["boost_weight"]) for word in settings["boost"] if word}
        if settings["beam_size"] > 1:
            booster = {"booster": lift(words(boost), self.model.vocabulary)} if boost else {}
            self.decoding = DecodingConfig(decoding=Beam(beam_size=settings["beam_size"], **booster))
        else:
            self.decoding = DecodingConfig(decoding=Greedy())
        # Whole-word, case-insensitive fixes for misheard names, then each name's
        # own spelling, so "Omp" at the start of a sentence becomes "omp".
        self.names = set(settings["names"]) | set(settings["replace"].values())
        pairs = list(settings["replace"].items()) + [(name, name) for name in sorted(self.names)]
        self.replacements = [
            (re.compile(rf"(?<![\w-]){re.escape(wrong)}(?![\w-])", re.IGNORECASE), right) for wrong, right in pairs
        ]
        log(f"settings: beam {settings['beam_size']}, {len(boost)} boosted, {len(self.replacements)} replacements")

    def transcribe(self, audio: mx.array) -> str:
        rate = self.model.preprocessor_config.sample_rate
        if len(audio) < self.model.preprocessor_config.hop_length:
            return ""
        if len(audio) <= CHUNK_SECONDS * rate:
            return self.model.generate(
                get_logmel(audio, self.model.preprocessor_config), decoding_config=self.decoding
            )[0].text
        # Rare: save to a temporary file and let parakeet chunk it.
        path = CLIPS / "long.wav"
        write_wav(path, audio, rate)
        try:
            return self.model.transcribe(path, decoding_config=self.decoding, chunk_duration=CHUNK_SECONDS).text
        finally:
            path.unlink(missing_ok=True)

    def fix(self, text: str) -> str:
        for pattern, right in self.replacements:
            text = pattern.sub(right, text)
        style = DEFAULTS["style"] | self.settings["style"]
        if style["lowercase_start"]:
            first = FIRST_WORD.match(text)
            if first and first[1] not in self.names and ordinary(first[1]):
                text = first[1].lower() + text[first.end() :]
        if not style["final_period"]:
            text = FINAL_PERIOD.sub("", text)
        return text


def read_audio(data: bytes, rate: int) -> mx.array:
    """Decode 16-bit mono WAV at the model rate directly, anything else through
    ffmpeg. Returns float32, which parakeet's mel code expects."""
    try:
        with wave.open(io.BytesIO(data)) as clip:
            if clip.getsampwidth() == 2 and clip.getnchannels() == 1 and clip.getframerate() == rate:
                samples = np.frombuffer(clip.readframes(clip.getnframes()), dtype="<i2")
                return mx.array(samples.astype(np.float32) / 32768.0)
    except (wave.Error, EOFError):
        pass
    from parakeet_mlx.audio import load_audio

    path = CLIPS / "incoming"
    path.write_bytes(data)
    try:
        return load_audio(path, rate)
    finally:
        path.unlink(missing_ok=True)


def write_wav(path: Path, audio: mx.array, rate: int):
    samples = (np.array(audio.astype(mx.float32)) * 32767).clip(-32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as clip:
        clip.setnchannels(1)
        clip.setsampwidth(2)
        clip.setframerate(rate)
        clip.writeframes(samples.tobytes())


def keep_clip(data: bytes, result: dict) -> str:
    stamp = time.strftime("%Y%m%d-%H%M%S") + f"-{int(time.time() * 1000) % 1000:03d}"
    (CLIPS / f"{stamp}.wav").write_bytes(data)
    (CLIPS / f"{stamp}.json").write_text(json.dumps(result, indent=2) + "\n")
    clips = sorted(CLIPS.glob("*.wav"))
    for old in clips[:-KEEP_CLIPS]:
        old.unlink(missing_ok=True)
        old.with_suffix(".json").unlink(missing_ok=True)
    return stamp


ENGINE: Engine


class Handler(BaseHTTPRequestHandler):
    def reply(self, status: int, body: dict):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {"ok": True, "model": ENGINE.model_name})
        else:
            self.reply(404, {"error": "not found"})

    def do_POST(self):
        url = urlsplit(self.path)
        if url.path != "/transcribe":
            return self.reply(404, {"error": "not found"})
        partial = parse_qs(url.query).get("partial") == ["1"]
        try:
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            started = time.perf_counter()
            ENGINE.refresh()
            audio = read_audio(body, ENGINE.model.preprocessor_config.sample_rate)
            raw = ENGINE.transcribe(audio).strip()
            text = ENGINE.fix(raw)
            ms = round((time.perf_counter() - started) * 1000)
            seconds = len(audio) / ENGINE.model.preprocessor_config.sample_rate
            result = {"text": text, "raw": raw, "ms": ms, "seconds": round(seconds, 2), "model": ENGINE.model_name}
            if not partial:
                result["clip"] = keep_clip(body, result) if raw else None
                log(f"{seconds:5.1f}s audio, {ms:4d} ms: {text}")
            self.reply(200, result)
        except Exception as error:  # noqa: BLE001 -- answer every failure instead of dropping the request
            log(f"error: {error!r}")
            self.reply(500, {"error": str(error)})

    def log_message(self, *_):
        pass


def main():
    global ENGINE
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG, help=f"settings file (default {DEFAULT_CONFIG})")
    args = parser.parse_args()
    CLIPS.mkdir(parents=True, exist_ok=True)
    ENGINE = Engine(args.config.expanduser())
    ENGINE.refresh()
    # Compile the model's kernels before the first real request.
    rate = ENGINE.model.preprocessor_config.sample_rate
    ENGINE.transcribe(mx.zeros(rate))
    # One request at a time: MLX work is serial anyway, and requests are short.
    host, port = ENGINE.settings["host"], int(ENGINE.settings["port"])
    server = HTTPServer((host, port), Handler)
    log(f"listening on {host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
