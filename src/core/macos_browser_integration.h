#pragma once

class BrowserActivation;

// macOS Services menu: manual link capture for Safari and any other app
// that supports macOS Services. Automatic capture still needs a Safari
// WebExtension and its own native messaging adapter.
void registerMacBrowserService(BrowserActivation* receiver);
