# Browser integration (experimental)

The browser integration is deliberately **fail-open**: an ordinary browser
download is only cancelled after `GenyDLNativeHost` returns an acknowledgement
that the desktop application queued the URL. If the native host is unavailable
or rejects a request, the browser download stays in the browser.

## Architecture

- `browser-extension/` — one Manifest V3 WebExtension for Chrome, Edge and
  Firefox; Safari conversion needs a signed Apple app extension.
- `GenyDLNativeHost` — small native-messaging executable, next to `GenyDL`
  (inside `GenyDL.app/Contents/MacOS` on macOS).
- `BrowserActivation` — current-user local socket, validates HTTP(S) URLs,
  forwards activations to the existing app instance, enqueues downloads without
  forcing a GUI window to the foreground. Browser download handoffs include an
  optional filename hint; the receiver discards any browser-provided directory
  path and uses only a validated basename. This preserves names such as
  `genydl-main.zip` when GitHub redirects to an extensionless codeload URL.
- `genydl://download/?url=<encoded HTTP(S) URL>` — supported as manual/fallback
  protocol on macOS and Windows; Linux .desktop declares the scheme.

No HTTPS MITM/proxy, certificate installation or privileged browser changes.

## Browser setup

1. Build the desktop application and put it in the final installation
   directory. Launch it once so it can register native-messaging host metadata
   in the current user's browser configuration directories.
2. For Firefox, the extension has stable ID
   `download-links@genydl.genyleap.com`; sign/publish the Firefox build before
   normal distribution. Temporary installation is possible from
   `about:debugging`.
3. For Chrome, Edge and Brave, first publish an extension or load it unpacked.
   Obtain its **32-character extension ID** and build the desktop app with
   `-DGENYDL_CHROMIUM_EXTENSION_ID=<extension-id>`. A launch of that build
   registers current-user native messaging descriptors for Chrome, Edge and
   Brave. These registrations do not install/enable the extension. Browser
   confirmation is still required.
4. Open the extension toolbar popup to choose:
   - **Smart** (default): only recognized file extensions / octet-stream;
   - **Automatic**: eligible HTTP(S) downloads;
   - **Manual**: user-initiated context-menu links only;
   - **Off**.
   Exclude specific hostnames in the same UI.

Do not rely on `mode=Automatic` with POST-backed, signed, cookie-authenticated,
streaming, or blob/data URL downloads. The native host currently transfers URL
only. It does not export cookies, form bodies, session tokens from browser
storage, Referer, or arbitrary request headers. Improving this requires a
privacy-reviewed, opt-in protocol with explicit secret lifetimes.

## macOS / Safari

macOS `Info.plist` registers the `genydl` protocol and a **Download with GenyDL**
Services menu entry, providing a manual way to send selected URL text from
Safari and other macOS applications without a Safari extension. The system
may prompt for protocol permission and for Services availability. Firefox / Chromium native-host
registration targets macOS user application-support folders.

**Safari automatic interception is NOT included in this Linux-built stage.**
Although this extension shares standard WebExtension source, Safari needs
conversion to an Xcode Safari Web Extension target, an associated signed
application extension and a browser-specific native messaging adapter.
Build/sign/notarize that target on macOS, then verify what versions of Safari
expose `downloads.onCreated`. Do not silently claim Safari automatically
captures downloads before this is verified.

## Test without CI

```sh
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++-23 \
  -DCMAKE_CXX_COMPILER_CLANG_SCAN_DEPS=/usr/bin/clang-scan-deps-23 \
  -DCMAKE_PREFIX_PATH=/opt/Qt/6.12.0/gcc_64
cmake --build build --target GenyDLNativeHost genydl_browser_bridge_tests
ctest --test-dir build -R genydl_browser_bridge_tests --output-on-failure
cmake --build build --target browser-extension-zip
node tests/browser-extension-smoke.cjs
```

On macOS, use your installed LLVM/Qt paths and test an app bundle installed
in /Applications (not an unpacked Linux binary). Example protocol smoke test:
`open 'genydl://download/?url=https%3A%2F%2Fexample.com%2Ftest.zip'`.

## Remaining before broad release

- Signed/store-hosted Chrome/Edge/Firefox extensions, their stable IDs,
  installer and CI/CD distribution.
- On-device macOS QA, especially Safari app-extension packaging and signing.
- User-visible browser connection status and pairing diagnostics.
- Opt-in authentication context/headers for session-backed downloads.
- Full desktop build/regression tests on each supported target OS.
