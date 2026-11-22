# Draft store submission material — requires publisher review

**DRAFT, NOT PUBLISHED.** This text describes the current extension source,
not a broader audit of the desktop application's services or data handling.
Before publication, check every privacy claim against the final binaries and
host the approved privacy policy at a real public URL.

## Listing

**Name:** Download with GenyDL

**One-line purpose:** Send browser download links to the GenyDL desktop
download manager with user-controlled confirmation.

**Description (English):**

Download with GenyDL adds a context-menu action for supported web links so
you can choose how to save files in the GenyDL desktop application.

By default, downloads stay in your browser. Choose **Download with GenyDL**
from a link's right-click menu to open GenyDL's Add Download dialog. You can
review the URL, filename, destination, and download settings before choosing
Add or Cancel.

If you choose, you can enable Ask mode (review eligible downloads before
transfer) or Always mode (automatically transfer eligible HTTP(S) downloads).
These modes are opt-in, and the browser requests the necessary download
management permission. If GenyDL is unavailable or a transfer is declined,
the extension attempts to let the browser continue its download.

Requires the separately installed GenyDL desktop application and its
native-messaging component. Browser-specific API limitations may apply.
Some authenticated downloads or POST requests cannot be transferred
reliably to a separate download manager.

## Permission explanations for reviewers

| Permission | Why it is needed |
| --- | --- |
| `nativeMessaging` | Exchange download URLs and response status with the locally installed GenyDL native host |
| `contextMenus` | Add "Download with GenyDL" to the context menu of browser links |
| `storage` | Store user's Manual/Ask/Always/Disabled choice and domain exclusions inside browser storage |
| `alarms` | Periodically check whether the locally installed GenyDL application accepts a native connection |
| `downloads` (optional) | Only after explicit opt-in to Ask or Always: pause eligible browser downloads, resume on rejection/failure, or cancel and remove the browser history entry after successful handoff |

The extension does not inject executable code from remote websites, does not
request unrestricted host access, and does not use the native host to run shell
commands. The companion application downloads files separately.

## Privacy and data transmission — disclosure draft

The extension passes a file URL, optional suggested filename, and request
metadata to the **locally installed GenyDL desktop application** when a user
selects Download with GenyDL or explicitly enables automatic interception.
This may include a URL containing a website token or query string.

The extension itself does not include an external analytics/telemetry endpoint
or send browsing history to a publisher-operated web service. The companion
application makes separate network requests to the user-selected download
destination. This draft does **not** state that the full GenyDL desktop
application never processes personal data; its own behavior must be audited
and disclosed separately.

For Mozilla, the manifest declares the `browsingActivity` data type because
URL transfer from the browser to the separate desktop application is outside
the add-on's browser environment. The exact disclosure should be reviewed
against Mozilla's current taxonomy before AMO submission.

For Chrome and Edge, accurately fill out the Privacy Practices and
Permission Justifications sections in the store consoles; do not falsely
select "no browsing data transmitted" simply because the native target is
local rather than cloud-hosted.

## Reviewer instructions (draft)

1. Install and launch the GenyDL desktop application and verify its native
   messaging host is registered for the test browser. Supply reviewers a
   verified installation download link; do not invent one.
2. Install the browser extension and accept required browser permissions.
3. Right-click a normal public HTTPS ZIP download link and choose
   **Download with GenyDL**. The desktop Add Download dialog appears; no
   download is started until the user approves.
4. Use Cancel, then repeat with Add and confirm a desktop download appears.
5. In the extension settings, Ask and Always modes require an additional
   browser downloads permission; choose Manual to revoke it when supported.
6. Without the native desktop app running, the extension should not
   claim a successful transfer or permanently interrupt a browser download.

## Items the publisher must supply

Real publisher name and support contact, public GenyDL application download
URL, trademark-approved logo/screen captures, hosted approved Privacy Policy,
any company verification data required by the store, and a testable app
package for each target OS.

The final browser listing URL and exact store-assigned extension ID become
known only after creating the corresponding store item. Configure those values
into the production desktop build, test the handshake with the store-installed
extension, then enable the in-app **Install from official store** action.
