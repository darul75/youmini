import AppKit
import AVKit
@preconcurrency import YouTubeKit

class AppWindowController: NSWindowController, NSSplitViewDelegate {
    var splitView: NSSplitView!
    var storedSplitView: NSSplitView?
    var listingController: ListingTableViewController!
    var playerController: PlayerViewController!
    let historyPanelWidth: CGFloat = 200
    let collapsedPanelWidth: CGFloat = 0
    let buttonPanelHeight: CGFloat = 40
    let buttonPanelDeployedHeight: CGFloat = 80
    var isMiniViewMode: Bool = false
    var isLeftPanelCollapsed: Bool = false
    var originalWindowFrame: NSRect?
    var addButton: NSButton!
    var removeButton: NSButton!
    var toggleButton: NSButton!
    var urlField: NSTextField!
    var submitButton: NSButton!
    var buttonPanel: NSView!
    var buttonPanelHeightConstraint: NSLayoutConstraint!
    var urlFieldConstraints: [NSLayoutConstraint] = []
    var submitButtonConstraints: [NSLayoutConstraint] = []

    init() {
        let mainPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
                            styleMask: [.titled, .resizable, .closable, .nonactivatingPanel, .miniaturizable],
                            backing: .buffered,
                            defer: false)
        mainPanel.level = .floating
        mainPanel.isMovableByWindowBackground = true

        mainPanel.title = Constants.appName

        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            mainPanel.setFrameOrigin(NSPoint(x: (screenFrame.width - 800) / 2, y: (screenFrame.height - 400) / 2))
        }

        super.init(window: mainPanel)

        setupUI()
        restorePanelState()
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResize(_:)), name: NSWindow.didResizeNotification, object: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        guard let contentView = window?.contentView else { return }

        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .paneSplitter
        splitView.autoresizingMask = [.width, .height]
        contentView.addSubview(splitView)
        splitView.frame = contentView.bounds
        splitView.delegate = self

        let leftView = NSView()
        listingController = ListingTableViewController()

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.distribution = .fill
        stackView.spacing = 0
        leftView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: leftView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leftView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: leftView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: leftView.bottomAnchor)
        ])

        stackView.addArrangedSubview(listingController.view)

        buttonPanel = NSView()
        buttonPanel.translatesAutoresizingMaskIntoConstraints = false
        buttonPanelHeightConstraint = buttonPanel.heightAnchor.constraint(equalToConstant: buttonPanelHeight)
        buttonPanelHeightConstraint.isActive = true
        stackView.addArrangedSubview(buttonPanel)

        addButton = NSButton(title: "+", target: self, action: #selector(showAddField))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        buttonPanel.addSubview(addButton)

        removeButton = NSButton(title: "-", target: self, action: #selector(removeEntry))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        buttonPanel.addSubview(removeButton)

        NSLayoutConstraint.activate([
            addButton.topAnchor.constraint(equalTo: buttonPanel.topAnchor, constant: 8),
            addButton.leadingAnchor.constraint(equalTo: buttonPanel.leadingAnchor, constant: 8),
            removeButton.topAnchor.constraint(equalTo: buttonPanel.topAnchor, constant: 8),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 8),
            removeButton.trailingAnchor.constraint(lessThanOrEqualTo: buttonPanel.trailingAnchor, constant: -8)
        ])

        let rightView = NSView()
        playerController = PlayerViewController()
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        rightView.addSubview(playerController.view)
        NSLayoutConstraint.activate([
            playerController.view.topAnchor.constraint(equalTo: rightView.topAnchor),
            playerController.view.leadingAnchor.constraint(equalTo: rightView.leadingAnchor),
            playerController.view.trailingAnchor.constraint(equalTo: rightView.trailingAnchor),
            playerController.view.bottomAnchor.constraint(equalTo: rightView.bottomAnchor)
        ])

        splitView.addArrangedSubview(leftView)
        splitView.addArrangedSubview(rightView)
        
        toggleButton = NSButton(title: Constants.UI.Buttons.toggleCollapse, target: self, action: #selector(toggleLeftPanel))
        toggleButton.toolTip = Constants.UI.Tooltips.toggleCollapse
        toggleButton.bezelStyle = .inline
        toggleButton.isBordered = false
        toggleButton.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
        toggleButton.wantsLayer = true
        toggleButton.layer?.zPosition = 1000
        contentView.addSubview(toggleButton)
        updateToggleButtonPosition()
    }

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        let dividerThickness = splitView.dividerThickness
        let totalWidth = splitView.bounds.width

        let leftWidth = splitView.subviews[0].frame.width
        let minWidth = isLeftPanelCollapsed ? 0 : historyPanelWidth
        var newLeftWidth = max(minWidth, leftWidth)

        if oldSize.width > totalWidth && leftWidth < minWidth {
            newLeftWidth = minWidth
        }

        newLeftWidth = min(newLeftWidth, totalWidth - dividerThickness - 100)
        let newRightWidth = totalWidth - newLeftWidth - dividerThickness

        splitView.subviews[0].frame = NSRect(x: 0, y: 0, width: newLeftWidth, height: splitView.bounds.height)
        splitView.subviews[1].frame = NSRect(x: newLeftWidth + dividerThickness, y: 0, width: newRightWidth, height: splitView.bounds.height)
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        updateToggleButtonPosition()
    }

    func saveWindowFrame() {
        guard let frame = window?.frame else {
            print("saveWindowFrame: No window frame to save")
            return
        }
        let frameDict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(frameDict, forKey: Constants.UserDefaultsKeys.windowFrame)
    }

    func restoreWindowFrame() {
        guard let frameDict = UserDefaults.standard.dictionary(forKey: Constants.UserDefaultsKeys.windowFrame) as? [String: CGFloat] else {
            print("❌ No saved window frame dictionary found")
            return
        }

        guard let x = frameDict["x"],
            let y = frameDict["y"],
            let width = frameDict["width"],
            let height = frameDict["height"] else {
            print("❌ Invalid frame dictionary: \(frameDict)")
            return
        }

        let frame = NSRect(x: x, y: y, width: width, height: height)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(frame.origin) }),
           screen.frame.intersects(frame) {
            window?.setFrame(frame, display: true, animate: false)
        } else {
            print("⚠️ Saved frame is off-screen or invalid, using default")
        }
    }

    func toggleMiniView(_ enabled: Bool) {
        isMiniViewMode = enabled

        if enabled {
            originalWindowFrame = window?.frame

            window?.styleMask.remove(.titled)
            window?.styleMask.remove(.closable)
            window?.titleVisibility = .hidden
            if #available(macOS 11.0, *) {
                window?.titlebarSeparatorStyle = .none
            }

            replaceContentWithPlayer()
        } else {
            window?.styleMask.insert(.titled)
            window?.styleMask.insert(.closable)
            window?.styleMask.insert(.resizable)
            window?.titleVisibility = .visible

            restoreSplitViewContent()
        }
    }

    private func replaceContentWithPlayer() {
        guard let contentView = window?.contentView else { return }

        storedSplitView = splitView
        splitView.removeFromSuperview()
        contentView.addSubview(playerController.view)
        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            playerController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            playerController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            playerController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        contentView.layoutSubtreeIfNeeded()
    }

    private func restoreSplitViewContent() {
        guard let contentView = window?.contentView,
            let storedSplitView = storedSplitView else { return }

        playerController.view.removeFromSuperview()
        contentView.addSubview(storedSplitView)
        splitView = storedSplitView

        storedSplitView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            storedSplitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            storedSplitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            storedSplitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            storedSplitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        guard let rightView = splitView.arrangedSubviews.last else { return }
        rightView.addSubview(playerController.view)

        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerController.view.topAnchor.constraint(equalTo: rightView.topAnchor),
            playerController.view.leadingAnchor.constraint(equalTo: rightView.leadingAnchor),
            playerController.view.trailingAnchor.constraint(equalTo: rightView.trailingAnchor),
            playerController.view.bottomAnchor.constraint(equalTo: rightView.bottomAnchor)
        ])

        self.storedSplitView = nil

        contentView.layoutSubtreeIfNeeded()
    }

    @objc func showAddField() {
        let isShowing = buttonPanelHeightConstraint.constant == buttonPanelHeight
        buttonPanelHeightConstraint.constant = isShowing ? buttonPanelDeployedHeight : buttonPanelHeight
        if urlField == nil {
            urlField = NSTextField()
            urlField.placeholderString = Constants.UI.Placeholders.youtubeURL
            urlField.translatesAutoresizingMaskIntoConstraints = false
            buttonPanel.addSubview(urlField)

            submitButton = NSButton(title: Constants.UI.Buttons.add, target: self, action: #selector(submitURL))
            submitButton.translatesAutoresizingMaskIntoConstraints = false
            buttonPanel.addSubview(submitButton)

            urlFieldConstraints = [
                urlField.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 8),
                urlField.leadingAnchor.constraint(equalTo: buttonPanel.leadingAnchor, constant: 8),
                urlField.bottomAnchor.constraint(lessThanOrEqualTo: buttonPanel.bottomAnchor, constant: -8),
                urlField.trailingAnchor.constraint(lessThanOrEqualTo: submitButton.leadingAnchor, constant: -8)
            ]
            submitButtonConstraints = [
                submitButton.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 8),
                submitButton.leadingAnchor.constraint(equalTo: urlField.trailingAnchor, constant: 8),
                submitButton.trailingAnchor.constraint(equalTo: buttonPanel.trailingAnchor, constant: -8),
                submitButton.widthAnchor.constraint(equalToConstant: 50)
            ]
        }
        if isShowing {
            NSLayoutConstraint.activate(urlFieldConstraints)
            NSLayoutConstraint.activate(submitButtonConstraints)
            urlField.isHidden = false
            submitButton.isHidden = false
            window?.makeFirstResponder(urlField)
        } else {
            NSLayoutConstraint.deactivate(urlFieldConstraints)
            NSLayoutConstraint.deactivate(submitButtonConstraints)
            urlField.isHidden = true
            submitButton.isHidden = true
        }
    }

    @objc func submitURL() {
        let url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        guard url.contains("youtube.com/watch") || url.contains("youtube.com/shorts") else {
            let alert = NSAlert()
            alert.messageText = Constants.Alerts.Messages.invalidURL
            alert.informativeText = Constants.Alerts.Descriptions.validYouTubeURL
            alert.runModal()
            return
        }

        (NSApp.delegate as? AppDelegate)?.addToHistory(url: url, title: Constants.UI.Status.loading)

        NSLayoutConstraint.deactivate(urlFieldConstraints)
        NSLayoutConstraint.deactivate(submitButtonConstraints)
        urlField.removeFromSuperview()
        submitButton.removeFromSuperview()
        urlField = nil
        submitButton = nil
        urlFieldConstraints = []
        submitButtonConstraints = []
        buttonPanelHeightConstraint.constant = 40
    }

    @objc func removeEntry() {
        let selectedRow = listingController.tableView.selectedRow
        guard selectedRow >= 0 else {
            let alert = NSAlert()
            alert.messageText = Constants.Alerts.Messages.noSelection
            alert.informativeText = Constants.Alerts.Descriptions.selectItemToRemove
            alert.beginSheetModal(for: window!)
            return
        }

        (NSApp.delegate as? AppDelegate)?.removeFromHistory(at: selectedRow)
    }

    @objc func toggleLeftPanel() {
        isLeftPanelCollapsed.toggle()

        toggleButton.title = isLeftPanelCollapsed ? Constants.UI.Buttons.toggleExpand : Constants.UI.Buttons.toggleCollapse
        toggleButton.toolTip = isLeftPanelCollapsed ? Constants.UI.Tooltips.toggleExpand : Constants.UI.Tooltips.toggleCollapse

        UserDefaults.standard.set(isLeftPanelCollapsed, forKey: Constants.UserDefaultsKeys.leftPanelCollapsed)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            if isLeftPanelCollapsed {
                splitView.setPosition(0, ofDividerAt: 0)
            } else {
                splitView.setPosition(historyPanelWidth, ofDividerAt: 0)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateToggleButtonPosition()
        }
    }

    private func updateToggleButtonPosition() {
        guard let contentView = window?.contentView else { return }

        let leftPanel = splitView.arrangedSubviews[0]
        let leftPanelFrame = leftPanel.frame

        let dividerX = leftPanelFrame.maxX + splitView.dividerThickness / 2
        let centerY = contentView.bounds.midY

        toggleButton.frame = NSRect(
            x: dividerX - 10,
            y: centerY - 10,
            width: 20,
            height: 20
        )
    }

    func restorePanelState() {
        isLeftPanelCollapsed = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.leftPanelCollapsed)

        DispatchQueue.main.async {
            let targetWidth = self.isLeftPanelCollapsed ? 0 : self.historyPanelWidth
            self.splitView.setPosition(targetWidth, ofDividerAt: 0)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.toggleButton.title = self.isLeftPanelCollapsed ? Constants.UI.Buttons.toggleExpand : Constants.UI.Buttons.toggleCollapse
                self.toggleButton.toolTip = self.isLeftPanelCollapsed ? Constants.UI.Tooltips.toggleExpand : Constants.UI.Tooltips.toggleCollapse
                self.updateToggleButtonPosition()
            }
        }
    }

    @objc private func windowDidResize(_ notification: Notification) {
        updateToggleButtonPosition()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}