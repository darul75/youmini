import AppKit

// Shortcuts are now defined in Constants.Shortcuts

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
            if event.characters == Constants.Shortcuts.savePlaylist {
                savePlaylist()
            } else if event.characters == Constants.Shortcuts.loadPlaylist {
                loadPlaylist()
            } else if event.characters == Constants.Shortcuts.quit {
                appDelegate?.quitApp()
            } else if event.characters == Constants.Shortcuts.toggleView {
                toggleMiniView()
            } else if event.characters == Constants.Shortcuts.detection {
                toggleAutoPlay()
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
        let openItem = NSMenuItem(title: Constants.UI.Menu.openWindow, action: #selector(forwardToggleWindow), keyEquivalent: "")
        let miniViewItem = NSMenuItem(title: Constants.UI.Menu.miniView, action: #selector(toggleMiniView), keyEquivalent: Constants.Shortcuts.toggleView)
        let saveItem = NSMenuItem(title: Constants.UI.Menu.savePlaylist, action: #selector(savePlaylist), keyEquivalent: Constants.Shortcuts.savePlaylist)
        let loadItem = NSMenuItem(title: Constants.UI.Menu.loadPlaylist, action: #selector(loadPlaylist), keyEquivalent: Constants.Shortcuts.loadPlaylist)
        let autoDetectionItem = NSMenuItem(title: Constants.UI.Menu.enableDetection, action: #selector(toggleAutoPlay), keyEquivalent: Constants.Shortcuts.detection)
        let aboutItem = NSMenuItem(title: Constants.UI.Menu.about, action: #selector(forwardShowAbout), keyEquivalent: "")
        let quitItem = NSMenuItem(title: Constants.UI.Menu.quit, action: #selector(forwardQuitApp), keyEquivalent: Constants.Shortcuts.quit)

        menu.addItem(openItem)
        menu.addItem(miniViewItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(saveItem)
        menu.addItem(loadItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(autoDetectionItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)

        openItem.target = self
        miniViewItem.target = self
        saveItem.target = self
        loadItem.target = self
        autoDetectionItem.target = self
        aboutItem.target = self
        quitItem.target = self

        menu.delegate = self
        statusItem.menu = menu

        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "YouTubeMini")
        appMenu.addItem(withTitle: Constants.UI.Menu.aboutApp, action: #selector(forwardShowAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: Constants.UI.Menu.quitApp, action: #selector(forwardQuitApp), keyEquivalent: Constants.Shortcuts.quit)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu

        updateMenuItems()
    }

    private func updateMenuItems() {
        guard let menu = statusItem.menu else { return }
        if let openItem = menu.items.first(where: { $0.action == #selector(forwardToggleWindow) }) {
            let isVisible = appDelegate?.appWindowController?.window?.isVisible == true
            openItem.title = isVisible ? Constants.UI.Menu.hideWindow : Constants.UI.Menu.showWindow
        }
        if let miniViewItem = menu.items.first(where: { $0.action == #selector(toggleMiniView) }) {
            miniViewItem.title = appDelegate?.isMiniViewMode == true ? Constants.UI.Menu.splitView : Constants.UI.Menu.miniView
        }
        if let autoPlayItem = menu.items.first(where: { $0.action == #selector(toggleAutoPlay) }) {
            autoPlayItem.title = appDelegate?.isDetectionEnabled == true ? Constants.UI.Menu.disableDetection : Constants.UI.Menu.enableDetection
        }
    }

    @MainActor @objc func toggleMiniView() {
        guard let appDelegate = appDelegate else { return }
        appDelegate.isMiniViewMode.toggle()
        appDelegate.appWindowController?.toggleMiniView(appDelegate.isMiniViewMode)
        UserDefaults.standard.set(appDelegate.isMiniViewMode, forKey: "com.youtube.mini.miniViewMode")
        updateMenuItems()
    }

    @MainActor @objc func toggleAutoPlay() {
        guard let appDelegate = appDelegate else { return }
        appDelegate.isDetectionEnabled.toggle()
        UserDefaults.standard.set(appDelegate.isDetectionEnabled, forKey: "com.youtube.mini.detectionEnabled")
        appDelegate.startAutoPlayTimer()
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
            alert.messageText = Constants.Alerts.Messages.noPlaylistToSave
            alert.informativeText = Constants.Alerts.Descriptions.playlistEmpty
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
                    alert.messageText = Constants.Alerts.Messages.saveFailed
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
                    UserDefaults.standard.set(0, forKey: Constants.UserDefaultsKeys.currentIndex)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = Constants.Alerts.Messages.loadFailed
                    alert.informativeText = "Could not load playlist: \(error.localizedDescription)"
                    alert.beginSheetModal(for: window)
                }
            }
        }
    }
}