import AppKit
import AVKit
@preconcurrency import YouTubeKit

class WindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSplitViewDelegate {
    var splitView: NSSplitView!
    var storedSplitView: NSSplitView?
    var listingTableView: NSTableView!
    var playerView: AVPlayerView!
    var spinner: NSProgressIndicator!
    var player: AVPlayer?
    var currentURL: String?
    let historyPanelWidth: CGFloat = 200
    let buttonPanelHeight: CGFloat = 40
    let buttonPanelDeployedHeight: CGFloat = 80
    var isMiniViewMode: Bool = false
    var originalWindowFrame: NSRect?
    var addButton: NSButton!
    var removeButton: NSButton!
    var urlField: NSTextField!
    var submitButton: NSButton!
    var buttonPanel: NSView!
    var buttonPanelHeightConstraint: NSLayoutConstraint!
    var urlFieldConstraints: [NSLayoutConstraint] = []
    var submitButtonConstraints: [NSLayoutConstraint] = []

    init() {
        let mainPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
                            styleMask: [.titled, .resizable, .closable, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        mainPanel.level = .floating
        mainPanel.isMovableByWindowBackground = true

        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            mainPanel.setFrameOrigin(NSPoint(x: (screenFrame.width - 800) / 2, y: (screenFrame.height - 400) / 2))
        }

        super.init(window: mainPanel)

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        guard let contentView = window?.contentView else { return }

        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .paneSplitter
        splitView.autoresizingMask = [.width, .height]
        contentView.addSubview(splitView)
        splitView.frame = contentView.bounds
        splitView.delegate = self

        let leftView = NSView()
        listingTableView = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Title"))
        column.title = "History"
        column.isEditable = false
        listingTableView.addTableColumn(column)
        listingTableView.headerView = nil
        listingTableView.dataSource = self
        listingTableView.delegate = self
        listingTableView.allowsMultipleSelection = false
        listingTableView.target = self
        listingTableView.doubleAction = #selector(tableClick)
        listingTableView.headerView = nil

        let listingScrollView = NSScrollView()
        listingScrollView.documentView = listingTableView
        listingScrollView.hasVerticalScroller = true
        listingScrollView.contentInsets = NSEdgeInsets(top: 0, left: -4, bottom: 0, right: -4)
        listingScrollView.translatesAutoresizingMaskIntoConstraints = false
        

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.distribution = .fill
        stackView.spacing = 0
        leftView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: leftView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leftView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: leftView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: leftView.bottomAnchor)
        ])

        stackView.addArrangedSubview(listingScrollView)

        buttonPanel = NSView()
        buttonPanel.translatesAutoresizingMaskIntoConstraints = false
        buttonPanelHeightConstraint = buttonPanel.heightAnchor.constraint(equalToConstant: buttonPanelHeight)
        buttonPanelHeightConstraint.isActive = true
        stackView.addArrangedSubview(buttonPanel)

        addButton = NSButton(title: "+", target: self, action: #selector(showAddField))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        buttonPanel.addSubview(addButton)

        removeButton = NSButton(title: "-", target: self, action: #selector(removeEntry))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        buttonPanel.addSubview(removeButton)

        NSLayoutConstraint.activate([
            addButton.topAnchor.constraint(equalTo: buttonPanel.topAnchor, constant: 8),
            addButton.leadingAnchor.constraint(equalTo: buttonPanel.leadingAnchor, constant: 8),
            removeButton.topAnchor.constraint(equalTo: buttonPanel.topAnchor, constant: 8),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 8),
            removeButton.trailingAnchor.constraint(lessThanOrEqualTo: buttonPanel.trailingAnchor, constant: -8)
        ])

        let rightView = NSView()
        playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        rightView.addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: rightView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: rightView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: rightView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: rightView.bottomAnchor)
        ])

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.isHidden = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        playerView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: playerView.centerYAnchor)
        ])

        splitView.addArrangedSubview(leftView)
        splitView.addArrangedSubview(rightView)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = NSTableCellView()
        cellView.wantsLayer = true
        cellView.textField = NSTextField()
        cellView.textField?.isEditable = false
        cellView.textField?.isBordered = false
        cellView.textField?.backgroundColor = .clear
        cellView.textField?.stringValue = (NSApp.delegate as? AppDelegate)?.playedHistory[row].title ?? ""
        cellView.textField?.cell?.lineBreakMode = .byTruncatingTail
        cellView.textField?.cell?.wraps = false
        cellView.addSubview(cellView.textField!)
        cellView.textField?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cellView.textField!.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: -8),
            cellView.textField!.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: 0),
            cellView.textField!.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        // Highlight current playing video
        if row == (NSApp.delegate as? AppDelegate)?.currentPlayingIndex {
            cellView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
            cellView.textField?.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        } else {
            cellView.layer?.backgroundColor = NSColor.clear.cgColor
            cellView.textField?.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }

        return cellView
    }

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        let dividerThickness = splitView.dividerThickness
        let totalWidth = splitView.bounds.width

        // Get current left width
        let leftWidth = splitView.subviews[0].frame.width

        // Ensure left pane has at least historyPanelWidth
        var newLeftWidth = max(historyPanelWidth, leftWidth)

        // If resizing and left is smaller, enforce min
        if oldSize.width > totalWidth && leftWidth < historyPanelWidth {
            newLeftWidth = historyPanelWidth
        }

        // Cap to leave space for right
        newLeftWidth = min(newLeftWidth, totalWidth - dividerThickness - 100)

        // Calculate right width
        let newRightWidth = totalWidth - newLeftWidth - dividerThickness

        // Set frames
        splitView.subviews[0].frame = NSRect(x: 0, y: 0, width: newLeftWidth, height: splitView.bounds.height)
        splitView.subviews[1].frame = NSRect(x: newLeftWidth + dividerThickness, y: 0, width: newRightWidth, height: splitView.bounds.height)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        let count = (NSApp.delegate as? AppDelegate)?.playedHistory.count ?? 0
        print("History count: \(count)")
        return count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return (NSApp.delegate as? AppDelegate)?.playedHistory[row].title ?? ""
    }

    @MainActor @objc func tableClick(_ sender: NSTableView) {
        let row = sender.clickedRow
        if let history = (NSApp.delegate as? AppDelegate)?.playedHistory,
           row >= 0 && row < history.count {
            let url = history[row].url
            (NSApp.delegate as? AppDelegate)?.currentPlayingIndex = row
            (NSApp.delegate as? AppDelegate)?.saveHistory()
            listingTableView.reloadData()
            listingTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            playYouTubeURL(url)
        }
    }

    @objc func videoDidFinish() {
        UserDefaults.standard.removeObject(forKey: "com.youtube.mini.wasPlayingOnQuit")
        print("🏁 Cleared wasPlayingOnQuit flag (video finished)")
        (NSApp.delegate as? AppDelegate)?.playNextVideo()
    }

    func stopPlayback() {
        if let player = player {
            player.removeObserver(self, forKeyPath: "rate")
        }
        player?.pause()
        player = nil
        playerView.player = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        print("Video playback stopped")
        UserDefaults.standard.removeObject(forKey: "com.youtube.mini.wasPlayingOnQuit")
        print("🛑 Cleared wasPlayingOnQuit flag")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate", object is AVPlayer {
            let newRate = change?[.newKey] as? Float ?? 0
            let oldRate = change?[.oldKey] as? Float ?? 0

            if newRate == 0 && oldRate > 0 {
                UserDefaults.standard.removeObject(forKey: "com.youtube.mini.wasPlayingOnQuit")
                print("⏸️ Video paused - cleared wasPlayingOnQuit flag")
            } else if newRate > 0 && oldRate == 0 {
                UserDefaults.standard.set(true, forKey: "com.youtube.mini.wasPlayingOnQuit")
                print("▶️ Video resumed - set wasPlayingOnQuit = true")
            }
        }
    }

    func saveWindowFrame() {
        guard let frame = window?.frame else {
            print("saveWindowFrame: No window frame to save")
            return
        }
        let frameDict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(frameDict, forKey: "com.youtube.mini.windowFrame")
        print("✅ Saved window frame: \(frame)")
    }

    func restoreWindowFrame() {
        guard let frameDict = UserDefaults.standard.dictionary(forKey: "com.youtube.mini.windowFrame") as? [String: CGFloat] else {
            print("❌ No saved window frame dictionary found")
            return
        }

        guard let x = frameDict["x"],
              let y = frameDict["y"],
              let width = frameDict["width"],
              let height = frameDict["height"] else {
            print("❌ Invalid frame dictionary: \(frameDict)")
            return
        }

        let frame = NSRect(x: x, y: y, width: width, height: height)
        print("📐 Attempting to restore frame: \(frame)")

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(frame.origin) }),
           screen.frame.intersects(frame) {
            window?.setFrame(frame, display: true, animate: false)
            print("✅ Restored window frame: \(frame)")
        } else {
            print("⚠️ Saved frame is off-screen or invalid, using default")
        }
    }

    func toggleMiniView(_ enabled: Bool) {
        isMiniViewMode = enabled

        if enabled {
            // Store current window frame for restoration
            originalWindowFrame = window?.frame

            // Remove title bar completely for true MiniView but keep resizable
            window?.styleMask.remove(.titled)
            window?.styleMask.remove(.closable)
            window?.titleVisibility = .hidden
            if #available(macOS 11.0, *) {
                window?.titlebarSeparatorStyle = .none
            }

            // Replace entire content view with player
            replaceContentWithPlayer()
        } else {
            // Restore title bar and controls
            window?.styleMask.insert(.titled)
            window?.styleMask.insert(.closable)
            window?.styleMask.insert(.resizable)
            window?.titleVisibility = .visible

            // Restore split view content
            restoreSplitViewContent()
        }
    }

    private func replaceContentWithPlayer() {
        guard let contentView = window?.contentView else { return }

        storedSplitView = splitView
        splitView.removeFromSuperview()
        contentView.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        contentView.layoutSubtreeIfNeeded()
    }

    private func restoreSplitViewContent() {
        guard let contentView = window?.contentView,
              let storedSplitView = storedSplitView else { return }

        playerView.removeFromSuperview()
        contentView.addSubview(storedSplitView)
        splitView = storedSplitView

        storedSplitView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            storedSplitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            storedSplitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            storedSplitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            storedSplitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        guard let rightView = splitView.arrangedSubviews.last else { return }
        rightView.addSubview(playerView)

        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: rightView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: rightView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: rightView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: rightView.bottomAnchor)
        ])

        self.storedSplitView = nil

        contentView.layoutSubtreeIfNeeded()
    }

    func playYouTubeURL(_ urlString: String) {
        stopPlayback()
        print("playYouTubeURL called with: \(urlString)")
        currentURL = urlString
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        guard let url = URL(string: urlString) else {
            print("Invalid URL format: \(urlString)")
            return
        }

        print("URL validation passed. Host: \(url.host ?? "nil"), Path: \(url.path), Query: \(url.query ?? "nil")")

        guard url.host?.contains("youtube.com") == true,
              url.path.contains("/watch") || url.path.contains("/shorts") else {
            print("Not a valid YouTube watch/shorts URL: \(urlString)")
            return
        }

        print("YouTube URL validation passed")

        DispatchQueue.main.async {
            self.spinner.isHidden = false
            self.spinner.startAnimation(nil)
        }

        Task {
            do {
                print("Starting YouTube extraction for URL: \(urlString)")

                let testRequest = URLRequest(url: url)
                let (_, response) = try await URLSession.shared.data(for: testRequest)
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP response status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("HTTP error: Status code \(httpResponse.statusCode)")
                    }
                }

                print("Creating YouTubeKit YouTube object...")
                let youTube = YouTube(url: url)
                print("YouTube object created, fetching streams...")
                let streams = try await youTube.streams
                print("Successfully extracted \(streams.count) streams")
                await MainActor.run {
                    print("Processing \(streams.count) total streams")
                    let videoAudioStreams = streams.filterVideoAndAudio()
                    print("Found \(videoAudioStreams.count) video+audio streams")

                    let hdStreams = videoAudioStreams
                        .filter(byResolution: { ($0 ?? 0) >= 720 })
                        .filter { $0.isNativelyPlayable }
                    print("Found \(hdStreams.count) HD (720p+) natively playable streams")

                    let hdStream = hdStreams.highestResolutionStream()
                    print("Selected HD stream: \(hdStream != nil ? "YES" : "NO")")

                    let fallbackStreams = streams.filterVideoAndAudio()
                        .filter { $0.isNativelyPlayable }
                    print("Found \(fallbackStreams.count) fallback natively playable streams")

                    let stream = hdStream ?? fallbackStreams.highestResolutionStream()
                    print("Final selected stream: \(stream != nil ? "YES" : "NO")")
                if let stream {
                    print("Stream URL: \(stream.url)")
                    player = AVPlayer(url: stream.url)
                    playerView.player = player
                    // Add observer for end of video
                    NotificationCenter.default.addObserver(self, selector: #selector(videoDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
                    // Add observer for play/pause changes
                    player?.addObserver(self, forKeyPath: "rate", options: [.new, .old], context: nil)
                    player?.play()
                    print("Started playing video")
                    // Mark that video is now playing
                    UserDefaults.standard.set(true, forKey: "com.youtube.mini.wasPlayingOnQuit")
                    print("🎬 Set wasPlayingOnQuit = true")
                        }
                    // Hide spinner
                    self.spinner.stopAnimation(nil)
                    self.spinner.isHidden = true
                }
            } catch {
                await MainActor.run {
                    print("❌ Error extracting video: \(error)")
                    print("Error type: \(type(of: error))")
                    print("Error localized description: \(error.localizedDescription)")

                    // Check if it's a YouTubeKit error
                    if let ytError = error as? YouTubeKit.YouTubeKitError {
                        print("YouTubeKit error: \(ytError.rawValue)")
                        switch ytError {
                        case .extractError:
                            print("💡 YouTubeKit extractError: YouTube may have changed their page format, or the video may be unavailable/private/region-blocked")
                        case .htmlParseError:
                            print("💡 YouTubeKit htmlParseError: Failed to parse YouTube's HTML structure")
                        case .videoUnavailable:
                            print("💡 Video is marked as unavailable by YouTube")
                        case .videoPrivate:
                            print("💡 Video is private")
                        case .videoAgeRestricted:
                            print("💡 Video is age-restricted")
                        case .videoRegionBlocked:
                            print("💡 Video is region-blocked")
                        case .membersOnly:
                            print("💡 Video is members-only")
                        case .liveStreamError:
                            print("💡 Cannot extract from livestream")
                        case .recordingUnavailable:
                            print("💡 Recording unavailable")
                        case .maxRetriesExceeded:
                            print("💡 Max retries exceeded - network issues?")
                        case .regexMatchError:
                            print("💡 Regex matching failed - YouTube format changed")
                        }
                    }


                    spinner.stopAnimation(nil)
                    spinner.isHidden = true
                }
            }
        }
    }

    @objc func showAddField() {
        let isShowing = buttonPanelHeightConstraint.constant == buttonPanelHeight
        buttonPanelHeightConstraint.constant = isShowing ? buttonPanelDeployedHeight : buttonPanelHeight
        if urlField == nil {
            urlField = NSTextField()
            urlField.placeholderString = "Paste YouTube URL here"
            urlField.translatesAutoresizingMaskIntoConstraints = false
            buttonPanel.addSubview(urlField)

            submitButton = NSButton(title: "Add", target: self, action: #selector(submitURL))
            submitButton.translatesAutoresizingMaskIntoConstraints = false
            buttonPanel.addSubview(submitButton)

            urlFieldConstraints = [
                urlField.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 8),
                urlField.leadingAnchor.constraint(equalTo: buttonPanel.leadingAnchor, constant: 8),
                urlField.bottomAnchor.constraint(lessThanOrEqualTo: buttonPanel.bottomAnchor, constant: -8),
                urlField.trailingAnchor.constraint(lessThanOrEqualTo: submitButton.leadingAnchor, constant: -8)
            ]
            submitButtonConstraints = [
                submitButton.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 8),
                submitButton.leadingAnchor.constraint(equalTo: urlField.trailingAnchor, constant: 8),
                submitButton.trailingAnchor.constraint(equalTo: buttonPanel.trailingAnchor, constant: -8),
                submitButton.widthAnchor.constraint(equalToConstant: 50)
            ]
        }
        if isShowing {
            NSLayoutConstraint.activate(urlFieldConstraints)
            NSLayoutConstraint.activate(submitButtonConstraints)
            urlField.isHidden = false
            submitButton.isHidden = false
            window?.makeFirstResponder(urlField)
        } else {
            NSLayoutConstraint.deactivate(urlFieldConstraints)
            NSLayoutConstraint.deactivate(submitButtonConstraints)
            urlField.isHidden = true
            submitButton.isHidden = true
        }
    }

    @objc func submitURL() {
        let url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        guard url.contains("youtube.com/watch") || url.contains("youtube.com/shorts") else {
            let alert = NSAlert()
            alert.messageText = "Invalid URL"
            alert.informativeText = "Please enter a valid YouTube watch or shorts URL."
            alert.runModal()
            return
        }

        (NSApp.delegate as? AppDelegate)?.addToHistory(url: url, title: "Loading...")

        NSLayoutConstraint.deactivate(urlFieldConstraints)
        NSLayoutConstraint.deactivate(submitButtonConstraints)
        urlField.removeFromSuperview()
        submitButton.removeFromSuperview()
        urlField = nil
        submitButton = nil
        urlFieldConstraints = []
        submitButtonConstraints = []
        buttonPanelHeightConstraint.constant = 40
    }

    @objc func removeEntry() {
        let selectedRow = listingTableView.selectedRow
        guard selectedRow >= 0 else {
            let alert = NSAlert()
            alert.messageText = "No Selection"
            alert.informativeText = "Please select an item to remove."
            alert.beginSheetModal(for: window!)
            return
        }

        (NSApp.delegate as? AppDelegate)?.removeFromHistory(at: selectedRow)
    }
}