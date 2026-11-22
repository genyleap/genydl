#!/usr/bin/env python3
"""Isolated Linux smoke test: toggles change on-disk Native Messaging access.
Runs a GUI instance in an empty temporary home, never touches the real profile.
Not a replacement for macOS/Windows browser installation tests.
"""
from pathlib import Path
import json
import os
import subprocess
import tempfile
import time

app = Path("build-qt612/bin/GenyDL").resolve()
if not app.exists():
    raise SystemExit("Build GenyDL first")

with tempfile.TemporaryDirectory(prefix="genydl-browser-toggle-") as scratch:
    home = Path(scratch)
    env = os.environ.copy()
    env.update(
        HOME=str(home),
        XDG_CONFIG_HOME=str(home / ".config"),
        XDG_DATA_HOME=str(home / ".local/share"),
        QT_QPA_PLATFORM="offscreen",
        QT_QUICK_BACKEND="software",
    )
    firefox = home / ".mozilla/native-messaging-hosts/com.genyleap.genydl.json"
    chrome = home / ".config/google-chrome/NativeMessagingHosts/com.genyleap.genydl.json"
    settings = home / ".config/Genyleap/GenyDL.conf"

    def launch_and_check(predicate):
        process = subprocess.Popen(
            [str(app)], env=env, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )
        try:
            for _ in range(70):
                if predicate():
                    return
                if process.poll() is not None:
                    raise AssertionError(
                        f"GenyDL exited with {process.returncode}: " +
                        (process.stdout.read() or b"").decode(errors="replace")[-2500:]
                    )
                time.sleep(.15)
            raise AssertionError("Native host setup never reached desired state")
        finally:
            process.terminate()
            try:
                process.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate()

    launch_and_check(lambda: firefox.is_file())
    assert not chrome.exists(), "Chromium must be opt-in by default"
    assert json.loads(firefox.read_text())["allowed_extensions"] == [
        "download-links@genydl.genyleap.com"
    ]
    settings.parent.mkdir(parents=True, exist_ok=True)
    # QSettings on Unix stores nested keys as a backslash-escaped subkey.
    settings.write_text(
        "[browserIntegration]\nenabled\\firefox=false\nenabled\\chrome=true\n"
    )
    launch_and_check(lambda: not firefox.exists() and chrome.exists())
    manifest = json.loads(chrome.read_text())
    assert "chrome-extension://dhmfclimdfgeemdecnghagiodcmiafdb/" in         manifest["allowed_origins"]
    settings.write_text(
        "[browserIntegration]\nenabled\\firefox=false\nenabled\\chrome=false\n"
    )
    launch_and_check(lambda: not chrome.exists() and not firefox.exists())
    print("Per-browser enable/disable Native Messaging smoke test passed")
