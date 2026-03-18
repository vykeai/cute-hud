"""
cute-hud Python helper — spawn and control the floating HUD from Python.

Usage:
    from cute_hud import CuteHUD

    with CuteHUD(mode="warning", title="SIMEMU", countdown=3) as hud:
        hud.update(badge="TAPPING", action="tap — Tap 250,500")
        do_work()

    # Blocking mode (covers screen like Xcode automation):
    with CuteHUD(mode="critical", title="DO NOT TOUCH", blocking=True) as hud:
        run_maestro_flow()
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import subprocess
import threading
from pathlib import Path
from typing import Any

log = logging.getLogger("cute-hud")

# Search order for the cute-hud binary
_SEARCH_PATHS = [
    "cute-hud",  # on PATH
    str(Path(__file__).parent.parent / ".build" / "release" / "cute-hud"),
    str(Path.home() / "dev" / "cute-hud" / ".build" / "release" / "cute-hud"),
]


def _find_binary() -> str | None:
    for candidate in _SEARCH_PATHS:
        if "/" in candidate:
            if Path(candidate).exists():
                return candidate
        else:
            found = shutil.which(candidate)
            if found:
                return found
    return None


class CuteHUD:
    """Context manager that spawns cute-hud and provides a send() API."""

    def __init__(
        self,
        mode: str = "info",
        title: str = "",
        badge: str = "",
        action: str = "",
        detail: str = "",
        task: str = "",
        countdown: int | None = None,
        blocking: bool = False,
        **extra: Any,
    ):
        self._initial = {
            "mode": mode,
            "title": title,
            "badge": badge,
            "action": action,
            "detail": detail,
            "task": task,
            "blocking": blocking,
            **extra,
        }
        if countdown is not None:
            self._initial["countdown"] = countdown
        self._proc: subprocess.Popen | None = None
        self._reader: threading.Thread | None = None
        self._ready = threading.Event()

    def __enter__(self) -> "CuteHUD":
        binary = _find_binary()
        if not binary:
            log.warning("cute-hud binary not found — HUD will not be shown")
            return self

        try:
            self._proc = subprocess.Popen(
                [binary],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1,
            )
        except (FileNotFoundError, PermissionError) as e:
            log.warning(f"Failed to start cute-hud: {e}")
            return self

        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._reader.start()

        if self._ready.wait(timeout=2.0):
            self.send(self._initial)
        else:
            log.warning("cute-hud did not become ready in time")

        return self

    def __exit__(self, exc_type: Any, exc: Any, tb: Any) -> bool:
        if self._proc:
            try:
                self.send({"mode": "idle"})
            except Exception:
                pass
            self._proc.terminate()
            try:
                self._proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self._proc.kill()
            self._proc = None
        return False

    def send(self, obj: dict[str, Any]) -> None:
        """Send a JSON message to cute-hud."""
        if not self._proc or self._proc.poll() is not None:
            return
        try:
            self._proc.stdin.write(json.dumps(obj) + "\n")  # type: ignore[union-attr]
            self._proc.stdin.flush()  # type: ignore[union-attr]
        except (BrokenPipeError, OSError):
            pass

    def update(self, **fields: Any) -> None:
        """Update specific fields on the HUD (merges with current state)."""
        self.send({"mode": self._initial.get("mode", "info"), **fields})

    def hide(self) -> None:
        self.send({"command": "hide"})

    def show(self) -> None:
        self.send({"command": "show"})

    def sound(self, name: str = "start") -> None:
        self.send({"command": "sound", "name": name})

    def _read_loop(self) -> None:
        if not self._proc or not self._proc.stdout:
            return
        for line in self._proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("event") == "ready":
                self._ready.set()
