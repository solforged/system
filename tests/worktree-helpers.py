"""Exercise zsh and nu worktree helpers only in disposable repositories."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(args, cwd, env, ok=True):
    result = subprocess.run(args, cwd=cwd, env=env, capture_output=True, text=True)
    if (result.returncode == 0) != ok:
        raise AssertionError(f"{args}: {result.returncode}\n{result.stdout}\n{result.stderr}")
    return result


def test(shell):
    with tempfile.TemporaryDirectory(prefix=f"worktree-{shell}-") as temporary:
        root = Path(temporary).resolve()
        repo = root / "project"
        repo.mkdir()
        if shell == "nu":
            load = f"use '{ROOT / 'config/nushell/scripts/worktree.nu'}' *"
        else:
            load = f"source '{ROOT / 'config/zsh/config.d/functions.zsh'}'"
        commands = root / "bin"
        commands.mkdir()
        gum = commands / "gum"
        # Answers yes unless GUM_ANSWER=no.
        gum.write_text('#!/bin/sh\n[ "$GUM_ANSWER" != no ]\n')
        gum.chmod(0o755)
        env = dict(os.environ, OMP_WORKTREE_DIR=str(root / "worktrees"), PATH=f"{commands}:{os.environ['PATH']}")
        # Do not inherit an enclosing repository or its hooks/signing policy.
        for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
            env.pop(key, None)
        run(["git", "init", "-q", "-b", "main"], repo, env)
        run(["git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false",
             "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
             "commit", "--allow-empty", "-qm", "chore(test): created a fixture"], repo, env)

        def command(text, cwd=repo, ok=True, overrides=None):
            args = [shell, "-n" if shell == "nu" else "-f", "-c", f"{load}; {text}"]
            return run(args, cwd, dict(env, **(overrides or {})), ok)

        command("gd", ok=False)
        command("ga invalid", ok=False, overrides={"OMP_WORKTREE_DIR": "relative"})
        nested = repo / "nested"
        nested.mkdir()
        command("ga topic/one", nested)
        first = root / "worktrees/project--topic-one"
        assert first.is_dir()
        command("ga topic/two", first)
        second = root / "worktrees/project--topic-two"
        assert second.is_dir()
        # Even a dangling symlink must not be reused.
        (root / "worktrees/project--occupied").symlink_to(root / "missing")
        command("ga occupied", ok=False)
        dirt = second / "untracked"
        dirt.write_text("keep me")
        command("gd", second, ok=False)
        assert dirt.read_text() == "keep me"
        dirt.unlink()
        # Declining is not a failure, and keeps the worktree.
        command("gd", second, overrides={"GUM_ANSWER": "no"})
        assert second.is_dir()
        command("gd", second)
        assert not second.exists()
        command("gd", first)
        assert not first.exists()
        print(f"{shell}: canonical paths, collisions, declining and safe removal passed")


if __name__ == "__main__":
    for shell in ("zsh", "nu"):
        test(shell)
