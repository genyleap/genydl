# Safari Web Extension implementation contract (not shipped yet)

This is the macOS-specific follow-up to the cross-platform Browser Integration
v2 code. Safari is not a Windows or Linux product. An HTML/JavaScript
WebExtension cannot be installed in Safari by copying a Chrome extension
folder or by registering a Firefox/Chromium native messaging JSON file.

## Build products

1. Xcode **Safari Web Extension** app extension target, with a Safari-specific
   Manifest V3 and the shared GenyDL UI/settings and context-menu logic.
2. Swift `SafariWebExtensionHandler` (native handler inside the .appex).
3. A signed container/host app or an extension packaging arrangement supported
   by Apple's SafariServices rules, integrated into the GenyDL macOS
   deployment bundle. `GenyDL.app` remains the Qt/C++ application.
4. Signing entitlements (Team ID and an App Group as needed) configured for
   both app and app extension; embed and sign the .appex before signing the
   outer application. Distribute notarized outside the App Store or publish
   through the App Store following Apple's requirements.

Do not invent Team IDs, App Group identifiers or entitlement profiles. These
come from the publisher's Apple Developer account and must be tested on a Mac.

## Functional scope and permissions

**Initial Safari release is Manual-only.** The extension should create a
**Download with GenyDL** context menu on links, plus an optional toolbar
action. No access to all site content is necessary for a context-menu link.
If Safari displays a permission prompt, let the user authorize it through
Safari settings. Provide visible instructions for opening Safari > Settings >
Extensions and enabling GenyDL.

On context menu:
1. Extract the clicked link's HTTP(S) URL in extension JavaScript.
2. Use `browser.runtime.sendNativeMessage` to deliver a versioned
   `download.offer` with unique `requestId` and the URL to the Safari
   native handler.
3. The native handler validates, forwards the request to the signed
   GenyDL app's IPC endpoint, and returns a prompt-delivery acknowledgment.
4. GenyDL activates its window and opens **Add download**, where the user
   explicitly decides whether and how to download.
5. Cancelling in GenyDL makes no change to an existing Safari download,
   because Manual mode does not intercept or pause the browser transfer.

Apple's native message response is not proof that GenyDL added or completed
a download; report precise state to the user.

## IPC and security

- Safari App Extension is not the existing `GenyDLNativeHost` executable.
  Native messages arrive at `SafariWebExtensionHandler` in the Apple
  SafariServices extension context.
- Choose an entitlement-compatible communication channel between the
  extension handler and Qt. An App Group container and local socket is a
  candidate if both processes have the corresponding entitlement and the
  sandbox can access the socket. Validate that design on macOS.
- Strictly parse and validate origin URL, command type, protocol version,
  requestId, string sizes, and filename basename. The handler must not
  execute shell commands, accept file destinations or trust arbitrary local
  paths from JavaScript.
- User approval belongs in GenyDL; the Safari handler should only forward
  a request and should not start the download on its own.
- Check extension enablement/permissions via supported SafariServices APIs;
  never edit Safari's preferences/plist or force-enable extensions.

## Safari automatic interception

Do not reuse Chromium's `downloads.onCreated` / `pause` / `erase` flow
unless each API is proven in the targeted Safari release. If unsupported,
expose only Manual, with clear capability status in GenyDL settings.
There is no clean universal browser-independent API for silently replacing
Safari's download pipeline.

## Verification on a Mac

- Build Safari app extension using Xcode and the appropriate Apple SDK.
- Confirm the extension appears in Safari > Settings > Extensions.
- Confirm that the user can enable/disable it without private APIs.
- Verify Manual right-click on an HTTP(S) link opens the Qt Add Download
  dialog, and Cancel does not interrupt a native Safari download.
- Verify host app closed, host app running, repeated links, multiple
  simultaneous requests, invalid schemes, URL encoding, and extension
  revocation.
- Verify notarized production packaging and launch on an otherwise clean
  macOS installation.

Official resources:
- https://developer.apple.com/documentation/safariservices/safari-web-extensions
- https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension
- https://developer.apple.com/documentation/safariservices/managing-safari-web-extension-permissions
