#!/usr/bin/env python3
"""Isolated Linux smoke test: toggles change on-disk Native Messaging access.
Runs a GUI instance in an empty temporary home, never touches the real profile.
Not a replacement for macOS/Windows browser installation tests.
"""
from pathlib import Path
import json
import os
import subprocess
import struct
import sys
import tempfile
import time

app = Path(sys.argv[1] if len(sys.argv) > 1 else "build-qt612/bin/GenyDL").resolve()
if not app.exists():
    raise SystemExit("Build GenyDL first")

with tempfile.TemporaryDirectory(prefix="genydl-browser-toggle-") as scratch:
    home = Path(scratch)
    runtime = home / "runtime"
    runtime.mkdir(mode=0o700)
    env = os.environ.copy()
    env.update(
        HOME=str(home),
        XDG_CONFIG_HOME=str(home / ".config"),
        XDG_DATA_HOME=str(home / ".local/share"),
        XDG_CACHE_HOME=str(home / ".cache"),
        XDG_RUNTIME_DIR=str(runtime),
        QT_QPA_PLATFORM="offscreen",
        QT_QUICK_BACKEND="software",
    )
    firefox = home / ".mozilla/native-messaging-hosts/com.genyleap.genydl.json"
    chrome = home / ".config/google-chrome/NativeMessagingHosts/com.genyleap.genydl.json"
    opera = home / ".config/opera/NativeMessagingHosts/com.genyleap.genydl.json"
    settings = home / ".config/Genyleap/GenyDL.conf"

    def launch_and_check(predicate, verify=None):
        process = subprocess.Popen(
            [str(app)], env=env, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )
        try:
            for _ in range(70):
                if process.poll() is not None:
                    raise AssertionError(
                        f"GenyDL exited with {process.returncode}: " +
                        (process.stdout.read() or b"").decode(errors="replace")[-2500:]
                    )
                if predicate():
                    time.sleep(.3)
                    if process.poll() is None:
                        if verify is not None:
                            verify()
                        return
                    raise AssertionError(f"GenyDL exited after registering native hosts: {process.returncode}")
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
    assert not opera.exists(), "Opera must be opt-in by default"
    assert not chrome.exists(), "Chromium must be opt-in by default"
    firefox_manifest = json.loads(firefox.read_text())
    assert Path(firefox_manifest["path"]).resolve() == app, "Firefox host must be the GUI executable"
    assert firefox_manifest["allowed_extensions"] == [
        "browser@genyleap.com"
    ]
    settings.parent.mkdir(parents=True, exist_ok=True)
    # QSettings on Unix stores nested keys as a backslash-escaped subkey.
    settings.write_text(
        "[browserIntegration]\nenabled\\firefox=false\nenabled\\chrome=true\n"
    )
    launch_and_check(lambda: not firefox.exists() and chrome.exists())
    manifest = json.loads(chrome.read_text())
    assert Path(manifest["path"]).resolve() == app, "Chrome host must be the GUI executable"
    assert "chrome-extension://dhmfclimdfgeemdecnghagiodcmiafdb/" in         manifest["allowed_origins"]
    settings.write_text(
        "[browserIntegration]\nenabled\\firefox=false\nenabled\\chrome=false\n"
    )
    launch_and_check(lambda: not chrome.exists() and not firefox.exists() and not opera.exists())
    settings.write_text("[browserIntegration]\nenabled\\opera=true\nenabled\\firefox=false\nenabled\\chrome=false\n")
    def check_opera_ping():
        origin = "chrome-extension://dfhcknlghpfenoedpjajifdihnokkpbh/"
        msg = json.dumps({"protocolVersion":2, "requestId":"opera-linux-smoke",
                          "type":"integration.ping","browser":"opera"}).encode()
        for _ in range(10):
            result = subprocess.run([str(app), origin], env=env,
                                    input=struct.pack("<I", len(msg)) + msg,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=6)
            if len(result.stdout) >= 4:
                size, = struct.unpack("<I", result.stdout[:4])
                assert len(result.stdout) == size + 4
                response = json.loads(result.stdout[4:])
                if response.get("ok") is True:
                    assert response["requestId"] == "opera-linux-smoke"
                    return
            time.sleep(.2)
        raise AssertionError("Opera-style native heartbeat not acknowledged")
    launch_and_check(lambda: opera.exists() and not chrome.exists() and not firefox.exists(), check_opera_ping)
    assert json.loads(opera.read_text())["allowed_origins"] == ["chrome-extension://dfhcknlghpfenoedpjajifdihnokkpbh/"]
    settings.write_text("[browserIntegration]\nenabled\\opera=false\nenabled\\firefox=false\nenabled\\chrome=false\n")
    launch_and_check(lambda: not opera.exists())
    print("Per-browser enable/disable Native Messaging smoke test passed")
