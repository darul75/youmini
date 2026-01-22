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
        appWindowController?.restoreWindowFrame()

        loadPersistedHistory()

        isMiniViewMode = UserDefaults.standard.bool(forKey: "com.youtube.mini.miniViewMode")
        if isMiniViewMode {
            appWindowController?.toggleMiniView(true)
        }

        let wasPlayingFlag = UserDefaults.standard.bool(forKey: "com.youtube.mini.wasPlayingOnQuit")
        currentPlayingIndex = UserDefaults.standard.integer(forKey: "com.youtube.mini.currentIndex")

        if let index = currentPlayingIndex, index < playedHistory.count,
            wasPlayingFlag == true {
            let videoURL = playedHistory[index].url
            reloadListData()
            appWindowController?.playerController.playYouTubeURL(videoURL)
            UserDefaults.standard.removeObject(forKey: "com.youtube.mini.wasPlayingOnQuit")
        }

        let tabs = ChromeHelper.getYouTubeTabs()
        for tab in tabs {
            addToHistory(url: tab.url, title: tab.title)
        }

        appWindowController?.showWindow(nil)

        if let index = currentPlayingIndex {
            appWindowController?.listingController.tableView?.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }

        startAutoPlayTimer()
    }

    @MainActor func reloadListData() {
        appWindowController?.listingController.tableView?.reloadData()
    }

    @MainActor @objc func toggleWindow() {
        if let wc = appWindowController {
            if wc.window?.isVisible == true {
                wc.saveWindowFrame()

                if isMiniViewMode {
                    statusBarManager?.toggleMiniView()
                }

                wc.playerController.stopPlayback()
                wc.close()
            } else {
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
        appWindowController?.listingController.tableView?.reloadData()

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
                        appWindowController?.listingController.tableView?.reloadData()
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
    }

    @MainActor private func loadPersistedHistory() {
        guard let historyData = UserDefaults.standard.array(forKey: "com.youtube.mini.history") as? [[String: String]],
            !historyData.isEmpty else {
            return
        }

        playedHistory = historyData.compactMap { dict -> (url: String, title: String)? in
            guard let url = dict["url"], let title = dict["title"] else {
                print("Invalid history item: \(dict)")
                return nil
            }
            return (url, title)
        }
        
        reloadListData()
    }

    @MainActor func removeFromHistory(at index: Int) {
        guard index >= 0 && index < playedHistory.count else { return }
        playedHistory.remove(at: index)
        if let current = currentPlayingIndex {
            if index < current {
                currentPlayingIndex = current - 1
            } else if index == current {
                if index < playedHistory.count {
                    currentPlayingIndex = index
                } else if index > 0 {
                    currentPlayingIndex = index - 1
                } else {
                    currentPlayingIndex = nil
                }
            }
        }
        saveHistory()
        appWindowController?.listingController.tableView?.reloadData()

        if let current = currentPlayingIndex {
            appWindowController?.listingController.tableView?.selectRowIndexes(IndexSet(integer: current), byExtendingSelection: false)
        } else {
            appWindowController?.listingController.tableView?.selectRowIndexes(IndexSet(), byExtendingSelection: false)
        }
    }

    @MainActor func playNextVideo() {
        if let index = currentPlayingIndex, index + 1 < playedHistory.count {
            currentPlayingIndex = index + 1
            reloadListData()
            appWindowController?.playerController.playYouTubeURL(playedHistory[index + 1].url)
            appWindowController?.listingController.tableView?.selectRowIndexes(IndexSet(integer: index + 1), byExtendingSelection: false)
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
        let tabs = ChromeHelper.getYouTubeTabs()
        for tab in tabs {
            if !playedHistory.contains(where: { $0.url == tab.url }) {
                print("Synced new tab to history: \(tab.url)")
                addToHistory(url: tab.url, title: tab.title)
            }
        }

        guard let info = ChromeHelper.getActiveTabInfo(),
              info.url.contains("youtube.com/watch") || info.url.contains("youtube.com/shorts"),
              info.url != appWindowController?.playerController.currentURL else {
            return
        }
        print("Detected new YouTube URL: \(info.url)")

        if let paused = ChromeHelper.isVideoPaused(url: info.url), paused {
            ChromeHelper.playVideoInChrome(url: info.url)
        }
        
        appWindowController?.showWindow(nil)
        appWindowController?.playerController.playYouTubeURL(info.url)
    }


    @MainActor @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @MainActor @objc func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(self)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appWindowController?.saveWindowFrame()
    }
}