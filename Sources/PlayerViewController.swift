import AppKit
import AVKit
import AppKit
@preconcurrency import YouTubeKit

class PlayerViewController: NSViewController, NSGestureRecognizerDelegate {
    var playerView: AVPlayerView!
    var player: AVPlayer?
    var spinner: NSProgressIndicator!
    var currentURL: String?
    private var keyMonitor: Any?
    
    override func loadView() {
        playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        playerView.addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: playerView.centerYAnchor)
        ])

        self.view = playerView

        setupNotifications()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 49 {
                self?.togglePlayback()
                return nil
            }
            return event
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(videoDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func playYouTubeURL(_ urlString: String) {
        stopPlayback()
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

        showSpinner()

        Task {
            do {
                let testRequest = URLRequest(url: url)
                let (_, response) = try await URLSession.shared.data(for: testRequest)
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP response status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("HTTP error: Status code \(httpResponse.statusCode)")
                    }
                }
                
                let youTube = YouTube(url: url, methods: [.local, .remote(serverURL: URL(string: "ws://localhost:8787")!)])                
                let streams = try await youTube.streams
                await MainActor.run {
                    let videoAudioStreams = streams.filterVideoAndAudio()
                    let hdStreams = videoAudioStreams
                        .filter(byResolution: { ($0 ?? 0) >= 720 })
                        .filter { $0.isNativelyPlayable }
                    let hdStream = hdStreams.highestResolutionStream()
                    let fallbackStreams = streams.filterVideoAndAudio()
                        .filter { $0.isNativelyPlayable }

                    let stream = hdStream ?? fallbackStreams.highestResolutionStream()
                    if let stream {
                        player = AVPlayer(url: stream.url)
                        playerView.player = player
                        NotificationCenter.default.addObserver(self, selector: #selector(videoDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
                        player?.addObserver(self, forKeyPath: "rate", options: [.new, .old], context: nil)
                        player?.play()
                        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.wasPlayingOnQuit)
                    }
                    hideSpinner()
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


                    hideSpinner()
                }
            }
        }
    }

    func stopPlayback() {
        if let player = player {
            player.removeObserver(self, forKeyPath: "rate")
        }
        player?.pause()
        player = nil
        playerView.player = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.wasPlayingOnQuit)
    }
    
    func showSpinner() {
        spinner.isHidden = false
        spinner.startAnimation(self)
    }
    
    func hideSpinner() {
        spinner.isHidden = true
        spinner.stopAnimation(self)
    }
    
    @objc func videoDidFinish() {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.wasPlayingOnQuit)        
        (NSApp.delegate as? AppDelegate)?.playNextVideo()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate", object is AVPlayer {
            let newRate = change?[.newKey] as? Float ?? 0
            let oldRate = change?[.oldKey] as? Float ?? 0
            if newRate == 0 && oldRate > 0 {
                UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.wasPlayingOnQuit)
            } else if newRate > 0 && oldRate == 0 {
                UserDefaults.standard.set(true, forKey: "com.youtube.mini.wasPlayingOnQuit")
            }
        }
    }

    private func togglePlayback() {
        guard let player = player else { return }

        if player.rate > 0 {
            player.pause()
        } else {
            player.play()
        }
    }

    @objc private func handleVideoClick(_ gesture: NSClickGestureRecognizer) {
        togglePlayback()
    }
}