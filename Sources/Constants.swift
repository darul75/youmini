struct Constants {
    struct UI {
        struct Menu {
            static let openWindow = "Open Window"
            static let hideWindow = "Hide Window"
            static let showWindow = "Show Window"
            static let miniView = "Mini View"
            static let splitView = "Split View"
            static let savePlaylist = "Save Playlist..."
            static let loadPlaylist = "Load Playlist..."
            static let enableDetection = "Enable Detection"
            static let disableDetection = "Disable Detection"
            static let about = "About"
            static let quit = "Quit"
            static let aboutApp = "About YouTubeMini"
            static let quitApp = "Quit YouTubeMini"
        }
        
        struct Buttons {
            static let addSymbol = "+"
            static let removeSymbol = "-"
            static let add = "Add"
        }
        
        struct Placeholders {
            static let youtubeURL = "Paste YouTube URL here"
        }
        
        struct Table {
            static let historyColumn = "History"
        }
        
        struct Status {
            static let loading = "Loading..."
        }
    }
    
    struct Alerts {
        struct Messages {
            static let noPlaylistToSave = "No Playlist to Save"
            static let saveFailed = "Save Failed"
            static let loadFailed = "Load Failed"
            static let invalidURL = "Invalid URL"
            static let noSelection = "No Selection"
        }

        struct Descriptions {
            static let playlistEmpty = "The playlist is empty."
            static let validYouTubeURL = "Please enter a valid YouTube watch or shorts URL."
            static let selectItemToRemove = "Please select an item to remove."
        }
    }
    
    struct Shortcuts {
        static let quit = "q"
        static let loadPlaylist = "o"
        static let savePlaylist = "s"
        static let toggleView = "t"
        static let detection = "d"
    }
    
    struct UserDefaultsKeys {
        static let wasPlayingOnQuit = "com.youtube.mini.wasPlayingOnQuit"
        static let detectionEnabled = "com.youtube.mini.detectionEnabled"
        static let miniViewMode = "com.youtube.mini.miniViewMode"
        static let currentIndex = "com.youtube.mini.currentIndex"
        static let history = "com.youtube.mini.history"
        static let windowFrame = "com.youtube.mini.windowFrame"
    }
}