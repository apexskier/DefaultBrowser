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

// return bundle ids for all applications that can open links
func getAllBrowsers() -> [String] {
    let httpHandlers = LSCopyAllHandlersForURLScheme("http")?.takeRetainedValue() ?? []
    let httpsHandlers = LSCopyAllHandlersForURLScheme("https")?.takeRetainedValue() ?? []
    var urlHandlers = [String]()
    for bid in httpHandlers {
        urlHandlers.append(bid as! String)
    }
    for bid in httpsHandlers {
        if !urlHandlers.contains(bid as! String) {
            urlHandlers.append(bid as! String)
        }
    }
    let selfBid = NSBundle.mainBundle().bundleIdentifier!.lowercaseString
    urlHandlers = urlHandlers.filter({ return $0.lowercaseString != selfBid })
    return urlHandlers
}

var validBrowsers = getAllBrowsers()

// return a descriptive name for an application
func getAppName(bundleId: String) -> String {
    var name = "Unknown Application"
    if let appPath = NSWorkspace.sharedWorkspace().absolutePathForAppBundleWithIdentifier(bundleId) {
        if let appBundle = NSBundle(path: appPath) {
            name = (appBundle.objectForInfoDictionaryKey("CFBundleDisplayName") as? String)
                ?? (appBundle.objectForInfoDictionaryKey("CFBundleName") as? String)
                ?? (appBundle.objectForInfoDictionaryKey("CFBundleExecutable") as? String)
                ?? ((appPath as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
                ?? name
        } else {
            name = ((appPath as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
        }
    }
    return name
}

func getDetailedAppName(bundleId: String) -> String {
    var name = "Unknown Application"
    if let appPath = NSWorkspace.sharedWorkspace().absolutePathForAppBundleWithIdentifier(bundleId) {
        if let appBundle = NSBundle(path: appPath) {
            name = (appBundle.objectForInfoDictionaryKey("CFBundleDisplayName") as? String)
                ?? (appBundle.objectForInfoDictionaryKey("CFBundleName") as? String)
                ?? (appBundle.objectForInfoDictionaryKey("CFBundleExecutable") as? String)
                ?? ((appPath as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
                ?? name
            if let version = appBundle.objectForInfoDictionaryKey("CFBundleShortVersionString") as? String {
                name += " (\(version))"
            }
        } else {
            name = ((appPath as NSString).lastPathComponent as NSString).stringByDeletingPathExtension
        }
    }
    return name
}

let MENU_ITEM_HEIGHT: CGFloat = 16

enum MenuItemTag: Int {
    case BrowserListTop = 1
    case BrowserListBottom
    case UseDefault
}

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
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var descriptiveAppNamesCheckbox: NSButton!
    @IBOutlet weak var browsersPopUp: NSPopUpButton!
    @IBOutlet weak var showWindowCheckbox: NSButton!
    @IBOutlet weak var setAsDefaultWarningText: NSTextField!
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    let workspace = NSWorkspace.sharedWorkspace()
    
    var runningBrowsers: [NSRunningApplication] = []
    var skipNextBrowserSort = true
    var explicitBrowser: String? = nil
    var useDefaultBrowser = false
    var firstTime = true
    
    // load settings
    let defaults = ThisDefaults()
    
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
            
            let item = menu.itemWithTag(MenuItemTag.UseDefault.rawValue)!
            if useDefaultBrowser {
                item.state = NSOnState
            } else {
                item.state = NSOffState
            }
        }
    }
    
    func applicationWillFinishLaunching(notification: NSNotification) {
        workspace.addObserver(self, forKeyPath: "runningApplications", options: [.Old, .New], context: &KVOContext)
        workspace.notificationCenter.addObserver(self, selector: Selector("applicationChange:"), name:
            NSWorkspaceDidActivateApplicationNotification, object: nil)
        NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: Selector("handleGetURLEvent:withReplyEvent:"), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32 (kAEGetURL))
    }
    
    func isCurrentlyDefault() -> Bool {
        let selfBundleID = NSBundle.mainBundle().bundleIdentifier!
        
        var currentlyDefault = false
        if let currentDefaultBrowser = LSCopyDefaultHandlerForURLScheme("http")?.takeRetainedValue() {
            if (currentDefaultBrowser as String).lowercaseString == selfBundleID.lowercaseString {
                currentlyDefault = true
            } else {
                defaults.defaultBrowser = currentDefaultBrowser as String
            }
        }
        return currentlyDefault
    }
    
    func setAsDefault() {
        let selfBundleID = NSBundle.mainBundle().bundleIdentifier!
        LSSetDefaultHandlerForURLScheme("http", selfBundleID)
        LSSetDefaultHandlerForURLScheme("https", selfBundleID)
        setAsDefaultWarningText.hidden = true
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
        let useDefaultMenuItem = NSMenuItem(title: "Use Default Browser", action: Selector("useDefault:"), keyEquivalent: "0")
        useDefaultMenuItem.tag = MenuItemTag.UseDefault.rawValue
        menu.addItem(useDefaultMenuItem)
        menu.addItem(NSMenuItem(title: "Quit", action: Selector("terminate:"), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        resetBrowsers()
        updateMenuItems()
        
        // set up preferences
        setUpPreferencesBrowsers()
        showWindowCheckbox.state = defaults.openWindowOnLaunch ? NSOnState : NSOffState
        descriptiveAppNamesCheckbox.state = defaults.detailedAppNames ? NSOnState : NSOffState
    }
    
    func setUpPreferencesBrowsers() {
        browsersPopUp.removeAllItems()
        var selectedDefaultBrowser: NSMenuItem? = nil
        validBrowsers.sort().forEach { bid in
            let name = defaults.detailedAppNames ? getDetailedAppName(bid) : getAppName(bid)
            let menuItem = BrowserMenuItem(title: name, action: nil, keyEquivalent: "")
            menuItem.height = MENU_ITEM_HEIGHT
            menuItem.bundleIdentifier = bid
            if defaults.defaultBrowser == bid {
                selectedDefaultBrowser = menuItem
            }
            browsersPopUp.menu?.addItem(menuItem)
        }
        browsersPopUp.selectItem(selectedDefaultBrowser)
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
        
        updateApps(apps)
    }
    
    func getOpeningBrowserId() -> String {
        if useDefaultBrowser {
            return defaults.defaultBrowser
        } else {
            return explicitBrowser ?? runningBrowsers.first?.bundleIdentifier ?? defaults.defaultBrowser
        }
    }
    
    func updateApps(apps: NSArray?) {
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
    
    func applicationChange(notification: NSNotification) {
        if !skipNextBrowserSort {
            if let app = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication {
                self.runningBrowsers.sortInPlace({ a, b -> Bool in
                    if a.bundleIdentifier == app.bundleIdentifier {
                        return true
                    }
                    return false
                })
                updateMenuItems()
            }
        }
        skipNextBrowserSort = false
    }
    
    func openWindow(sender: AnyObject) {
        window.makeKeyAndOrderFront(sender)
        NSApp.activateIgnoringOtherApps(true)
    }
    
    func useDefault(sender: NSMenuItem) {
        useDefaultBrowser = sender.state != NSOnState
        statusItem.button?.appearsDisabled = sender.state != NSOnState
        explicitBrowser = nil
        updateMenuItems()
    }
    
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
    
    func resetBrowsers() {
        validBrowsers = getAllBrowsers()
        runningBrowsers = []
        updateApps(workspace.runningApplications)
    }
    
    @IBAction func defaultBrowserPopUpChange(sender: NSPopUpButton) {
        if let item = sender.selectedItem as? BrowserMenuItem {
            defaults.defaultBrowser = item.bundleIdentifier ?? ""
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

}

extension Dictionary {
    // Merges a sequence of (key,value) tuples into a Dictionary.
    mutating func merge <S: SequenceType where S.Generator.Element == Element> (seq: S) {
        var gen = seq.generate()
        while let (key, value): (Key, Value) = gen.next() {
            self[key] = value
        }
    }
    
    // Merges a sequence of values into a Dictionary by specifying a filter function.
    // The filter function can return nil to filter out that item from the input Sequence, or return a (key,value)
    // tuple to insert or change an item. In that case, value can be nil to remove the item for that key.
    mutating func merge <T, S: SequenceType where S.Generator.Element == T> (seq: S, filter: (T) -> (Key, Value?)?) {
        var gen = seq.generate()
        while let t: T = gen.next() {
            if let (key, value): (Key, Value?) = filter(t) {
                self[key] = value
            }
        }
    }
}

// http://stackoverflow.com/a/32127187/2178159
extension CFArray: SequenceType {
    public func generate() -> AnyGenerator<AnyObject> {
        var index = -1
        let maxIndex = CFArrayGetCount(self)
        return anyGenerator{
            guard ++index < maxIndex else {
                return nil
            }
            let unmanagedObject: UnsafePointer<Void> = CFArrayGetValueAtIndex(self, index)
            let rec = unsafeBitCast(unmanagedObject, AnyObject.self)
            return rec
        }
    }
}
