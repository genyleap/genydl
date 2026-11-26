#pragma once

// Native Messaging uses the same executable as the GenyDL desktop app.
// Detect browser invocations before constructing QApplication, so the host
// writes only length-prefixed JSON to stdout and never opens the GUI.
bool isNativeMessagingInvocation(int argc, char* argv[]);
int runNativeMessagingHost(int argc, char* argv[]);
