# GenyDL Browser Integration (v2 development branch)

Browser integrations are **user-controlled** and fail open. Desktop downloads
are not intercepted by default. The initial installation never attempts to
silently install browser extensions or grant permissions.

## What this branch implements

| Browser | Desktop platforms | Native host | Context menu | Optional interception |
| --- | --- | --- | --- | --- |
| Firefox | macOS, Windows, Linux | Implemented | Implemented | Implemented; request Downloads permission |
| Chrome / Chromium | macOS, Windows, Linux | Implemented | Implemented | Fixed developer extension ID; store builds require published ID |
| Edge / Brave / Vivaldi | macOS, Windows, Linux | Registration code exists | Shared Chromium extension | Fixed developer ID; browser-specific runtime tests pending |
| Safari | macOS only | **Not implemented** | Only legacy macOS Services | **Not implemented** |

The table describes code availability, not a claim of real-world testing on
all three operating systems. Firefox/macOS was tested by a user with a prior
iteration. Qt 6.12/Clang/Linux and test harnesses validate this branch.
Safari's signed app extension, store publication, Windows runtime testing,
sandboxed Linux packages, and broad browser compatibility remain outstanding.

### Download policies

- **Manual (default)**: ordinary downloads stay inside the browser. Right
  click a HTTP(S) link and select **Download with GenyDL**; the desktop Add
  Download dialog opens for approval.
- **Ask**: recognized HTTP(S) downloads (or all HTTP(S) if the user selects
  that advanced scope) pause in the browser while the desktop Add dialog awaits
  explicit approval. Add transfers control; Cancel resumes the browser.
- **Always**: **explicit opt-in only**. Eligible downloads pause, are enqueued
  in GenyDL without the dialog, and are cancelled in the browser only after
  the desktop explicitly confirms the new task.
- **Disabled**: no browser capture, including context-menu handoffs.

For first-time users the stored mode is Manual. Legacy Smart/Automatic
settings are migrated to Manual, requiring renewed opt-in. Switching to
Ask/Always requests the optional **downloads** permission using the browser's
standard permission prompt; denial restores Manual. Returning to Manual/Off
removes that optional permission where supported. Native Messaging, context
menus, and local settings are required permissions. No website-wide host
permissions are requested.

Browser download history: after successful transfer the extension attempts
`downloads.erase({id})` to remove that particular cancelled browser entry.
The API **does not guarantee** that a temporary Paused/Cancelled row can never
flash in the browser UI.

Authenticated downloads, POST bodies, cookies, Referer, and browser session
headers are **not** transferred. Only public direct HTTP(S) links are reliable
in the current protocol. Downloads whose methods or authorization cannot
be reconstructed should remain in the browser.

## Protocol and architecture

```text
Firefox / Chromium extension
  ├── Manual: contextMenus → connectNative
  ├── Ask: pause → connectNative → Add/Cancel → cancel+erase or resume
  └── Always: pause → connectNative → enqueue ACK → cancel+erase or resume
              ↓
GenyDLNativeHost (Qt Core; framed 32-bit little-endian JSON on stdio)
              ↓
private per-user QLocalSocket endpoint (newline-delimited JSON)
              ↓
BrowserActivation (request ID validation, FIFO pending queue, timeout)
              ↓
GenyDL QML Add Download dialog → DownloadManager
```

For a prompt, the browser sends:

```json
{
  "protocolVersion": 2,
  "requestId": "unique-per-download",
  "type": "download.prompt",
  "url": "https://example.org/file.zip",
  "filename": "file.zip"
}
```

`download.request` is reserved for the explicitly enabled Always mode and
for the legacy command-line protocol. For v2 requests, `requestId` is required
and round-tripped in the native host response. Native Ports keep the Manifest
V3 service worker active while waiting. The desktop limits pending prompts
to 16, each prompt expires after 120 seconds, the browser sets a 160-second
deadline, and the native host waits at most 180 seconds. Expired or disconnected
requests fail open and release queue slots.

The Qt bridge accepts legacy v1 messages temporarily for compatibility.
Duplicate v2 request IDs are rejected while pending and, after acceptance,
retained in a bounded 256-entry recent-ID cache. Filenames are hints only:
directory components and unsafe names are never accepted as destinations.
The desktop does not display prompts until the QML window has connected.

## Build and installation

Build and run the desktop program first, so it can register per-user native
host manifests. The executable must remain at the path contained in the host
manifest (moving the app requires repairing the connection).

**Firefox development build:** load `browser-extension/manifest.json` using
`about:debugging#/runtime/this-firefox`, or unpack
`GenyDL-Firefox-extension.zip`. The fixed Firefox extension ID is
`download-links@genydl.genyleap.com`.

**Chromium development build:** use **Load unpacked** on the CMake output
directory `<build>/browser-extensions/chromium`. The Chromium package
`GenyDL-Chromium-extension.zip` uses a separate, valid MV3 background
service-worker declaration.

**User-facing setup:** open **Configuration → Browsers** and turn on
**Use** beside the desired browser. The desktop registers the appropriate
native messaging descriptor automatically and removes it when switched off.
There is **no extension ID field, registry path, or terminal step** in the
user-facing interface. Firefox remains enabled by default when upgrading
existing installations; Chrome-family browsers are opt-in.

The Chromium developer package now includes a fixed public `manifest.key`
and therefore uses the stable unpacked extension ID
`dhmfclimdfgeemdecnghagiodcmiafdb`. This ID is registered by GenyDL without
copy/paste. The public key is not a secret and does not authenticate the
extension; browser-provided Native Messaging origin checks still apply.
Official store builds can specify their own published extension IDs at
compile time. This avoids trusting arbitrary IDs supplied by websites.

**Important:** switching on a browser enables only GenyDL's native bridge.
It does not silently install or enable an extension. The browser's add-on
installation and permission prompts remain controlled by the browser.
**Open extensions** opens the selected browser's extension manager.
The test version has no verified public store listing yet; installation
of the development extension is a one-time manual step until publication.
Never label a browser `Connected` simply because its native host exists.

On Windows, Brave and Vivaldi use the Chrome native-host registry location.
GenyDL therefore writes a shared Chrome manifest containing the explicitly
configured Chrome, Brave and Vivaldi IDs. Microsoft Edge and Chromium also
have their own native-host entries; Edge can fall back to the Chrome entry.
No wildcard extension origins are allowed.

For store builds, published IDs can also be configured individually with:
- `GENYDL_CHROME_EXTENSION_ID`
- `GENYDL_EDGE_EXTENSION_ID`
- `GENYDL_BRAVE_EXTENSION_ID`
- `GENYDL_VIVALDI_EXTENSION_ID`
- `GENYDL_CHROMIUM_EXTENSION_ID` (legacy shared value)

The browser registration system does not use wildcards. Brave and Vivaldi
can reuse the Chrome Store ID if they install that version of the extension.
Firefox has a separate `allowed_extensions` entry.

The **Browsers** panel says *Allowed by GenyDL* when the relevant bridge
is enabled and installed. It deliberately does not say *Connected* because
browser extension installation, enablement and permission state cannot yet
be verified from the desktop. A live extension-to-native diagnostic handshake
and store install links remain future work.

## macOS Safari status

The existing GenyDL.app supports the `genydl://` URL protocol and manual
macOS Services actions. This is **not a Safari Web Extension**. For a
first-class right-click Safari menu, build an Xcode Safari Web Extension
with a separate native app extension and signing. The native handler
communicates with the Qt application using an entitlement-compatible,
user-scoped IPC bridge (Apple App Groups when required). It cannot simply
reuse Chrome/Firefox's native messaging manifest. Do not enable automatic
Safari interception without proving the required Downloads APIs exist
and behave consistently in target versions.

See `docs/safari-extension-implementation.md` for the macOS target contract.

## Test commands (no CI)

```sh
cmake --build <build> --target GenyDL GenyDLNativeHost genydl_browser_bridge_tests browser-extension-zip
ctest --test-dir <build> --output-on-failure
node tests/browser-extension-smoke.cjs
node tests/browser-options-smoke.cjs
node tests/browser-setup-smoke.cjs
# Linux-only isolated native-host toggle regression:
python3 tests/browser-toggle-linux-smoke.py
```

On macOS, additionally verify cold-start handoff, Manual right-click,
permission denial, Ask/Add, Ask/Cancel, Always, 3+ concurrent requests,
repeated file names, backgrounding, and host disconnection.

**Not done:** signed Safari Web Extension, store publication and verified
one-click store install links, automatic browser extension installation
(outside enterprise policy), live extension-enable/health handshake,
Windows runtime tests, sandboxed Linux host access. Do not market these
as completed until each platform has been tested.
