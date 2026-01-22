import AppKit
import AVKit
@preconcurrency import YouTubeKit

class PlayerViewController: NSViewController {
    var playerView: AVPlayerView!
    var player: AVPlayer?
    var spinner: NSProgressIndicator!
    
    override func loadView() {
        let view = NSView()
        view.wantsLayer = true
        
        playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerView)
        
        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        view.addSubview(spinner)
        
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        self.view = view
        
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(videoDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func playYouTubeURL(_ url: String) {
        showSpinner()
        
        Task { @MainActor in
            do {
                let youTube = YouTube(url: URL(string: url)!)
                let stream = try await youTube.streams
                    .filter { $0.fileExtension == .mp4 }
                    .highestResolutionStream()
                
                guard let streamURL = stream?.url else {
                    hideSpinner()
                    return
                }
                
                player = AVPlayer(url: streamURL)
                playerView.player = player
                player?.play()
                
                hideSpinner()
                
            } catch {
                print("Failed to load video: \(error)")
                hideSpinner()
            }
        }
    }
    
    func stopPlayback() {
        player?.pause()
        player = nil
        playerView.player = nil
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
        UserDefaults.standard.removeObject(forKey: "com.youtube.mini.wasPlayingOnQuit")
        print("🏁 Cleared wasPlayingOnQuit flag (video finished)")
        (NSApp.delegate as? AppDelegate)?.playNextVideo()
    }
    
    func replaceContentWithPlayer() {
        // This might need to be handled by the parent controller
        // Since mini-view affects the whole window
    }
    
    func restoreSplitViewContent() {
        // This might need to be handled by the parent controller
    }
}