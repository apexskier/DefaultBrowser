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
            let workspace = NSWorkspace.sharedWorkspace()
            if let bid = self.bundleIdentifier, path = workspace.absolutePathForAppBundleWithIdentifier(bid) {
                image = workspace.iconForFile(path)
                if let size = self.height {
                    image?.size = NSSize(width: size, height: size)
                }
            }
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var descriptiveAppNamesCheckbox: NSButton!
    @IBOutlet weak var browsersPopUp: NSPopUpButton!
    @IBOutlet weak var showWindowCheckbox: NSButton!
    @IBOutlet weak var setAsDefaultWarningText: NSTextField!
    @IBOutlet weak var blacklistTable: NSTableView!
    @IBOutlet weak var blacklistView: NSScrollView!
    @IBOutlet weak var blacklistHeightConstraint: NSLayoutConstraint!
    
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    let workspace = NSWorkspace.sharedWorkspace()
    
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
    
    func applicationWillFinishLaunching(notification: NSNotification) {
        // Watch for when the user opens and quits applications
        workspace.addObserver(self, forKeyPath: "runningApplications", options: [.Old, .New], context: &KVOContext)
        // Watch for when the user switches applications
        workspace.notificationCenter.addObserver(self, selector: Selector("applicationChange:"), name:
            NSWorkspaceDidActivateApplicationNotification, object: nil)
        // Watch for the user opening links
        NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: Selector("handleGetURLEvent:withReplyEvent:"), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32 (kAEGetURL))
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        let selfBundleID = NSBundle.mainBundle().bundleIdentifier!
        var selfName = getAppName(selfBundleID)
        if selfName == "Unknown Application" {
            selfName = "Default Browser"
        }
        
        defaults.registerDefaults(defaultSettings)
        
        if !isCurrentlyDefault() {
            let notDefaultAlert = NSAlert()
            notDefaultAlert.addButtonWithTitle("Set As Default")
            notDefaultAlert.addButtonWithTitle("Cancel")
            notDefaultAlert.messageText = "Set Default Browser"
            notDefaultAlert.informativeText = "\(selfName) must be set as your default browser. Your current default will be remembered."
            notDefaultAlert.alertStyle = .WarningAlertStyle
            switch notDefaultAlert.runModal() {
            case NSAlertFirstButtonReturn:
                setAsDefault()
            default:
                break
            }
        } else {
            self.setAsDefaultWarningText.hidden = true
        }
        
        setOpenOnLogin()
        
        // open window?
        window.releasedWhenClosed = false
        if defaults.openWindowOnLaunch {
            window.makeKeyAndOrderFront(self)
        }
        
        // set up menu bar
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
            button.allowsMixedState = true
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About \(selfName)", action: Selector("openWindow:"), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences...", action: Selector("openWindow:"), keyEquivalent: ","))
        let browserListTop = NSMenuItem.separatorItem()
        browserListTop.tag = MenuItemTag.BrowserListTop.rawValue
        menu.addItem(browserListTop)
        let browserListBottom = NSMenuItem.separatorItem()
        browserListBottom.tag = MenuItemTag.BrowserListBottom.rawValue
        menu.addItem(browserListBottom)
        let usePrimaryMenuItem = NSMenuItem(title: "Use Primary Browser", action: Selector("usePrimary:"), keyEquivalent: "0")
        usePrimaryMenuItem.tag = MenuItemTag.usePrimary.rawValue
        menu.addItem(usePrimaryMenuItem)
        menu.addItem(NSMenuItem(title: "Quit", action: Selector("terminate:"), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        resetBrowsers()
        updateMenuItems()
        
        // set up preferences
        setUpPreferencesBrowsers()
        showWindowCheckbox.state = defaults.openWindowOnLaunch ? NSOnState : NSOffState
        descriptiveAppNamesCheckbox.state = defaults.detailedAppNames ? NSOnState : NSOffState
        
        blacklistTable.setDataSource(self)
        blacklistTable.setDelegate(self)
        updateBlacklistTable()
    }
    
    func setUpPreferencesBrowsers() {
        browsersPopUp.removeAllItems()
        var selectedPrimaryBrowser: NSMenuItem? = nil
        validBrowsers.sort().forEach { bid in
            let name = defaults.detailedAppNames ? getDetailedAppName(bid) : getAppName(bid)
            let menuItem = BrowserMenuItem(title: name, action: nil, keyEquivalent: "")
            menuItem.height = MENU_ITEM_HEIGHT
            menuItem.bundleIdentifier = bid
            let primaryBid = defaults.primaryBrowser.lowercaseString
            if primaryBid == bid.lowercaseString {
                selectedPrimaryBrowser = menuItem
            }
            browsersPopUp.menu?.addItem(menuItem)
        }
        browsersPopUp.selectItem(selectedPrimaryBrowser)
    }
    
    func applicationShouldHandleReopen(sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        workspace.removeObserver(self, forKeyPath: "runningApplications")
        workspace.notificationCenter.removeObserver(self, name: NSWorkspaceDidActivateApplicationNotification, object: nil)
        NSAppleEventManager.sharedAppleEventManager().removeEventHandlerForEventClass(UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }

    
    // MARK: Signal/Notification Responses
    
    // Respond to the user opening a link
    func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // not sure if the format always matches what I expect
        if let urlDescriptor = event.descriptorAtIndex(1), urlStr = urlDescriptor.stringValue, url = NSURL(string: urlStr) {
            let theBrowser = getOpeningBrowserId()
            print("opening: \(url) in \(theBrowser)")
            workspace.openURLs([url], withAppBundleIdentifier: theBrowser, options: .Default, additionalEventParamDescriptor: replyEvent, launchIdentifiers: nil)
        } else {
            // TODO: error
            let errorAlert = NSAlert()
            let appName = NSFileManager.defaultManager().displayNameAtPath(NSBundle.mainBundle().bundlePath)
            errorAlert.messageText = "Error"
            errorAlert.informativeText = "\(appName) couldn't understand an URL. Please report this error."
            errorAlert.alertStyle = .CriticalAlertStyle
            errorAlert.addButtonWithTitle("Okay")
            errorAlert.addButtonWithTitle("Report")
            switch errorAlert.runModal() {
            case NSAlertSecondButtonReturn:
                let bodyText = "\(appName) couldn't handle to some url.\n\nInformation:\n```\n\(event)\n```".stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
                let to = "cameron@camlittle.com"
                let subject = "\(appName) Error".stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
                
                let mailto = "mailto:\(to)?subject=\(subject)&body=\(bodyText)"
                
                workspace.openURL(NSURL(string: mailto)!)
            default:
                break
            }
        }
    }
    
    // Respond to the user opening or quitting applications
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        var apps: NSArray? = nil
        
        //	This uses the new guard statement to return early if there's no change dictionary.
        guard let change = change else {
            return
        }
        
        if let rv = change[NSKeyValueChangeKindKey] as? UInt, kind = NSKeyValueChange(rawValue: rv) {
            switch kind {
            case .Insertion:
                //	Get the inserted apps (usually only one, but you never know)
                apps = change[NSKeyValueChangeNewKey] as? NSArray
            case .Removal:
                //	Get the removed apps (usually only one, but you never know)
                apps = change[NSKeyValueChangeOldKey] as? NSArray
            default:
                return	// nothing to refresh; should never happen, but...
            }
        }
        
        updateBrowsers(apps)
    }
    
    // Respond to the user changing applications
    func applicationChange(notification: NSNotification) {
        if !skipNextBrowserSort {
            if let app = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication {
                self.runningBrowsers.sortInPlace({ a, b -> Bool in
                    if a.bundleIdentifier == app.bundleIdentifier {
                        return true
                    }
                    return false
                })
                lastActiveApplication = app
                updateMenuItems()
            }
        }
        skipNextBrowserSort = false
    }
    
    
    // MARK: Management Methods
    
    // update list of currently running browsers
    func updateBrowsers(apps: NSArray?) {
        if let apps = apps as? Array<NSRunningApplication>  {
            /// Use one of the Dictionary extensions to merge the changes into procdict.
            apps.filter({ return $0.bundleIdentifier != nil }).forEach { app in
                let remove = app.terminated		// insert or remove?
                
                if (validBrowsers.contains(app.bundleIdentifier!)) {
                    if remove {
                        if let index = runningBrowsers.indexOf(app) {
                            runningBrowsers.removeAtIndex(index)
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
            let blacklist = defaults.browserBlacklist
            return explicitBrowser
                ?? runningBrowsers.filter({
                    return !blacklist.contains($0.bundleIdentifier!)
                }).first?.bundleIdentifier
                ?? defaults.primaryBrowser
        }
    }
    
    // check if DefaultBrowser is the OS level link handler
    func isCurrentlyDefault() -> Bool {
        let selfBundleID = NSBundle.mainBundle().bundleIdentifier!
        
        var currentlyDefault = false
        if let currentDefaultBrowser = LSCopyDefaultHandlerForURLScheme("http")?.takeRetainedValue() {
            if (currentDefaultBrowser as String).lowercaseString == selfBundleID.lowercaseString {
                currentlyDefault = true
            } else {
                defaults.primaryBrowser = currentDefaultBrowser as String
            }
        }
        return currentlyDefault
    }
    
    // set DefaultBrowser as the OS level link handler
    func setAsDefault() {
        let selfBundleID = NSBundle.mainBundle().bundleIdentifier!
        LSSetDefaultHandlerForURLScheme("http", selfBundleID)
        LSSetDefaultHandlerForURLScheme("https", selfBundleID)
        LSSetDefaultHandlerForURLScheme("file", selfBundleID)
        setAsDefaultWarningText.hidden = true
    }
    
    // set to open automatically at login
    func setOpenOnLogin() {
        let appURL = NSBundle.mainBundle().bundleURL
        if let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil).takeRetainedValue() as LSSharedFileListRef? {
            let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil).takeRetainedValue() as NSArray
            let lastItemRef = loginItems.lastObject as! LSSharedFileListItemRef
            for currentItem in loginItems {
                let currentItemRef: LSSharedFileListItemRef = currentItem as! LSSharedFileListItemRef
                if let itemURL = LSSharedFileListItemCopyResolvedURL(currentItemRef, 0, nil) {
                    if (itemURL.takeRetainedValue() as NSURL).isEqual(appURL) {
                        print("Already registered in startup list.")
                        return
                    }
                }
            }
            print("Registering in startup list.")
            LSSharedFileListInsertItemURL(loginItemsRef, lastItemRef, nil, nil, appURL, nil, nil)
        }
    }

    // reset lists of browsers
    func resetBrowsers() {
        validBrowsers = getAllBrowsers()
        runningBrowsers = []
        updateBrowsers(workspace.runningApplications.sort({ (a, b) -> Bool in
            return (a.bundleIdentifier ?? "") == defaults.primaryBrowser
        }))
        blacklistTable.reloadData()
        blacklistTable.setNeedsDisplay()
        updateBlacklistTable()
        setUpPreferencesBrowsers()
    }
    
    // refresh menu bar ui
    func updateMenuItems() {
        if let menu = statusItem.menu {
            let top = menu.indexOfItemWithTag(MenuItemTag.BrowserListTop.rawValue)
            let bottom = menu.indexOfItemWithTag(MenuItemTag.BrowserListBottom.rawValue)
            let openingBrowser = getOpeningBrowserId()
            for i in ((top+1)..<bottom).reverse() {
                statusItem.menu?.removeItemAtIndex(i)
            }
            var idx = top + 1
            if runningBrowsers.count > 0 {
                runningBrowsers.forEach({ app in
                    let name = defaults.detailedAppNames ? getDetailedAppName(app.bundleIdentifier ?? "") : (app.localizedName ?? getAppName(app.bundleIdentifier ?? ""))
                    let item = BrowserMenuItem(title: name, action: Selector("selectBrowser:"), keyEquivalent: "\(idx - top)")
                    item.height = MENU_ITEM_HEIGHT
                    item.bundleIdentifier = app.bundleIdentifier
                    if item.bundleIdentifier == explicitBrowser {
                        item.state = NSOnState
                    }
                    menu.insertItem(item, atIndex: idx)
                    idx++
                })
                if let browser = explicitBrowser {
                    if runningBrowsers.filter({ $0.bundleIdentifier == explicitBrowser }).count == 0 {
                        let name = defaults.detailedAppNames ? getDetailedAppName(browser) : getAppName(browser)
                        let item = BrowserMenuItem(title: name, action: Selector("selectBrowser:"), keyEquivalent: "\(idx - top)")
                        item.height = MENU_ITEM_HEIGHT
                        item.bundleIdentifier = browser
                        item.state = NSOnState
                        menu.insertItem(item, atIndex: idx)
                    }
                }
                if let button = statusItem.button {
                    if !isCurrentlyDefault() {
                        button.image = NSImage(named: "StatusBarButtonImageError")
                        setAsDefaultWarningText.hidden = false
                    } else {
                        if firstTime {
                            firstTime = true
                            resetBrowsers()
                            return
                        }
                        setAsDefaultWarningText.hidden = true
                        switch openingBrowser.lowercaseString {
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
                        default:
                            button.image = NSImage(named: "StatusBarButtonImage")
                        }
                    }
                }
            }
            
            let item = menu.itemWithTag(MenuItemTag.usePrimary.rawValue)!
            if usePrimaryBrowser {
                item.state = NSOnState
            } else {
                item.state = NSOffState
            }
        }
    }

    // refresh blacklist bar ui
    func updateBlacklistTable() {
        let blacklist = defaults.browserBlacklist
        let selectedRows = NSMutableIndexSet()
        validBrowsers.enumerate().map({ (i, browser) -> (Int, String) in
            return (i, browser)
        }).filter({ (_, browser) -> Bool in
            return blacklist.contains(browser)
        }).map({ (i, _) -> Int in
            return i
        }).forEach { i in
            selectedRows.addIndex(i)
        }
        blacklistTable.selectRowIndexes(selectedRows, byExtendingSelection: false)
    }
    
    
    // MARK: NSTableViewDelegate
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return validBrowsers.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = validBrowsers[row]
        if let col = tableColumn {
            let cell = tableView.makeViewWithIdentifier(col.identifier, owner: self) as! NSTableCellView
            if let path = workspace.absolutePathForAppBundleWithIdentifier(app) {
                let image = workspace.iconForFile(path)
                image.size = NSSize(width: MENU_ITEM_HEIGHT, height: MENU_ITEM_HEIGHT)
                cell.imageView?.image = image
            }
            /* Can't get this to reset when the primary browser changes
            if app == defaults.primaryBrowser {
                cell.textField?.textColor = NSColor.disabledControlTextColor()
            }*/
            cell.textField?.stringValue = defaults.detailedAppNames ? getDetailedAppName(app) : getAppName(app)
            return cell
        }
        return nil
    }
    
    func tableView(tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: NSIndexSet) -> NSIndexSet {
        defaults.browserBlacklist = proposedSelectionIndexes.map { i -> String in
            return validBrowsers[i]
        }
        if let primaryIndex = validBrowsers.indexOf(defaults.primaryBrowser) {
            let newSelection = NSMutableIndexSet(indexSet: proposedSelectionIndexes)
            newSelection.removeIndex(primaryIndex)
            return newSelection
        }
        return proposedSelectionIndexes
    }
    
    
    // MARK: UI Actions
    
    // user clicked a browser from the menu
    func selectBrowser(sender: NSMenuItem) {
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
    func usePrimary(sender: NSMenuItem) {
        if defaults.primaryBrowser != "" {
            usePrimaryBrowser = sender.state != NSOnState
            statusItem.button?.appearsDisabled = sender.state != NSOnState
            explicitBrowser = nil
            updateMenuItems()
        }
    }
    
    // user clicked "Preferences..."
    func openWindow(sender: AnyObject) {
        window.makeKeyAndOrderFront(sender)
        NSApp.activateIgnoringOtherApps(true)
    }
    
    
    // MARK: IB Actions
    
    @IBAction func primaryBrowserPopUpChange(sender: NSPopUpButton) {
        if let item = sender.selectedItem as? BrowserMenuItem, bid = item.bundleIdentifier {
            defaults.primaryBrowser = bid
            blacklistTable.reloadData()
            blacklistTable.setNeedsDisplay()
            updateBlacklistTable()
            updateMenuItems()
        }
    }

    @IBAction func descriptiveAppNamesChange(sender: NSButton) {
        defaults.detailedAppNames = sender.state == NSOnState
        updateMenuItems()
        setUpPreferencesBrowsers()
    }
    
    @IBAction func showWindowChange(sender: NSButton) {
        defaults.openWindowOnLaunch = sender.state == NSOnState
    }
    
    @IBAction func refreshBrowsersPress(sender: AnyObject?) {
        resetBrowsers()
    }

    @IBAction func setAsDefaultPress(sender: AnyObject) {
        setAsDefault()
    }

    @IBAction func blacklistDisclosurePress(sender: NSButton) {
        if sender.state == NSOnState {
            blacklistHeightConstraint.constant = 100
        } else {
            blacklistHeightConstraint.constant = 0
        }
    }
    
}
