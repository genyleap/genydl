#pragma once

// Register only native-messaging descriptors; never force-enable extensions.
// Chromium registration requires a published/unpacked extension ID.
void registerBrowserNativeHosts();
