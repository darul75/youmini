import AppKit
import AVKit
@preconcurrency import YouTubeKit

class WindowController: NSWindowController, NSTextFieldDelegate {
    var playerView: AVPlayerView!
    var urlField: NSTextField!
    var playButton: NSButton!
    var spinner: NSProgressIndicator!
    var player: AVPlayer?



    init() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
                            styleMask: [.resizable, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        // Position at top center
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            panel.setFrameOrigin(NSPoint(x: (screenFrame.width - 400) / 2, y: screenFrame.height - 280 - 50))
        }

        super.init(window: panel)

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        guard let contentView = window?.contentView else { return }

        // URL input field
        urlField = NSTextField()
        urlField.placeholderString = "Enter YouTube URL"
        urlField.delegate = self
        urlField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(urlField)

        // Play button
        playButton = NSButton()
        playButton.title = "Play"
        playButton.target = self
        playButton.action = #selector(playVideo)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playButton)

        // Spinner
        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.isHidden = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        // Player view
        playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playerView)

        // Move spinner to playerView for overlay
        playerView.addSubview(spinner)

        // Constraints
        NSLayoutConstraint.activate([
            // Player view: fill most of window
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: urlField.topAnchor, constant: -10),

            // URL field: bottom left
            urlField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            urlField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            urlField.widthAnchor.constraint(equalToConstant: 300),
            urlField.heightAnchor.constraint(equalToConstant: 24),

            // Play button: bottom right
            playButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            playButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            playButton.widthAnchor.constraint(equalToConstant: 70),
            playButton.heightAnchor.constraint(equalToConstant: 24),

            // Spinner: center in player view
            spinner.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: playerView.centerYAnchor)
        ])
    }

    @objc func playVideo() {
        let urlString = urlField.stringValue
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
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
                        player = AVPlayer(url: stream.url)
                        playerView.player = player
                        player?.play()
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

    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField, textField == urlField {
            playVideo()
        }
    }
}