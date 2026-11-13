#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12,<3.14"
# dependencies = ["parakeet-mlx>=0.7,<0.8", "numpy", "mlx-whisper"]
# ///
"""Replay recent dictation clips through several speech-to-text setups.

The server keeps each clip with what it typed. This prints, per clip, that
transcript, what the current config makes of it now, and the raw output of
the alternatives (before [replace] fixes, to show what each gets wrong), then
the median latency of each, so settings can be judged on real speech. Usage:

    bench.py [N] [--config PATH]    the N most recent clips (default 10)
"""

import argparse
import statistics
import sys
import time
from pathlib import Path

# Import server.py from beside this file without leaving __pycache__ in the repo.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import mlx_whisper
import numpy as np
from parakeet_mlx import from_pretrained
from parakeet_mlx.boost import lift, words
from parakeet_mlx.parakeet import Beam, DecodingConfig, Greedy

import server

WHISPER = "mlx-community/whisper-large-v3-turbo"


def main():
    parser = argparse.ArgumentParser(description="Replay recent dictation clips through each speech-to-text setup.")
    parser.add_argument("count", nargs="?", type=int, default=10, help="how many recent clips (default 10)")
    parser.add_argument("--config", type=Path, default=server.DEFAULT_CONFIG, help="the server's settings file")
    args = parser.parse_args()
    count = args.count
    clips = sorted(server.CLIPS.glob("*.wav"))[-count:]
    if not clips:
        sys.exit(f"No clips in {server.CLIPS} yet; dictate something first.")

    current = server.Engine(args.config.expanduser())
    current.refresh()
    models = {}

    boost = {word: float(current.settings["boost_weight"]) for word in current.settings["boost"]}

    def parakeet(name, boosted=False):
        def run(audio):
            if name not in models:
                models[name] = from_pretrained(server.local_model(name))
            model = models[name]
            decoding = Greedy()
            if boosted:
                decoding = Beam(beam_size=5, booster=lift(words(boost), model.vocabulary))
            mel = server.get_logmel(audio, model.preprocessor_config)
            return model.generate(mel, decoding_config=DecodingConfig(decoding=decoding))[0].text

        return run

    prompt = ", ".join(boost)

    def whisper(initial_prompt):
        def run(audio):
            return mlx_whisper.transcribe(
                np.array(audio), path_or_hf_repo=WHISPER, language="en", initial_prompt=initial_prompt
            )["text"]

        return run

    setups = {
        "config": lambda audio: current.fix(current.transcribe(audio)),
        "v3": parakeet("mlx-community/parakeet-tdt-0.6b-v3"),
        "v3+boost": parakeet("mlx-community/parakeet-tdt-0.6b-v3", boosted=True),
        "v2": parakeet("mlx-community/parakeet-tdt-0.6b-v2"),
        "whisper+names": whisper(prompt or None),
    }
    rate = current.model.preprocessor_config.sample_rate
    audios = [server.read_audio(clip.read_bytes(), rate) for clip in clips]
    # One setup at a time over every clip: alternating models per clip evicts
    # each other's GPU caches and inflates every timing.
    results = {}
    for label, run in setups.items():
        run(audios[0])
        for clip, audio in zip(clips, audios):
            started = time.perf_counter()
            text = run(audio).strip()
            results[label, clip] = (text, (time.perf_counter() - started) * 1000)

    for clip, audio in zip(clips, audios):
        meta = clip.with_suffix(".json")
        typed = server.json.loads(meta.read_text())["text"] if meta.exists() else "?"
        print(f"\n{clip.stem}  ({len(audio) / rate:.1f}s)\n  {'typed':12} {typed}")
        for label in setups:
            text, ms = results[label, clip]
            print(f"  {label:12} {text}  [{ms:.0f} ms]")
    print(
        "\nmedian latency: "
        + ", ".join(
            f"{label} {statistics.median(results[label, clip][1] for clip in clips):.0f} ms" for label in setups
        )
    )


if __name__ == "__main__":
    main()
