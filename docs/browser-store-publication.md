# Publishing GenyDL browser extensions (2026)

**Status:** not submitted or published. This guide prepares an authorized
maintainer to submit. Draft store listing text, privacy explanations and
reviewer instructions are in `docs/browser-store-submission-materials.md`.
Do not create developer accounts, pay fees, upload, claim approval, or enable
CI without explicit owner authorization.

## Store coverage

| Distribution channel | Artifact | Desktop browsers | Native messaging |
| --- | --- | --- | --- |
| Chrome Web Store | `GenyDL-Chromium-extension.zip` | Chrome, and compatible Brave/Vivaldi/Chromium variants | Configure the **real store-assigned ID** in GenyDL |
| Firefox Add-ons (AMO) | `GenyDL-Firefox-extension.zip` | Firefox | Fixed `gecko.id`: `browser@genyleap.com` |
| Microsoft Edge Add-ons | Chromium ZIP | Microsoft Edge | Configure its **own store-assigned ID** |
| Apple distribution | **not yet built** | Safari on macOS only | Requires separately signed Safari App Extension |

### 1. Prerequisites, before uploading anything

- Complete real browser/desktop tests (right-click prompt, Add, Cancel, browser
  disconnected, app closed, permission rejection, Ask and Always, concurrent
  downloads); no fake "Connected" label based only on a local file.
- Verify publisher identity/rights to "GenyDL" and logos, write user-facing
  descriptions, choose support contact, and prepare real screenshots.
- Host an accessible and accurate privacy policy on a publisher-controlled URL.
  Do not claim that the extension handles no data: download URLs are transmitted
  from the browser extension to the **local GenyDL desktop application**.
  The app then fetches the selected URLs from their originating websites. Any
  further collection by the native app must be described separately if present.
- Explain `nativeMessaging`, `contextMenus`, `storage`, `alarms`, and
  optional `downloads` in review notes. Native Messaging connects the
  extension to the installed GenyDL desktop app; it is not arbitrary remote
  code execution.
- Keep the initial policy **Manual**. Ask/Always request browser-managed
  permission separately and must be explicitly chosen by the user.
- Confirm the manifest versions are incremented for every new submission.

### 2. Chrome Web Store

Official process:
https://developer.chrome.com/docs/webstore/register/
https://developer.chrome.com/docs/webstore/prepare
https://developer.chrome.com/docs/webstore/cws-dashboard-privacy

1. Owner creates a Chrome Web Store Developer account with 2-step verification
   and pays Google's one-time registration fee.
2. Upload the versioned Chromium ZIP (root contains `manifest.json`).
3. Complete the Store Listing: single purpose, category, name, description,
   screenshots/logo, support and website.
4. Complete the Privacy form: permissions justification, data practices,
   privacy policy URL, no remotely hosted extension code.
5. Submit for review. Initially prefer controlled/private testing when available.
6. **After Google assigns the listing ID**, verify it; do not assume it equals
   the public `manifest.key` unpacked development ID.
7. Configure the real ID with `GENYDL_CHROME_EXTENSION_ID` in the desktop
   release build, install the resulting native host, and confirm a real
   `connectNative` handshake with a Chrome Web Store installation.

Future updates can use the documented Chrome Web Store API, once the owner
configures authenticated access:
https://developer.chrome.com/docs/webstore/using-api/

### 3. Mozilla Add-ons (AMO)

Official process:
https://extensionworkshop.com/documentation/publish/submitting-an-add-on/
https://extensionworkshop.com/documentation/publish/signing-and-distribution-overview/
https://extensionworkshop.com/documentation/develop/firefox-builtin-data-consent/

1. Owner signs in to https://addons.mozilla.org/developers/ and begins a new
   public listed extension submission.
2. Upload `GenyDL-Firefox-extension.zip`, with `manifest.json` at ZIP root.
3. Preserve `browser_specific_settings.gecko.id` across updates.
4. New Firefox extensions must disclose data collection/transmission via
   `browser_specific_settings.gecko.data_collection_permissions`. The extension
   sends user-selected/download URLs to a **separate local desktop application**,
   so the manifest declares `browsingActivity` rather than incorrectly
   declaring `none`. Review this classification with AMO policy documentation
   and actual application data handling before final submission.
5. Add accurate privacy/support details, reviewer notes explaining local
   native messaging, and reproducible source/build instructions if requested.
6. After review/signing, install from the official AMO listing and test its
   connection to the desktop native host. Unlisted self-distribution uses a
   different signing/update route and is not the desired consumer flow.

### 4. Microsoft Edge Add-ons

Official instructions:
https://learn.microsoft.com/en-us/microsoft-edge/extensions/publish/publish-extension

Use an owner-controlled Partner Center account. Upload the Chromium ZIP to
Edge Add-ons, supply listing, permissions/privacy data, screenshots and
certification test instructions, then submit. Edge's published extension ID
can differ from Chrome's even with identical JavaScript.

Configure the approved ID through `GENYDL_EDGE_EXTENSION_ID`. Verify the
native manifest uses the exact approved ID and perform a real handshake.
Do not silently treat a Chrome listing as an Edge listing.

### 5. Safari

Official Apple route:
https://developer.apple.com/documentation/safariservices/distributing-your-safari-web-extension

Safari cannot consume the Chromium/Firefox native messaging manifest. Build
a separate Safari Web Extension and native Safari App Extension using Xcode,
with the correct Apple signing entitlements, embed/sign it in a host app and
notarize the application (outside Mac App Store), or submit through App Store
Connect. **Not implemented yet.**

### 6. App UX once the listings actually exist

The install action must be a direct HTTPS link to each verified store
listing. It must not just open a browser start page or the generic
`chrome://extensions` / `about:addons` screen. Native-host registration
happens internally and is not evidence the extension is installed.

Expected user flow:
`Choose browser → Install from official store → Browser permission dialog →
 GenyDL extension handshake → Connected`.

Do not put a listing URL into the app until the matching item genuinely
exists. Keep a development-only "Show extension files" action for debugging,
separate from normal production onboarding.

**Release ID caveat:** the fixed unpacked Chromium ID
`dhmfclimdfgeemdecnghagiodcmiafdb` is only a development convenience;
do not assume the store accepts or preserves it. Update GenyDL's permitted
origin list to the actual store-assigned ID(s) when known.
