import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var windowController: WindowController?
    var autoPlayTimer: Timer?
    var playedHistory: [(url: String, title: String)] = []

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

        // Add Play Chrome YouTube submenu (will be updated dynamically)
        let playItem = NSMenuItem(title: "Play Chrome YouTube", action: nil, keyEquivalent: "")
        menu.addItem(playItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu

        // Create window controller
        windowController = WindowController()

        // Populate history with existing YouTube tabs
        let tabs = ChromeHelper.getYouTubeTabs()
        for tab in tabs {
            addToHistory(url: tab.url, title: tab.title)
        }

        // Start auto-play timer
        startAutoPlayTimer()
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

    @MainActor func addToHistory(url: String, title: String) {
        // Remove if already exists
        playedHistory.removeAll { $0.url == url }
        // Add to front
        playedHistory.insert((url, title), at: 0)
        // Limit to 20
        if playedHistory.count > 20 {
            playedHistory = Array(playedHistory.prefix(20))
        }
        print("Added to history: \(url) - \(title), total: \(playedHistory.count)")
        // Reload table
        windowController?.tableView?.reloadData()
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

    func startAutoPlayTimer() {
        autoPlayTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkForAutoPlay()
            }
        }
    }
    
    @MainActor func checkForAutoPlay() {
        print("Checking for auto-play...")
        guard let info = ChromeHelper.getActiveTabInfo(),
              info.url.contains("youtube.com/watch"),
              info.url != windowController?.currentURL else {
            print("No new YouTube URL detected")
            return
        }
        print("Detected new YouTube URL: \(info.url)")

        // Add to history
        addToHistory(url: info.url, title: info.title)

        // Check if video is paused in Chrome, if yes, start it
        if let paused = ChromeHelper.isVideoPaused(url: info.url), paused {
            ChromeHelper.playVideoInChrome(url: info.url)
        }

        // Auto-play in mini app
        windowController?.showWindow(nil)
        windowController?.playYouTubeURL(info.url)
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Update the Play Chrome YouTube submenu dynamically
        if let playItem = menu.items.first(where: { $0.title == "Play Chrome YouTube" }) {
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
        }

        // Sync history with detected YouTube tabs
        let tabs = ChromeHelper.getYouTubeTabs()
        for tab in tabs {
            if !playedHistory.contains(where: { $0.url == tab.url }) {
                addToHistory(url: tab.url, title: tab.title)
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