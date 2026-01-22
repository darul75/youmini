# Changelog

All notable changes to YouTubeMini will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/spec2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-01-22

### Added
- Support for YouTube Shorts videos in Chrome tab detection and playback
- StatusBarManager class for better separation of UI concerns
- Playlist save/load feature: Export/import playlist as JSON via status bar menu (Cmd+S to save, Cmd+O to load)
- Auto-save loaded playlists to UserDefaults

### Fixed
- Double-clicking video in history now selects the row, enabling remove action without "No Selection" alert
- Alert dialogs now centered on the app window instead of screen center
- Reduced left/right margins in video history table for tighter layout
- Background video audio stops when switching to a new video

### Changed
- Improved add URL panel constraint management to prevent minus button shifting when toggling panel
- Refactored status bar and menu setup into dedicated StatusBarManager class
- Major code refactoring: moved table view logic to `ListingTableViewController` and player logic to `PlayerViewController` for better separation of concerns
- Added keyboard shortcuts for menu actions (Cmd+Q to quit, Cmd+T to toggle MiniView, Cmd+O to load playlist, Cmd+S to save playlist)
- Enhanced table row selection persistence - current index is saved on single-click selection

## [1.0.1] - 2026-01-21

### Added
- Intelligent auto-resume feature that detects video pause/play state
- Only resumes videos that were actually playing when app quit
- Player rate monitoring to clear resume flag when video is paused
- Version display in About menu
- Proper app versioning system with VERSION file

### Removed
- Safari browser support - app now focuses exclusively on Chrome integration

### Fixed
- Window frame persistence now saves frame before MiniView exit
- App termination now properly saves window frame

### Changed
- Hidden NSTableView column header for cleaner UI

## [1.0.0] - Initial Release

### Added
- Multi-browser YouTube detection (Chrome and Safari)
- Mini player with floating window
- Smart playlist management with history
- MiniView mode for immersive full-screen experience
- Persistent history and playback state
- Window size and position memory
- Accurate YouTube video title fetching
- Auto-stop playback when window is hidden
- Comprehensive error logging and debugging
- Professional distribution bundle

### Technical Features
- UserDefaults-based persistence system
- AVPlayer integration for video playback
- AppleScript automation for browser control
- YouTubeKit library for video extraction
- macOS menu bar integration
- Swift 6 concurrency and safety

### Development
- Swift Package Manager setup
- Automated build script
- Code linting and type checking
- Comprehensive debugging features

---

## Detailed Commit History

### Core Features
- **cc4963e** - Initial commit with basic app structure
- **56a6f6d** - Add logic to start paused videos in Chrome before playing in mini app
- **49333c7** - Complete AppDelegate and WindowController changes for Chrome tab detection
- **09062dc** - Make submenu update dynamically when menu opens
- **8f7945a** - Add auto-play when Chrome YouTube URL changes
- **193c311** - Integrate split view with clickable video history on left pane (200px default)
- **a9aeb00** - Sync history list with detected YouTube tabs from submenu
- **5c35f3c** - Remove Play Chrome YouTube menu; sync history in real-time via timer
- **bd23783** - Add auto-play on launch for single video, sequential playback on finish, visual highlight for current video, history appends new items to end
- **078b421** - Fix text wrapping in history list, add bold + background visual indicator for current video, reload table on selection/play to update styling
- **c21669c** - Replace text menubar icon with minimalist play button icon

### Distribution & Build
- **fe89d24** - Add build script and distributable .app bundle for sharing with friends
- **dad7710** - Add AGENTS.md with lint and build commands

### Error Handling & Debugging
- **435fd16** - Add comprehensive logging for YouTube extraction errors to debug extractError issues

### Library Updates
- **da01f3b** - Update YouTubeKit to version 0.4.1 for better YouTube compatibility
- **fcb37cb** - Update distribution bundle with YouTubeKit 0.4.1

### Bug Fixes
- **8c3014b** - Fix duplicate titles bug by fetching real YouTube video titles using YouTubeKit metadata instead of Chrome tab titles
- **3e749ca** - Update distribution bundle with duplicate titles fix

### Code Quality
- **d8d19cc** - Clean up code warnings - remove unreachable code and unnecessary error casting
- **0c166b4** - Fix Timer concurrency warning by using selector-based Timer API
- **673fcb1** - Complete code cleanup - fix all remaining warnings and improve code quality
- **be58fc1** - Update distribution bundle with final code cleanup

### Persistence Features
- **1e74cde** - Add persistent history feature - save/load history and current playback position using UserDefaults
- **f04783e** - Update distribution bundle with persistent history feature
- **c8c3657** - Add window frame persistence - save and restore window size and position across app restarts
- **e6e2a83** - Update distribution bundle with window frame persistence
- **4dd1c03** - Fix window frame persistence - save frame BEFORE MiniView exit to preserve user's actual window size/position
- **849e330** - Update distribution bundle with window frame persistence fix
- **31fd59d** - Add window frame saving on app termination - ensures frame is saved even when quitting directly with Cmd+Q
- **405bfe2** - Update distribution bundle with app termination window frame saving

### UI Improvements
- **fe662d4** - Add stop video playback when hiding window feature - pauses video and cleans resources when window is closed
- **5cd5564** - Update distribution bundle with stop playback on hide feature
- **c746040** - Add MiniView feature - toggle between split view and immersive full-screen player mode
- **ef2fc3c** - Update distribution bundle with MiniView feature
- **9828f82** - Fix MiniView persistence - apply mode to window on app startup and make window resizable in MiniView mode
- **3f5aba4** - Update distribution bundle with MiniView persistence fixes
- **1d274c3** - Hide NSTableView header to remove column resize handle and create cleaner UI
- **ac70a1d** - Update distribution bundle with hidden table header

### Auto-Resume Intelligence
- **8c8f34b** - Add intelligent auto-resume feature that detects video pause/play state - only resumes videos that were actually playing when app quit
- **f0165e1** - Update distribution bundle with intelligent auto-resume feature