import AppKit
@preconcurrency import YouTubeKit

typealias Video = (url: String, title: String)

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarManager: StatusBarManager?
    var appWindowController: AppWindowController?
    var isMiniViewMode: Bool = false
    var autoPlayTimer: Timer?
    var playedHistory: [Video] = []
    var currentPlayingIndex: Int?



    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarManager = StatusBarManager(appDelegate: self)

        appWindowController = AppWindowController()

        print("🚀 App launch, restoring window frame...")
        appWindowController?.restoreWindowFrame()

        loadPersistedHistory()

        isMiniViewMode = UserDefaults.standard.bool(forKey: "com.youtube.mini.miniViewMode")
        if isMiniViewMode {
            appWindowController?.toggleMiniView(true)
        }

        let wasPlayingFlag = UserDefaults.standard.bool(forKey: "com.youtube.mini.wasPlayingOnQuit")
        print("🚀 App launch - currentPlayingIndex: \(currentPlayingIndex ?? -1), wasPlayingFlag: \(wasPlayingFlag), historyCount: \(playedHistory.count)")

        if let index = currentPlayingIndex, index < playedHistory.count,
            wasPlayingFlag == true {
            let videoURL = playedHistory[index].url
            print("🎬 Auto-resuming video that was playing when app quit: \(videoURL)")
            appWindowController?.listingTableView?.reloadData()
            appWindowController?.playYouTubeURL(videoURL)
            UserDefaults.standard.removeObject(forKey: "com.youtube.mini.wasPlayingOnQuit")
            print("✅ Cleared wasPlayingOnQuit flag after auto-resume")
        } else {
            print("❌ Not auto-resuming: index=\(currentPlayingIndex ?? -1), flag=\(wasPlayingFlag), count=\(playedHistory.count)")
        }

        let tabs = ChromeHelper.getYouTubeTabs()
        for tab in tabs {
            addToHistory(url: tab.url, title: tab.title)
        }

        appWindowController?.showWindow(nil)

        if playedHistory.count == 1 {
            currentPlayingIndex = 0
            appWindowController?.listingTableView?.reloadData()
            appWindowController?.playYouTubeURL(playedHistory[0].url)
        }

        startAutoPlayTimer()
    }

    @MainActor @objc func toggleWindow() {
        if let wc = appWindowController {
            if wc.window?.isVisible == true {
                print("🔽 Hiding window, saving frame...")
                wc.saveWindowFrame()

                if isMiniViewMode {
                    statusBarManager?.toggleMiniView()
                }

                wc.stopPlayback()
                wc.close()
            } else {
                print("🔼 Showing window, restoring frame...")
                wc.restoreWindowFrame()
                wc.showWindow(nil)
            }
        }
    }



    @MainActor func addToHistory(url: String, title: String) {
        playedHistory.removeAll { $0.url == url }
        playedHistory.append((url, title))
        if playedHistory.count > 20 {
            playedHistory.removeFirst()
        }
        print("Added to history: \(url) - \(title), total: \(playedHistory.count)")

        appWindowController?.listingTableView?.reloadData()

        if playedHistory.count == 1 && currentPlayingIndex == nil {
            currentPlayingIndex = 0
        }

        saveHistory()

        Task { @MainActor in
            do {
                print("Fetching real title for URL: \(url)")
                let youTube = YouTube(url: URL(string: url)!)
                let metadata = try await youTube.metadata
                if let realTitle = metadata?.title, realTitle != title {
                    print("Updating title from '\(title)' to '\(realTitle)'")
                    if let index = playedHistory.firstIndex(where: { $0.url == url }) {
                        playedHistory[index] = (url, realTitle)
                        appWindowController?.listingTableView?.reloadData()
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
        appWindowController?.listingTableView?.reloadData()
    }

    @MainActor func removeFromHistory(at index: Int) {
        guard index >= 0 && index < playedHistory.count else { return }
        playedHistory.remove(at: index)

        if let current = currentPlayingIndex {
            if index < current {
                currentPlayingIndex = current - 1
            } else if index == current {
                currentPlayingIndex = nil
            }
        }
        saveHistory()
        appWindowController?.listingTableView?.reloadData()
        print("Removed from history at index \(index), total: \(playedHistory.count)")
    }

    @MainActor func playNextVideo() {
        if let index = currentPlayingIndex, index + 1 < playedHistory.count {
            currentPlayingIndex = index + 1
            appWindowController?.listingTableView?.reloadData()
            appWindowController?.playYouTubeURL(playedHistory[index + 1].url)
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

        let tabs = ChromeHelper.getYouTubeTabs()
        for tab in tabs {
            if !playedHistory.contains(where: { $0.url == tab.url }) {
                print("Synced new tab to history: \(tab.url)")
                addToHistory(url: tab.url, title: tab.title)
            }
        }

        guard let info = ChromeHelper.getActiveTabInfo(),
              info.url.contains("youtube.com/watch"),
              info.url != appWindowController?.currentURL else {
            print("No new YouTube URL detected")
            return
        }
        print("Detected new YouTube URL: \(info.url)")

        if let paused = ChromeHelper.isVideoPaused(url: info.url), paused {
            ChromeHelper.playVideoInChrome(url: info.url)
        }
        
        appWindowController?.showWindow(nil)
        appWindowController?.playYouTubeURL(info.url)
    }


    @MainActor @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @MainActor @objc func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(self)
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("💾 App terminating, saving window frame...")
        appWindowController?.saveWindowFrame()
    }
}