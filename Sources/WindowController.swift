import AppKit
import AVKit
@preconcurrency import YouTubeKit

class WindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSplitViewDelegate {
    var splitView: NSSplitView!
    var tableView: NSTableView!
    var playerView: AVPlayerView!
    var spinner: NSProgressIndicator!
    var player: AVPlayer?
    var currentURL: String?
    let historyPanelWidth: CGFloat = 200



    init() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
                            styleMask: [.titled, .resizable, .closable, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        // Position centered
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            panel.setFrameOrigin(NSPoint(x: (screenFrame.width - 800) / 2, y: (screenFrame.height - 400) / 2))
        }

        super.init(window: panel)

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

        // Left: History table
        let leftView = NSView()
        tableView = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Title"))
        column.title = "History"
        column.width = historyPanelWidth - 20
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.doubleAction = #selector(tableClick)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        leftView.addSubview(scrollView)
        scrollView.frame = leftView.bounds

        // Right: Player
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

        // Spinner on player
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

        // Set initial frames
        let totalWidth = splitView.bounds.width
        let leftWidth = historyPanelWidth
        let rightWidth = max(100, totalWidth - leftWidth - splitView.dividerThickness)
        splitView.subviews[0].frame = NSRect(x: 0, y: 0, width: leftWidth, height: splitView.bounds.height)
        splitView.subviews[1].frame = NSRect(x: leftWidth + splitView.dividerThickness, y: 0, width: rightWidth, height: splitView.bounds.height)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = NSTableCellView()
        cellView.textField = NSTextField()
        cellView.textField?.isEditable = false
        cellView.textField?.isBordered = false
        cellView.textField?.backgroundColor = .clear
        cellView.textField?.stringValue = (NSApp.delegate as? AppDelegate)?.playedHistory[row].title ?? ""
        cellView.addSubview(cellView.textField!)
        cellView.textField?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cellView.textField!.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            cellView.textField!.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            cellView.textField!.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        // Highlight current playing video
        if row == (NSApp.delegate as? AppDelegate)?.currentPlayingIndex {
            cellView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        } else {
            cellView.layer?.backgroundColor = NSColor.clear.cgColor
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
            playYouTubeURL(url)
        }
    }

    @objc func videoDidFinish() {
        (NSApp.delegate as? AppDelegate)?.playNextVideo()
    }

    func playYouTubeURL(_ urlString: String) {
        print("playYouTubeURL called with: \(urlString)")
        currentURL = urlString
        // Remove previous observer
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        // Show spinner
        DispatchQueue.main.async {
            self.spinner.isHidden = false
            self.spinner.startAnimation(nil)
        }

        Task {
            do {
                let youTube = YouTube(url: url)
                let streams = try await youTube.streams
                await MainActor.run {
                    // Prefer HD (720p+) if available, else highest
                    let hdStream = streams.filterVideoAndAudio()
                        .filter(byResolution: { ($0 ?? 0) >= 720 })
                        .filter { $0.isNativelyPlayable }
                        .highestResolutionStream()
                    let stream = hdStream ?? streams.filterVideoAndAudio()
                        .filter { $0.isNativelyPlayable }
                        .highestResolutionStream()
                        if let stream {
                            print("Stream URL: \(stream.url)")
                            player = AVPlayer(url: stream.url)
                            playerView.player = player
                            // Add observer for end of video
                            NotificationCenter.default.addObserver(self, selector: #selector(videoDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
                            player?.play()
                            print("Started playing video")
                        }
                    // Hide spinner
                    self.spinner.stopAnimation(nil)
                    self.spinner.isHidden = true
                }
            } catch {
                await MainActor.run {
                    print("Error extracting video: \(error)")
                    spinner.stopAnimation(nil)
                    spinner.isHidden = true
                }
            }
        }
    }
}