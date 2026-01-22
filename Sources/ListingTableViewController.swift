import AppKit

class ListingTableViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var tableView: NSTableView!
    
    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(tableDoubleClick(_:))
        tableView.headerView = nil
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Title"))
        column.title = "History"
        column.width = 200
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        self.view = scrollView
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return (NSApp.delegate as? AppDelegate)?.playedHistory.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return (NSApp.delegate as? AppDelegate)?.playedHistory[row].title ?? ""
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = NSTableCellView()
        cellView.wantsLayer = true
        cellView.textField = NSTextField()
        cellView.textField?.isEditable = false
        cellView.textField?.isBordered = false
        cellView.textField?.backgroundColor = .clear
        cellView.textField?.stringValue = (NSApp.delegate as? AppDelegate)?.playedHistory[row].title ?? ""
        cellView.textField?.cell?.lineBreakMode = .byTruncatingTail
        cellView.textField?.cell?.wraps = false
        cellView.addSubview(cellView.textField!)
        cellView.textField?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cellView.textField!.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: -8),
            cellView.textField!.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: 0),
            cellView.textField!.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        if row == (NSApp.delegate as? AppDelegate)?.currentPlayingIndex {
            cellView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
            cellView.textField?.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        } else {
            cellView.layer?.backgroundColor = NSColor.clear.cgColor
            cellView.textField?.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView, tableView == self.tableView else { return }
        
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            (NSApp.delegate as? AppDelegate)?.currentPlayingIndex = selectedRow
            UserDefaults.standard.set(selectedRow, forKey: "com.youtube.mini.currentIndex")
        }
    }
    
    @MainActor @objc func tableDoubleClick(_ sender: NSTableView) {
        let row = sender.clickedRow
        if let history = (NSApp.delegate as? AppDelegate)?.playedHistory,
           row >= 0 && row < history.count {
            let url = history[row].url
            (NSApp.delegate as? AppDelegate)?.currentPlayingIndex = row
            (NSApp.delegate as? AppDelegate)?.saveHistory()
            tableView.reloadData()
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            (NSApp.delegate as? AppDelegate)?.appWindowController?.playYouTubeURL(url)
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return row >= 0 && row < ((NSApp.delegate as? AppDelegate)?.playedHistory.count ?? 0)
    }
}