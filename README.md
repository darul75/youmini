# YouTubeMini

A sleek macOS menu bar app that detects YouTube videos playing in Chrome and provides a mini player experience with playlist management.

## Features

- 🎵 **Chrome integration** - Works with Google Chrome
- 📱 **Mini player** - Compact video player that stays on top
- 📋 **Smart playlist** - Automatically detects and manages YouTube tabs
- 🎬 **MiniView mode** - Immersive full-screen player experience
- 💾 **Persistent history** - Remembers your video history across app restarts
- 🔄 **Intelligent auto-resume** - Only resumes videos that were actively playing
- 🖥️ **Window position memory** - Remembers window size and position
- 🎯 **Accurate titles** - Fetches real YouTube video titles
- 🔇 **Smart audio management** - Stops playback when window is hidden
- 📐 **Collapsible Panel** - Toggle button in divider to collapse/expand playlist for full video focus
- 🛡️ **Local Server Fallback** - Run YouTubeKit-Server locally for enhanced reliability when YouTube changes their API

## Installation

### Requirements
- macOS 11.0 or later
- Google Chrome (for YouTube detection)

### Download
1. Download the latest `YouTubeMini.zip` from the releases
2. Extract the zip file
3. Move `YouTubeMini.app` to your Applications folder
4. Right-click `YouTubeMini.app` and select "Open" (first time only to bypass Gatekeeper)

### Permissions
The app requires automation permissions to detect YouTube tabs:
- **System Preferences** → **Security & Privacy** → **Privacy** → **Automation**
- Enable YouTubeMini for **Google Chrome**

### Optional: Local Server Fallback

For enhanced reliability when YouTube changes their API, you can run a local YouTubeKit-Server instance as a fallback:

1. **Clone and setup the server:**
   ```bash
   git clone https://github.com/alexeichhorn/YouTubeKit-Server.git
   cd YouTubeKit-Server
   npm install
   ```

2. **Run the server locally:**
   ```bash
   npm run dev
   ```
   Server will run at `http://localhost:8787`

3. **Configure the app** to connect to your local server (implementation details in development documentation)

This provides an additional layer of reliability when YouTube's API changes break local extraction.

## Usage

### Basic Usage
1. Launch YouTubeMini (appears in menu bar)
2. Open YouTube videos in Chrome
3. Click the menu bar icon to see detected videos
4. Double-click a video to play it in the mini player

### MiniView Mode
- Select **"Mini View"** from the menu bar to enter immersive mode
- Removes window chrome for distraction-free viewing
- Select **"Split View"** to return to normal mode

### Keyboard Shortcuts
- `Cmd+Q` - Quit the app

## Features in Detail

### Chrome Integration
- Automatically scans Chrome tabs for YouTube videos
- Updates playlist in real-time as you browse
- No configuration needed - seamless Chrome integration

### Mini Player
- Floating video player that stays above other windows
- Click and drag to reposition
- Resize window to adjust player size

### Smart Playlist Management
- Videos are added to history when detected
- Maintains chronological order (newest first)
- Duplicate URLs are consolidated
- History persists across app restarts

### Intelligent Auto-Resume
- Only resumes videos that were actively playing when you quit
- Respects your pause decisions - won't resume paused videos
- One-time resume - clears flag after auto-playing

### Window Persistence
- Remembers window size and position across sessions
- Works in both normal and MiniView modes
- Gracefully handles screen changes

## Troubleshooting

### Video Won't Play
- Ensure you have the latest version of YouTubeKit
- Check that YouTube videos load normally in your browser
- Try restarting the app

### Videos Not Detected
- Grant automation permissions in System Preferences
- Ensure YouTube tabs are fully loaded
- Try refreshing the YouTube page

### App Won't Start
- Right-click the app and select "Open" to bypass Gatekeeper
- Check Console.app for error messages

## Privacy

YouTubeMini only accesses:
- Browser tab URLs (to detect YouTube videos)
- Browser tab titles (for display purposes)
- No browsing history or personal data is accessed

## Disclaimer

**YouTubeMini is an independent project and is not affiliated with Google, YouTube, or Apple.**

This app uses YouTubeKit library to extract video streams from YouTube. Please be aware that:

- **Terms of Service**: Using third-party YouTube clients may violate YouTube's Terms of Service. Use at your own risk.
- **Copyright**: Only play videos you have the right to view. Respect copyright laws.
- **No Warranty**: This software is provided "as is" without warranty of any kind.
- **Responsibility**: The authors are not responsible for any misuse or legal issues arising from use of this software.

## Development

### Building from Source
```bash
git clone <repository-url>
cd youtube-mini
swift build -c release
./build-app.sh
```

### Dependencies
- Swift 6.0+
- YouTubeKit (for video extraction)
- macOS 11.0+ (for modern APIs)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## License

This project is open source. See LICENSE file for details.

## Contributing

Contributions welcome! Please open issues for bugs or feature requests.

## Support

For issues or questions, please open a GitHub issue.