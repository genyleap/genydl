# GenyDL browser integration: Firefox and Chrome

## Release scope

GenyDL currently exposes two browser integrations in **Configuration → Browsers**:

| Browser | Installation | Native Messaging | Default capture |
| --- | --- | --- | --- |
| Mozilla Firefox | [Official AMO listing](https://addons.mozilla.org/en-US/firefox/addon/genydl-download-with-genydl/) | Supported via GenyDL itself | Manual |
| Google Chrome | Load unpacked from `<build>/browser-extensions/chrome` until Chrome Store approval | Supported via GenyDL itself | Manual |

Both integrations can be switched on or off independently. Firefox defaults to enabled for continuity; Chrome is opt-in. An enabled switch registers the local native host, **not** the browser extension itself. The browser performs extension installation, permission grants, and extension enable/disable.

Edge, Brave, Chromium, Vivaldi and Safari are intentionally **not displayed or activated** in this release. Their existing adapters, protocol seams and configuration hooks remain available as future implementation points; they must not be advertised as tested or shipped support.

## Install steps

1. Build and launch GenyDL. The app creates the native manifest automatically on startup (or when toggled). Its `path` is the absolute path of the **main GenyDL executable**, not a second helper executable.
2. Open **Configuration → Browsers**, turn on the appropriate browser, and follow its installation action.
3. **Firefox:** choose **Install from official store** and approve installation on Mozilla Add-ons. Confirm the add-on ID is `browser@genyleap.com`.
4. **Chrome:** open `chrome://extensions`, enable **Developer mode**, select **Load unpacked**, and choose `<build>/browser-extensions/chrome`. The fixed development ID is `dhmfclimdfgeemdecnghagiodcmiafdb`. The Chrome package is `GenyDL-Chrome-extension.zip`. A published Chrome Store listing requires a separately configured verified URL and ID.
5. Keep GenyDL running while opening or restarting the extension. A successful `integration.ping` heartbeat changes its state to **Connected**. Simply locating a browser or creating its host manifest is not evidence that the extension is connected.
6. Right-click a direct HTTP(S) link and select **Download with GenyDL**. Review the desktop dialog and approve or reject.

If a user moves `GenyDL.app` or changes its installed path, use the connection repair function or restart GenyDL to re-register absolute paths.

## Single-executable native host

There is **no separate `GenyDLNativeHost` executable**. Both Firefox and Chrome native manifests point at the main `GenyDL` executable. The browser's launch arguments select a pre-GUI headless mode:

- Firefox supplies the native manifest path and its add-on ID.
- Chrome supplies its `chrome-extension://` origin.

The GenyDL entry point detects these before constructing `QApplication` or loading QML. The headless path instead uses `QCoreApplication`, reads a little-endian, 32-bit-length-prefixed JSON request from standard input, forwards the validated request to the running GUI over a private user-scoped `QLocalSocket`, and writes only a length-prefixed JSON response to standard output. Diagnostics must never be printed to stdout. User-approved download prompts can keep the native Port open while awaiting the decision. Ordinary browser pings must **not** automatically launch the GUI.

The browser validates `allowed_extensions` (Firefox) or `allowed_origins` (Chrome) in `com.genyleap.genydl.json`; no wildcard extension origins are used. The native host replies only after the desktop reports acceptance, so a rejected or unreachable desktop leaves the browser download under browser control.

## User-selected download policy

- **Manual (default):** only the right-click action sends a link; normal browser downloads stay in the browser.
- **Ask (explicit opt-in):** recognized downloads are temporarily paused, and the browser resumes them if the user cancels, the host fails, or the timeout expires.
- **Always (explicit opt-in):** eligible downloads transfer to the desktop only after a positive acknowledgment.
- **Off:** no handoff.

Ask and Always require the optional browser **downloads** permission; denial returns the extension to Manual mode. Previous automatic settings are migrated to Manual and must be opted into again. Chrome and Firefox may differ in their `downloads` API permission flows. Authenticated downloads, POST requests, session cookies, Referer and other browser-only context cannot currently be recreated reliably; do not promise those handoffs will work.

## Future-browser architecture

Browser descriptors, host-registration templates, extension origin configuration and generic download IPC stay reusable. Adding another browser later requires enabling its descriptor, its host-registration policy, the verified extension ID/store listing, and platform-specific tests. Simply sharing a Chromium extension package is not proof of compatibility. Safari needs its own signed app-extension transport; the existing Safari design note remains future planning only.

## Verification

```sh
cmake --build <build> --target GenyDL genydl_browser_bridge_tests browser-extension-zip
ctest --test-dir <build> --output-on-failure
node tests/browser-extension-smoke.cjs
node tests/browser-options-smoke.cjs
node tests/browser-setup-smoke.cjs
```

The native integration tests launch **GenyDL itself** with Firefox and Chrome-style arguments and validate the length-prefixed protocol and the approval flow. On macOS also test installation through the Mozilla store, browser heartbeat, GUI cold start on a right-click, 3+ simultaneous prompts, Ask/Always permissions, rejection and browser recovery.

**Verification limitations:** Qt 6.12/macOS desktop runtime, real Firefox AMO round-trip, and Chrome user-installation behavior require testing on machines with those browsers. The code and store link alone do not establish that the end-to-end experience passed.
