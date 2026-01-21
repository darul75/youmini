import AppKit
import AVKit
@preconcurrency import YouTubeKit

class WindowController: NSWindowController {
    var playerView: AVPlayerView!
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
            // Player view: fill entire window
            playerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Spinner: center in player view
            spinner.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: playerView.centerYAnchor)
        ])
    }

    func playYouTubeURL(_ urlString: String) {
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
}