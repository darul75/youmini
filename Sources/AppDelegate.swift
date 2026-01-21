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

        // Add Play Chrome YouTube submenu
        let playItem = NSMenuItem(title: "Play Chrome YouTube", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let tabs = ChromeHelper.getYouTubeTabs()
        if tabs.isEmpty {
            let noTabsItem = NSMenuItem(title: "No YouTube tabs found", action: nil, keyEquivalent: "")
            noTabsItem.isEnabled = false
            submenu.addItem(noTabsItem)
        } else {
            for tab in tabs {
                let item = NSMenuItem(title: tab.title, action: #selector(playYouTubeTab(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = tab.url
                submenu.addItem(item)
            }
        }
        playItem.submenu = submenu
        menu.addItem(playItem)

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

    @MainActor @objc func playYouTubeTab(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? String {
            // Start the video in Chrome if paused
            if let paused = ChromeHelper.isVideoPaused(url: url), paused {
                ChromeHelper.playVideoInChrome(url: url)
            }
            windowController?.showWindow(nil)
            windowController?.playYouTubeURL(url)
        }
    }

    @MainActor @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
}