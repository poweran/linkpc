import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    // Terminate privileged helper process when the app quits
    let task = Process()
    task.launchPath = "/usr/bin/sudo"
    task.arguments = ["-n", "/usr/bin/pkill", "-f", "linkpc-sing-box"]
    try? task.run()
    task.waitUntilExit()
  }
}
