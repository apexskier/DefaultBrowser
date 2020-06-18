//
//  AppDelegate.swift
//  DefaultBrowser
//
//  Created by Cameron Little on 10/23/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Cocoa
import CoreServices

private var KVOContext = 0

// Menu item tags used to fetch them without a direct reference
enum MenuItemTag: Int {
    case BrowserListTop = 1
    case BrowserListBottom
    case usePrimary
}

// Height of each menu item's icon
let MENU_ITEM_HEIGHT: CGFloat = 16

// Adds a bundle id field to menu items and the browser's icon
// used in menu bar and preferences primary browser picker
class BrowserMenuItem: NSMenuItem {
    private var _bundleIdentifier: String?
    var height: CGFloat?
    var bundleIdentifier: String? {
        get {
            return _bundleIdentifier
        }
        set (value) {
            _bundleIdentifier = value
            let workspace = NSWorkspace.shared
            if let bid = self.bundleIdentifier, let path = workspace.absolutePathForApplication(withBundleIdentifier: bid) {
                image = workspace.icon(forFile: path)
                if let size = self.height {
                    image?.size = NSSize(width: size, height: size)
                }
            }
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var descriptiveAppNamesCheckbox: NSButton!
    @IBOutlet weak var browsersPopUp: NSPopUpButton!
    @IBOutlet weak var showWindowCheckbox: NSButton!
    @IBOutlet weak var setAsDefaultWarningText: NSTextField!
    @IBOutlet weak var blocklistTable: NSTableView!
    @IBOutlet weak var blocklistView: NSScrollView!
    @IBOutlet weak var blocklistHeightConstraint: NSLayoutConstraint!
    

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let workspace = NSWorkspace.shared
    
    // a list of all valid browsers installed
    var validBrowsers = getAllBrowsers()
    
    // keep an ordered list of running browsers
    var runningBrowsers: [NSRunningApplication] = []
    
    var lastActiveApplication: NSRunningApplication = NSRunningApplication()
    
    // maybe will be used when manually opening a link in a specific app
    var skipNextBrowserSort = true
    
    // an explicitly chosen default browser
    var explicitBrowser: String? = nil
    
    // the user's "system" default browser
    var usePrimaryBrowser = false
    
    // user settings
    let defaults = ThisDefaults()
    
    // get around a bug in the browser list when this app wasn't set as the default OS browser
    var firstTime = false
    
    
    // MARK: NSApplicationDelegate
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Watch for when the user opens and quits applications
        workspace.addObserver(self, forKeyPath: "runningApplications", options: [.old, .new], context: &KVOContext)
        // Watch for when the user switches applications
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(applicationChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // Watch for the user opening links
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent),
            forEventClass: UInt32(kInternetEventClass),
            andEventID: UInt32(kAEGetURL)
        )
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        let selfBundleID = Bundle.main.bundleIdentifier!
        var selfName = getAppName(bundleId: selfBundleID)
        if selfName == "Unknown Application" {
            selfName = "Default Browser"
        }
        
        defaults.register(defaults: defaultSettings)
        
        if !isCurrentlyDefault() {
            let notDefaultAlert = NSAlert()
            notDefaultAlert.addButton(withTitle: "Set As Default")
            notDefaultAlert.addButton(withTitle: "Cancel")
            notDefaultAlert.messageText = "Set Default Browser"
            notDefaultAlert.informativeText = "\(selfName) must be set as your default browser. Your current default will be remembered."
            notDefaultAlert.alertStyle = .warning
            switch notDefaultAlert.runModal() {
            case NSApplication.ModalResponse.alertFirstButtonReturn:
                setAsDefault()
            default:
                break
            }
        } else {
            self.setAsDefaultWarningText.isHidden = true
        }
        
        setOpenOnLogin()
        
        // open window?
        window.isReleasedWhenClosed = false
        if defaults.openWindowOnLaunch {
            window.makeKeyAndOrderFront(self)
        }
        
        // set up menu bar
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
            button.allowsMixedState = true
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About \(selfName)", action: #selector(openWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openWindow), keyEquivalent: ","))
        let browserListTop = NSMenuItem.separator()
        browserListTop.tag = MenuItemTag.BrowserListTop.rawValue
        menu.addItem(browserListTop)
        let browserListBottom = NSMenuItem.separator()
        browserListBottom.tag = MenuItemTag.BrowserListBottom.rawValue
        menu.addItem(browserListBottom)
        let usePrimaryMenuItem = NSMenuItem(title: "Use Primary Browser", action: #selector(usePrimary), keyEquivalent: "0")
        usePrimaryMenuItem.tag = MenuItemTag.usePrimary.rawValue
        menu.addItem(usePrimaryMenuItem)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(terminate), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        resetBrowsers()
        updateMenuItems()
        
        // set up preferences
        setUpPreferencesBrowsers()
        showWindowCheckbox.state = defaults.openWindowOnLaunch ? .on : .off
        descriptiveAppNamesCheckbox.state = defaults.detailedAppNames ? .on : .off
        
        blocklistTable.dataSource = self
        blocklistTable.delegate = self
        updateBlocklistTable()
    }
    
    func setUpPreferencesBrowsers() {
        browsersPopUp.removeAllItems()
        var selectedPrimaryBrowser: NSMenuItem? = nil
        validBrowsers.sort()
        validBrowsers.forEach { bid in
            let name = defaults.detailedAppNames ? getDetailedAppName(bundleId: bid) : getAppName(bundleId: bid)
            let menuItem = BrowserMenuItem(title: name, action: nil, keyEquivalent: "")
            menuItem.height = MENU_ITEM_HEIGHT
            menuItem.bundleIdentifier = bid
            let primaryBid = defaults.primaryBrowser.lowercased()
            if primaryBid == bid.lowercased() {
                selectedPrimaryBrowser = menuItem
            }
            browsersPopUp.menu?.addItem(menuItem)
        }
        browsersPopUp.select(selectedPrimaryBrowser)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        workspace.removeObserver(self, forKeyPath: "runningApplications")
        workspace.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSAppleEventManager.shared().removeEventHandler(forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }

    
    // MARK: Signal/Notification Responses
    
    // Respond to the user opening a link
    @objc func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // not sure if the format always matches what I expect
        if let urlDescriptor = event.atIndex(1), let urlStr = urlDescriptor.stringValue, let url = URL(string: urlStr) {
            let theBrowser = getOpeningBrowserId()
            print("opening: \(url) in \(theBrowser)")
            workspace.open(
                [url],
                withAppBundleIdentifier: theBrowser,
                options: NSWorkspace.LaunchOptions.default,
                additionalEventParamDescriptor: replyEvent,
                launchIdentifiers: nil
            )
        } else {
            // TODO: error
            let errorAlert = NSAlert()
            let appName = FileManager.default.displayName(atPath: Bundle.main.bundlePath)
            errorAlert.messageText = "Error"
            errorAlert.informativeText = "\(appName) couldn't understand an URL. Please report this error."
            errorAlert.alertStyle = .critical
            errorAlert.addButton(withTitle: "Okay")
            errorAlert.addButton(withTitle: "Report")
            switch errorAlert.runModal() {
            case NSApplication.ModalResponse.alertSecondButtonReturn:
                let bodyText = "\(appName) couldn't handle to some url.\n\nInformation:\n```\n\(event)\n```".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                let to = "cameron@camlittle.com"
                let subject = "\(appName) Error".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                
                let mailto = "mailto:\(to)?subject=\(subject)&body=\(bodyText)"
                
                workspace.open(URL(string: mailto)!)
            default:
                break
            }
        }
    }
    
    // Respond to the user opening or quitting applications
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        var apps: [NSRunningApplication]? = nil
        
        //	This uses the new guard statement to return early if there's no change dictionary.
        guard let change = change else {
            return
        }
        
        if let rv = change[NSKeyValueChangeKey.kindKey] as? UInt, let kind = NSKeyValueChange(rawValue: rv) {
            switch kind {
            case .insertion:
                //	Get the inserted apps (usually only one, but you never know)
                apps = change[NSKeyValueChangeKey.newKey] as? [NSRunningApplication]
            case .removal:
                //	Get the removed apps (usually only one, but you never know)
                apps = change[NSKeyValueChangeKey.oldKey] as? [NSRunningApplication]
            default:
                return	// nothing to refresh; should never happen, but...
            }
        }
        
        updateBrowsers(apps: apps)
    }
    
    // Respond to the user changing applications
    @objc func applicationChange(notification: NSNotification) {
        if !skipNextBrowserSort {
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self.runningBrowsers.sort { a, b -> Bool in
                    if a.bundleIdentifier == app.bundleIdentifier {
                        return true
                    }
                    return false
                }
                lastActiveApplication = app
                updateMenuItems()
            }
        }
        skipNextBrowserSort = false
    }
    
    
    // MARK: Management Methods
    
    // update list of currently running browsers
    func updateBrowsers(apps: [NSRunningApplication]?) {
        if let apps = apps {
            /// Use one of the Dictionary extensions to merge the changes into procdict.
            apps.filter({ return $0.bundleIdentifier != nil }).forEach { app in
                let remove = app.isTerminated // insert or remove?
                
                if (validBrowsers.contains(app.bundleIdentifier!)) {
                    if remove {
                        if let index = runningBrowsers.firstIndex(of: app) {
                            runningBrowsers.remove(at: index)
                        }
                    } else {
                        runningBrowsers.append(app)
                    }
                    print("remove: \(remove); \(app.bundleIdentifier!)")
                }
            }
            updateMenuItems()
        }
    }
    
    // decide which browser should be used to open a link
    func getOpeningBrowserId() -> String {
        if usePrimaryBrowser {
            return defaults.primaryBrowser
        } else {
            let blocklist = defaults.browserBlocklist
            return explicitBrowser
                ?? runningBrowsers.filter({
                    return !blocklist.contains($0.bundleIdentifier!)
                }).first?.bundleIdentifier
                ?? defaults.primaryBrowser
        }
    }
    
    // check if DefaultBrowser is the OS level link handler
    func isCurrentlyDefault() -> Bool {
        let selfBundleID = Bundle.main.bundleIdentifier!
        
        var currentlyDefault = false
        // TODO LSCopyDefaultHandlerForURLScheme is deprecated but I'm not sure if I can migrate to content type
        if let currentDefaultBrowser = LSCopyDefaultHandlerForURLScheme("http" as CFString)?.takeRetainedValue() as String? {
            if currentDefaultBrowser.lowercased() == selfBundleID.lowercased() {
                currentlyDefault = true
            } else {
                defaults.primaryBrowser = currentDefaultBrowser
                defaults.browserBlocklist = defaults.browserBlocklist.filter { $0 == currentDefaultBrowser }
            }
        }
        return currentlyDefault
    }
    
    // set DefaultBrowser as the OS level link handler
    func setAsDefault() {
        let selfBundleID = Bundle.main.bundleIdentifier! as CFString
        LSSetDefaultHandlerForURLScheme("http" as CFString, selfBundleID)
        LSSetDefaultHandlerForURLScheme("https" as CFString, selfBundleID)
        LSSetDefaultHandlerForURLScheme("file" as CFString, selfBundleID)
        LSSetDefaultHandlerForURLScheme("html" as CFString, selfBundleID)
        setAsDefaultWarningText.isHidden = true
    }
    
    // set to open automatically at login
    func setOpenOnLogin() {
        let appURL = Bundle.main.bundleURL
        if let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil).takeRetainedValue() as LSSharedFileList? {
            let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
            let lastItemRef = loginItems.lastObject as! LSSharedFileListItem
            for currentItem in loginItems {
                let currentItemRef: LSSharedFileListItem = currentItem as! LSSharedFileListItem
                if let itemURL = LSSharedFileListItemCopyResolvedURL(currentItemRef, 0, nil) {
                    if (itemURL.takeRetainedValue() as NSURL).isEqual(appURL) {
                        print("Already registered in startup list.")
                        return
                    }
                }
            }
            print("Registering in startup list.")
            LSSharedFileListInsertItemURL(loginItemsRef, lastItemRef, nil, nil, appURL as CFURL, nil, nil)
        }
    }

    // reset lists of browsers
    func resetBrowsers() {
        validBrowsers = getAllBrowsers()
        runningBrowsers = []
        updateBrowsers(apps: workspace.runningApplications.sorted { (a, b) -> Bool in
            return (a.bundleIdentifier ?? "") == defaults.primaryBrowser
        })
        blocklistTable.reloadData()
        blocklistTable.setNeedsDisplay()
        updateBlocklistTable()
        setUpPreferencesBrowsers()
    }
    
    // refresh menu bar ui
    func updateMenuItems() {
        if let menu = statusItem.menu {
            let top = menu.indexOfItem(withTag: MenuItemTag.BrowserListTop.rawValue)
            let bottom = menu.indexOfItem(withTag: MenuItemTag.BrowserListBottom.rawValue)
            let openingBrowser = getOpeningBrowserId().lowercased()
            for i in ((top+1)..<bottom).reversed() {
                statusItem.menu?.removeItem(at: i)
            }
            if runningBrowsers.count > 0 {
                var idx = top + 1
                runningBrowsers.forEach({ app in
                    let name = defaults.detailedAppNames
                        ? getDetailedAppName(bundleId: app.bundleIdentifier ?? "")
                        : (app.localizedName ?? getAppName(bundleId: app.bundleIdentifier ?? ""))
                    let item = BrowserMenuItem(
                        title: name,
                        action: #selector(selectBrowser),
                        keyEquivalent: "\(idx - top)"
                    )
                    item.height = MENU_ITEM_HEIGHT
                    item.bundleIdentifier = app.bundleIdentifier
                    if item.bundleIdentifier == explicitBrowser {
                        item.state = .on
                    }
                    menu.insertItem(item, at: idx)
                    idx += 1
                })
                if let browser = explicitBrowser {
                    if runningBrowsers.filter({ $0.bundleIdentifier == explicitBrowser }).count == 0 {
                        let name = defaults.detailedAppNames
                            ? getDetailedAppName(bundleId: browser)
                            : getAppName(bundleId: browser)
                        let item = BrowserMenuItem(
                            title: name,
                            action: #selector(selectBrowser),
                            keyEquivalent: "\(idx - top)"
                        )
                        item.height = MENU_ITEM_HEIGHT
                        item.bundleIdentifier = browser
                        item.state = .on
                        menu.insertItem(item, at: idx)
                    }
                }
                if let button = statusItem.button {
                    if !isCurrentlyDefault() {
                        button.image = NSImage(named: "StatusBarButtonImageError")
                        setAsDefaultWarningText.isHidden = false
                    } else {
                        if firstTime {
                            firstTime = true
                            resetBrowsers()
                            return
                        }
                        setAsDefaultWarningText.isHidden = true
                        switch openingBrowser {
                        case "com.apple.safari":
                            button.image = NSImage(named: "StatusBarButtonImageSafari")
                        case "com.google.chrome":
                            button.image = NSImage(named: "StatusBarButtonImageChrome")
                        case "com.google.chrome.canary":
                            button.image = NSImage(named: "StatusBarButtonImageChromeCanary")
                        case "org.mozilla.firefox":
                            button.image = NSImage(named: "StatusBarButtonImageFirefox")
                        case "com.operasoftware.opera":
                            button.image = NSImage(named: "StatusBarButtonImageOpera")
                        case "org.webkit.nightly.webkit":
                            button.image = NSImage(named: "StatusBarButtonImageWebKit")
                        case "org.waterfoxproject.waterfox":
                            button.image = NSImage(named: "StatusBarButtonImageWaterfox")
                        case "com.vivaldi.vivaldi":
                            button.image = NSImage(named: "StatusBarButtonImageVivaldi")
                        default:
                            button.image = NSImage(named: "StatusBarButtonImage")
                        }
                    }
                }
            }
            
            let item = menu.item(withTag: MenuItemTag.usePrimary.rawValue)!
            item.state = usePrimaryBrowser ? .on : .off
        }
    }

    // refresh blocklist bar ui
    func updateBlocklistTable() {
        blocklistTable.reloadData()
        let blocklist = defaults.browserBlocklist
        let primaryDefault = defaults.primaryBrowser
        let selectedRows = NSMutableIndexSet()
        validBrowsers.enumerated().filter({ (_, browser) -> Bool in
            return blocklist.contains(browser) && primaryDefault != browser
        }).forEach { (i, _) in
            selectedRows.add(i)
        }
        blocklistTable.deselectAll(self)
        blocklistTable.selectRowIndexes(selectedRows as IndexSet, byExtendingSelection: false)
    }
    
    // MARK: UI Actions
    
    // user clicked a browser from the menu
    @objc func selectBrowser(sender: NSMenuItem) {
        if let menuItem = sender as? BrowserMenuItem {
            if explicitBrowser == menuItem.bundleIdentifier {
                explicitBrowser = nil
            } else {
                explicitBrowser = menuItem.bundleIdentifier
            }
            updateMenuItems()
        }
    }
    
    // use user's primary browser -- user clicked the menu button
    @objc func usePrimary(sender: NSMenuItem) {
        if defaults.primaryBrowser != "" {
            usePrimaryBrowser = sender.state != .on
            statusItem.button?.appearsDisabled = sender.state != .on
            explicitBrowser = nil
            updateMenuItems()
        }
    }
    
    // user clicked "Preferences..."
    @objc func openWindow(sender: AnyObject) {
        window.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func terminate() {
        NSApplication.shared.terminate(self)
    }
    
    // MARK: IB Actions
    
    @IBAction func primaryBrowserPopUpChange(sender: NSPopUpButton) {
        if let item = sender.selectedItem as? BrowserMenuItem, let bid = item.bundleIdentifier {
            defaults.primaryBrowser = bid
            defaults.browserBlocklist = defaults.browserBlocklist.filter { $0 != bid }
            blocklistTable.reloadData()
            blocklistTable.setNeedsDisplay()
            updateBlocklistTable()
            updateMenuItems()
        }
    }

    @IBAction func descriptiveAppNamesChange(sender: NSButton) {
        defaults.detailedAppNames = sender.state == .on
        updateMenuItems()
        setUpPreferencesBrowsers()
        updateBlocklistTable()
    }
    
    @IBAction func showWindowChange(sender: NSButton) {
        defaults.openWindowOnLaunch = sender.state == .on
    }
    
    @IBAction func refreshBrowsersPress(sender: AnyObject?) {
        resetBrowsers()
    }

    @IBAction func setAsDefaultPress(sender: AnyObject) {
        setAsDefault()
    }

    @IBAction func blocklistDisclosurePress(sender: NSButton) {
        if sender.state == .on {
            blocklistHeightConstraint.constant = 100
        } else {
            blocklistHeightConstraint.constant = 0
        }
    }
    
}

extension AppDelegate: NSTableViewDataSource {
    
}

extension AppDelegate: NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return validBrowsers.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = validBrowsers[row]
        if let col = tableColumn {
            let cell = tableView.makeView(withIdentifier: col.identifier, owner: self) as! NSTableCellView
            if let path = workspace.absolutePathForApplication(withBundleIdentifier: app) {
                let image = workspace.icon(forFile: path)
                image.size = NSSize(width: MENU_ITEM_HEIGHT, height: MENU_ITEM_HEIGHT)
                cell.imageView?.image = image
            }
            cell.textField?.textColor = app == defaults.primaryBrowser
                ? .disabledControlTextColor
                : .controlTextColor
            cell.textField?.stringValue = defaults.detailedAppNames
                ? getDetailedAppName(bundleId: app)
                : getAppName(bundleId: app)
            return cell
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        defaults.browserBlocklist = proposedSelectionIndexes
            .map { validBrowsers[$0] }
            .filter { $0 != defaults.primaryBrowser }
        if let primaryIndex = validBrowsers.firstIndex(of: defaults.primaryBrowser) {
            let newSelection = NSMutableIndexSet(indexSet: proposedSelectionIndexes)
            newSelection.remove(primaryIndex)
            return newSelection as IndexSet
        }
        return proposedSelectionIndexes
    }
    
}
