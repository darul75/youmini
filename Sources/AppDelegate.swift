import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var windowController: WindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "YT"
        }

        // Create menu
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Window", action: #selector(toggleWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Create window controller
        windowController = WindowController()
    }

    @MainActor @objc func toggleWindow() {
        if let wc = windowController {
            if wc.window?.isVisible == true {
                wc.close()
            } else {
                wc.showWindow(nil)
            }
        }
    }

    @MainActor @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
}