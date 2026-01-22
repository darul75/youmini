import AppKit
@preconcurrency import YouTubeKit

typealias Video = (url: String, title: String)

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var windowController: WindowController?
    var isMiniViewMode: Bool = false
    var autoPlayTimer: Timer?
    var playedHistory: [Video] = []
    var currentPlayingIndex: Int?

    private func createPlayButtonIcon() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        let path = NSBezierPath()
        // Draw larger play triangle: points at (2,2), (2,14), (13,8) for better visibility
        path.move(to: NSPoint(x: 2, y: 2))
        path.line(to: NSPoint(x: 2, y: 14))
        path.line(to: NSPoint(x: 13, y: 8))
        path.close()
        path.fill()
        image.unlockFocus()
        return image
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = createPlayButtonIcon()
            button.image?.isTemplate = true
        }

        // Create menu
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Window", action: #selector(toggleWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let miniViewItem = NSMenuItem(title: "Mini View", action: #selector(toggleMiniView), keyEquivalent: "")
        miniViewItem.target = self
        menu.addItem(miniViewItem)

        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu

        // Set up main menu for standard About panel
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "YouTubeMini")
        appMenu.addItem(withTitle: "About YouTubeMini", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit YouTubeMini", action: #selector(quitApp), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu

        // Create window controller
        windowController = WindowController()

        // Restore window frame before showing
        print("🚀 App launch, restoring window frame...")
        windowController?.restoreWindowFrame()

        // Load persisted history first
        loadPersistedHistory()

        // Load MiniView mode
        isMiniViewMode = UserDefaults.standard.bool(forKey: "com.youtube.mini.miniViewMode")
        if isMiniViewMode {
            // Update menu title for persisted mode
            if let miniViewItem = menu.items.first(where: { $0.action == #selector(toggleMiniView) }) {
                miniViewItem.title = "Split View"
            }
            // Apply the MiniView mode to the window
            windowController?.toggleMiniView(true)
        }

        // Auto-resume if video was playing when app quit
        let wasPlayingFlag = UserDefaults.standard.bool(forKey: "com.youtube.mini.wasPlayingOnQuit")
        print("🚀 App launch - currentPlayingIndex: \(currentPlayingIndex ?? -1), wasPlayingFlag: \(wasPlayingFlag), historyCount: \(playedHistory.count)")

        if let index = currentPlayingIndex, index < playedHistory.count,
           wasPlayingFlag == true {
            let videoURL = playedHistory[index].url
            print("🎬 Auto-resuming video that was playing when app quit: \(videoURL)")
            windowController?.listingTableView?.reloadData()  // Highlight current video
            windowController?.playYouTubeURL(videoURL)
            // Clear the flag after auto-playing (one-time only)
            UserDefaults.standard.removeObject(forKey: "com.youtube.mini.wasPlayingOnQuit")
            print("✅ Cleared wasPlayingOnQuit flag after auto-resume")
        } else {
            print("❌ Not auto-resuming: index=\(currentPlayingIndex ?? -1), flag=\(wasPlayingFlag), count=\(playedHistory.count)")
        }

        // Then populate history with existing YouTube tabs
        let tabs = ChromeHelper.getYouTubeTabs()
        for tab in tabs {
            addToHistory(url: tab.url, title: tab.title)
        }

        windowController?.showWindow(nil)

        // Set initial menu title to Hide Window since window is shown
        if let openItem = menu.items.first(where: { $0.action == #selector(toggleWindow) }) {
            openItem.title = "Hide Window"
        }

        // Auto-play if only one video in history
        if playedHistory.count == 1 {
            currentPlayingIndex = 0
            windowController?.listingTableView?.reloadData()
            windowController?.playYouTubeURL(playedHistory[0].url)
        }

        // Start auto-play timer
        startAutoPlayTimer()
    }

    @MainActor @objc func toggleWindow() {
        if let wc = windowController {
            if wc.window?.isVisible == true {
                print("🔽 Hiding window, saving frame...")
                wc.saveWindowFrame()  // Save window frame BEFORE any mode changes

                if isMiniViewMode {
                    // Exit MiniView first when hiding window
                    toggleMiniView()
                }

                wc.stopPlayback()  // Stop video before hiding window
                wc.close()
            } else {
                print("🔼 Showing window, restoring frame...")
                wc.restoreWindowFrame()  // Restore window frame before showing
                wc.showWindow(nil)
            }
        }
    }

    @MainActor @objc func toggleMiniView() {
        isMiniViewMode.toggle()

        // Update menu title
        if let miniViewItem = statusItem.menu?.items.first(where: { $0.action == #selector(toggleMiniView) }) {
            miniViewItem.title = isMiniViewMode ? "Split View" : "Mini View"
        }

        // Notify window controller
        windowController?.toggleMiniView(isMiniViewMode)

        // Persist mode
        UserDefaults.standard.set(isMiniViewMode, forKey: "com.youtube.mini.miniViewMode")
        print("MiniView mode \(isMiniViewMode ? "enabled" : "disabled")")
    }

    @MainActor func addToHistory(url: String, title: String) {
        // Remove if already exists
        playedHistory.removeAll { $0.url == url }
        // Add to end
        playedHistory.append((url, title))
        // Limit to 20, remove oldest
        if playedHistory.count > 20 {
            playedHistory.removeFirst()
        }
        print("Added to history: \(url) - \(title), total: \(playedHistory.count)")
        // Reload table
        windowController?.listingTableView?.reloadData()

        // If this is the first video and no current playing, set index
        if playedHistory.count == 1 && currentPlayingIndex == nil {
            currentPlayingIndex = 0
        }

        // Save history to UserDefaults
        saveHistory()

        // Fetch real title asynchronously
        Task { @MainActor in
            do {
                print("Fetching real title for URL: \(url)")
                let youTube = YouTube(url: URL(string: url)!)
                let metadata = try await youTube.metadata
                if let realTitle = metadata?.title, realTitle != title {
                    print("Updating title from '\(title)' to '\(realTitle)'")
                    // Update the existing entry
                    if let index = playedHistory.firstIndex(where: { $0.url == url }) {
                        playedHistory[index] = (url, realTitle)
                        windowController?.listingTableView?.reloadData()
                        // Save updated history
                        saveHistory()
                    }
                }
            } catch {
                print("Failed to fetch metadata for \(url): \(error)")
            }
        }
    }

    func saveHistory() {
        let historyData = playedHistory.map { ["url": $0.url, "title": $0.title] }
        UserDefaults.standard.set(historyData, forKey: "com.youtube.mini.history")
        UserDefaults.standard.set(currentPlayingIndex, forKey: "com.youtube.mini.currentIndex")
        print("Saved history: \(playedHistory.count) items, current index: \(currentPlayingIndex ?? -1)")
    }

    @MainActor private func loadPersistedHistory() {
        guard let historyData = UserDefaults.standard.array(forKey: "com.youtube.mini.history") as? [[String: String]],
              !historyData.isEmpty else {
            print("No persisted history found (first launch)")
            return
        }

        playedHistory = historyData.compactMap { dict -> (url: String, title: String)? in
            guard let url = dict["url"], let title = dict["title"] else {
                print("Invalid history item: \(dict)")
                return nil
            }
            return (url, title)
        }

        currentPlayingIndex = UserDefaults.standard.integer(forKey: "com.youtube.mini.currentIndex")
        if let index = currentPlayingIndex, index >= playedHistory.count {
            currentPlayingIndex = nil
            print("Current index \(index) out of bounds, resetting to nil")
        }

        print("Loaded persisted history: \(playedHistory.count) items, current index: \(currentPlayingIndex ?? -1)")
        windowController?.listingTableView?.reloadData()
    }

    @MainActor func removeFromHistory(at index: Int) {
        guard index >= 0 && index < playedHistory.count else { return }
        playedHistory.remove(at: index)
        // Adjust currentPlayingIndex
        if let current = currentPlayingIndex {
            if index < current {
                currentPlayingIndex = current - 1
            } else if index == current {
                currentPlayingIndex = nil
            }
        }
        saveHistory()
        windowController?.listingTableView?.reloadData()
        print("Removed from history at index \(index), total: \(playedHistory.count)")
    }

    @MainActor func playNextVideo() {
        if let index = currentPlayingIndex, index + 1 < playedHistory.count {
            currentPlayingIndex = index + 1
            windowController?.listingTableView?.reloadData()
            windowController?.playYouTubeURL(playedHistory[index + 1].url)
            saveHistory()
        }
    }



    func startAutoPlayTimer() {
        autoPlayTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
    }

    @objc @MainActor private func timerFired() {
        checkForAutoPlay()
    }
    
    @MainActor func checkForAutoPlay() {
        print("Checking for auto-play...")

        // Sync history with detected YouTube tabs
        let tabs = ChromeHelper.getYouTubeTabs()
        for tab in tabs {
            if !playedHistory.contains(where: { $0.url == tab.url }) {
                print("Synced new tab to history: \(tab.url)")
                addToHistory(url: tab.url, title: tab.title)
            }
        }

        guard let info = ChromeHelper.getActiveTabInfo(),
              info.url.contains("youtube.com/watch"),
              info.url != windowController?.currentURL else {
            print("No new YouTube URL detected")
            return
        }
        print("Detected new YouTube URL: \(info.url)")

        // Add to history (already added above, but ensure)
        
        // Check if video is paused in Chrome, if yes, start it
        if let paused = ChromeHelper.isVideoPaused(url: info.url), paused {
            ChromeHelper.playVideoInChrome(url: info.url)
        }
        
        // Auto-play in mini app
        windowController?.showWindow(nil)
        windowController?.playYouTubeURL(info.url)
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Update Show/Hide Window title
        if let openItem = menu.items.first(where: { $0.action == #selector(toggleWindow) }) {
            let isVisible = windowController?.window?.isVisible == true
            openItem.title = isVisible ? "Hide Window" : "Show Window"
        }
    }

    @MainActor @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @MainActor @objc func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(self)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save window frame before app terminates
        print("💾 App terminating, saving window frame...")
        windowController?.saveWindowFrame()
    }
}