import AppKit

@MainActor
class StatusBarManager: NSObject, NSMenuDelegate {
    var statusItem: NSStatusItem!
    weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        setupStatusBar()
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

        let miniViewItem = NSMenuItem(title: "Mini View", action: #selector(toggleMiniView), keyEquivalent: "")
        miniViewItem.target = self
        menu.addItem(miniViewItem)

        let aboutItem = NSMenuItem(title: "About", action: #selector(forwardShowAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(forwardQuitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu

        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "YouTubeMini")
        appMenu.addItem(withTitle: "About YouTubeMini", action: #selector(forwardShowAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit YouTubeMini", action: #selector(forwardQuitApp), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu

        // Update menu items based on state
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
        print("MiniView mode \(appDelegate.isMiniViewMode ? "enabled" : "disabled")")
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
}