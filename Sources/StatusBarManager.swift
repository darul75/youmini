import AppKit

let SHORTCUT_QUIT = "q"
let SHORTCUT_LOAD_PLAYLIST = "o"
let SHORTCUT_SAVE_PLAYLIST = "s"
let SHORTCUT_TOGGLE_VIEW = "t"

struct PlaylistItem: Codable {
    let url: String
    let title: String
}

@MainActor
class StatusBarManager: NSObject, NSMenuDelegate {
    var statusItem: NSStatusItem!
    weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        setupStatusBar()
        setupGlobalShortcuts()
    }

    private func createPlayButtonIcon() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 2, y: 2))
        path.line(to: NSPoint(x: 2, y: 14))
        path.line(to: NSPoint(x: 13, y: 8))
        path.close()
        path.fill()
        image.unlockFocus()
        return image
    }

    private func setupGlobalShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, event.modifierFlags.contains(.command), event.modifierFlags.intersection(.deviceIndependentFlagsMask).isSubset(of: [.command]) else {
                return event
            }
            if event.characters == SHORTCUT_SAVE_PLAYLIST {
                self.savePlaylist()
                return nil
            } else if event.characters == SHORTCUT_LOAD_PLAYLIST {
                self.loadPlaylist()
                return nil
            } else if event.characters == SHORTCUT_QUIT {
                self.forwardQuitApp()
                return nil
            } else if event.characters == SHORTCUT_TOGGLE_VIEW {
                self.toggleMiniView()
                return nil
            }
            return event
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = createPlayButtonIcon()
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Window", action: #selector(forwardToggleWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let miniViewItem = NSMenuItem(title: "Mini View", action: #selector(toggleMiniView), keyEquivalent: SHORTCUT_TOGGLE_VIEW)
        miniViewItem.target = self
        menu.addItem(miniViewItem)

        menu.addItem(NSMenuItem.separator())

        let saveItem = NSMenuItem(title: "Save Playlist...", action: #selector(savePlaylist), keyEquivalent: SHORTCUT_SAVE_PLAYLIST)
        saveItem.target = self
        menu.addItem(saveItem)

        let loadItem = NSMenuItem(title: "Load Playlist...", action: #selector(loadPlaylist), keyEquivalent: SHORTCUT_LOAD_PLAYLIST)
        loadItem.target = self
        menu.addItem(loadItem)

        menu.addItem(NSMenuItem.separator())
        let aboutItem = NSMenuItem(title: "About", action: #selector(forwardShowAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(forwardQuitApp), keyEquivalent: SHORTCUT_QUIT)
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu

        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "YouTubeMini")
        appMenu.addItem(withTitle: "About YouTubeMini", action: #selector(forwardShowAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit YouTubeMini", action: #selector(forwardQuitApp), keyEquivalent: SHORTCUT_QUIT)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu

        updateMenuItems()
    }

    private func updateMenuItems() {
        guard let menu = statusItem.menu else { return }
        if let openItem = menu.items.first(where: { $0.action == #selector(forwardToggleWindow) }) {
            let isVisible = appDelegate?.appWindowController?.window?.isVisible == true
            openItem.title = isVisible ? "Hide Window" : "Show Window"
        }
        if let miniViewItem = menu.items.first(where: { $0.action == #selector(toggleMiniView) }) {
            miniViewItem.title = appDelegate?.isMiniViewMode == true ? "Split View" : "Mini View"
        }
    }

    @MainActor @objc func toggleMiniView() {
        guard let appDelegate = appDelegate else { return }
        appDelegate.isMiniViewMode.toggle()
        appDelegate.appWindowController?.toggleMiniView(appDelegate.isMiniViewMode)
        UserDefaults.standard.set(appDelegate.isMiniViewMode, forKey: "com.youtube.mini.miniViewMode")
        updateMenuItems()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenuItems()
    }

    @objc func forwardToggleWindow() {
        appDelegate?.toggleWindow()
    }

    @objc func forwardShowAbout() {
        appDelegate?.showAbout()
    }

    @objc func forwardQuitApp() {
        appDelegate?.quitApp()
    }

    @objc func savePlaylist() {
        guard let history = appDelegate?.playedHistory, !history.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Playlist to Save"
            alert.informativeText = "The playlist is empty."
            alert.beginSheetModal(for: appDelegate?.appWindowController?.window ?? NSApplication.shared.mainWindow!)
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["json"]
        savePanel.nameFieldStringValue = "playlist.json"
        let window = appDelegate?.appWindowController?.window ?? NSApplication.shared.mainWindow!
        savePanel.beginSheetModal(for: window) { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let items = history.map { PlaylistItem(url: $0.url, title: $0.title) }
                    let data = try JSONEncoder().encode(items)
                    try data.write(to: url)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Save Failed"
                    alert.informativeText = "Could not save playlist: \(error.localizedDescription)"
                    alert.beginSheetModal(for: window)
                }
            }
        }
    }

    @objc func loadPlaylist() {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["json"]
        let window = appDelegate?.appWindowController?.window ?? NSApplication.shared.mainWindow!
        openPanel.beginSheetModal(for: window) { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let loadedItems = try JSONDecoder().decode([PlaylistItem].self, from: data)
                    let loadedHistory = loadedItems.map { (url: $0.url, title: $0.title) } as [Video]
                    self.appDelegate?.playedHistory = loadedHistory
                    self.appDelegate?.currentPlayingIndex = nil
                    self.appDelegate?.saveHistory()
                    self.appDelegate?.reloadListData()

                    self.appDelegate?.appWindowController?.listingController.tableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    UserDefaults.standard.set(0, forKey: "com.youtube.mini.currentIndex")
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Load Failed"
                    alert.informativeText = "Could not load playlist: \(error.localizedDescription)"
                    alert.beginSheetModal(for: window)
                }
            }
        }
    }
}