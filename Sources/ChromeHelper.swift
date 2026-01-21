import Foundation

class ChromeHelper {
    static func getYouTubeTabs() -> [(url: String, title: String)] {
        let script = """
        tell application "Google Chrome"
            if not running then return ""
            set resultList to ""
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "youtube.com/watch" then
                        set resultList to resultList & (URL of t) & "|" & (title of t) & ";"
                    end if
                end repeat
            end repeat
            return resultList
        end tell
        """
        
        guard let appleScript = NSAppleScript(source: script) else { return [] }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript error: \(error)")
            return []
        }
        
        var tabs: [(String, String)] = []
        if let resultString = result.stringValue {
            let entries = resultString.split(separator: ";").filter { !$0.isEmpty }
            for entry in entries {
                let parts = entry.split(separator: "|", maxSplits: 1)
                if parts.count == 2 {
                    tabs.append((String(parts[0]), String(parts[1])))
                }
            }
        }
        return tabs
    }
    
    static func isVideoPaused(url: String) -> Bool? {
        let script = """
        tell application "Google Chrome"
            set targetTab to first tab of windows whose URL is "\(url)"
            if targetTab is not missing value then
                return execute targetTab javascript "document.querySelector('video')?.paused || true"
            end if
            return "true"
        end tell
        """
        
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript error: \(error)")
            return nil
        }
        
        if let stringResult = result.stringValue {
            return stringResult == "true"
        }
        return nil
    }
    
    static func playVideoInChrome(url: String) {
        let script = """
        tell application "Google Chrome"
            set targetTab to first tab of windows whose URL is "\(url)"
            if targetTab is not missing value then
                execute targetTab javascript "document.querySelector('video')?.play();"
            end if
        end tell
        """
        
        guard let appleScript = NSAppleScript(source: script) else { return }
        var error: NSDictionary?
        _ = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript error: \(error)")
        }
    }
}