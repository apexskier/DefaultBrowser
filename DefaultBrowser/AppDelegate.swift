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

enum MenuItemTag: Int {
    case BrowserListTop = 1
    case BrowserListBottom = 2
}

class BrowserMenuItem: NSMenuItem {
    private var _bundleIdentifier: String?
    var bundleIdentifier: String? {
        get {
            return _bundleIdentifier
        }
        set (value) {
            _bundleIdentifier = value
            let workspace = NSWorkspace.sharedWorkspace()
            if let bid = self.bundleIdentifier, path = workspace.absolutePathForAppBundleWithIdentifier(bid) {
                image = workspace.iconForFile(path)
            }
        }
    }
}

enum DefaultKey: String {
    case OpenWindowOnLaunch
    case DetailedAppNames
    case DefaultBrowser
}

let defaultSettings: [String: AnyObject] = [
    DefaultKey.OpenWindowOnLaunch.rawValue: true,
    DefaultKey.DetailedAppNames.rawValue: false,
    DefaultKey.DefaultBrowser.rawValue: "com.apple.Safari"
]

class ThisDefaults: NSUserDefaults {
    var openWindowOnLaunch: Bool {
        get {
            return boolForKey(DefaultKey.OpenWindowOnLaunch.rawValue)
        }
        set (value) {
            setBool(value, forKey: DefaultKey.OpenWindowOnLaunch.rawValue)
        }
    }
    var detailedAppNames: Bool {
        get {
            return boolForKey(DefaultKey.DetailedAppNames.rawValue)
        }
        set (value) {
            setBool(value, forKey: DefaultKey.DetailedAppNames.rawValue)
        }
    }
    var defaultBrowser: String {
        get {
            return stringForKey(DefaultKey.DefaultBrowser.rawValue) ?? (defaultSettings[DefaultKey.DefaultBrowser.rawValue] as! String)
        }
        set (value) {
            setObject(value, forKey: DefaultKey.DefaultBrowser.rawValue)
        }
    }
}

// return a descriptive name for an application
func getAppName(bundleId: String) -> String {
    var name = "Unknown Application"
    if let appPath = NSWorkspace.sharedWorkspace().absolutePathForAppBundleWithIdentifier(bundleId), appBundle = NSBundle(path: appPath) {
        name = (appBundle.objectForInfoDictionaryKey("CFBundleExecutable") as? String)
            ?? (appBundle.objectForInfoDictionaryKey("CFBundleDisplayName") as? String)
            ?? (appBundle.objectForInfoDictionaryKey("CFBundleName") as? String)
            ?? (appPath as NSString).stringByDeletingLastPathComponent
            ?? name
    }
    return name
}

func getDetailedAppName(bundleId: String) -> String {
    var name = "Unknown Application"
    if let appPath = NSWorkspace.sharedWorkspace().absolutePathForAppBundleWithIdentifier(bundleId), appBundle = NSBundle(path: appPath) {
        name = (appBundle.objectForInfoDictionaryKey("CFBundleExecutable") as? String)
            ?? (appBundle.objectForInfoDictionaryKey("CFBundleName") as? String)
            ?? (appBundle.objectForInfoDictionaryKey("CFBundleDisplayName") as? String)
            ?? (appPath as NSString).stringByDeletingLastPathComponent
            ?? name
        if let version = appBundle.objectForInfoDictionaryKey("CFBundleShortVersionString") as? String {
            name += " (\(version))"
        }
    }
    return name
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var descriptiveAppNamesCheckbox: NSButton!
    @IBOutlet weak var browsersPopUp: NSPopUpButton!
    @IBOutlet weak var showWindowCheckbox: NSButton!
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    let workspace = NSWorkspace.sharedWorkspace()
    
    let currentBrowser: NSRunningApplication? = nil
    var procdict: [NSRunningApplication: ProcessInfo] = [:]
    var processes: [ProcessInfo] = []
    var runningBrowsers: [NSRunningApplication] = []
    var skipNextBrowserSort = true
    var explicitBrowser: String? = nil
    
    // load settings
    let defaults = ThisDefaults()
    
    func updateMenuItems() {
        if let menu = statusItem.menu {
            let top = menu.indexOfItemWithTag(MenuItemTag.BrowserListTop.rawValue)
            let bottom = menu.indexOfItemWithTag(MenuItemTag.BrowserListBottom.rawValue)
            for i in ((top+1)..<bottom).reverse() {
                statusItem.menu?.removeItemAtIndex(i)
            }
            var idx = top + 1
            if self.runningBrowsers.count > 0 {
                self.runningBrowsers.forEach({ app in
                    let name = defaults.detailedAppNames ? getDetailedAppName(app.bundleIdentifier ?? "") : getAppName((app.bundleIdentifier ?? ""))
                    let item = BrowserMenuItem(title: name, action: Selector("selectBrowser:"), keyEquivalent: "\(idx - top)")
                    item.bundleIdentifier = app.bundleIdentifier
                    if item.bundleIdentifier == explicitBrowser {
                        item.state = NSOnState
                    }
                    menu.insertItem(item, atIndex: idx)
                    idx++
                })
            } else {
                menu.addItem(NSMenuItem(title: "Default Browser", action: nil, keyEquivalent: ""))
            }
        }
    }
    
    func applicationWillFinishLaunching(notification: NSNotification) {
        workspace.addObserver(self, forKeyPath: "runningApplications", options: [.Old, .New], context: &KVOContext)
        workspace.notificationCenter.addObserver(self, selector: Selector("applicationChange:"), name:
            NSWorkspaceDidActivateApplicationNotification, object: nil)
        NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: Selector("handleGetURLEvent:withReplyEvent:"), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32 (kAEGetURL))
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        defaults.registerDefaults(defaultSettings)
        
        // open window?
        window.releasedWhenClosed = false
        if defaults.openWindowOnLaunch {
            window.makeKeyAndOrderFront(self)
        }
        
        // set up menu bar
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
        }
        
        let menu = NSMenu()
        let appName = getAppName(NSBundle.mainBundle().bundleIdentifier!)
        menu.addItem(NSMenuItem(title: "About \(appName)", action: Selector("openWindow:"), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences...", action: Selector("openWindow:"), keyEquivalent: ","))
        let browserListTop = NSMenuItem.separatorItem()
        browserListTop.tag = MenuItemTag.BrowserListTop.rawValue
        menu.addItem(browserListTop)
        let browserListBottom = NSMenuItem.separatorItem()
        browserListBottom.tag = MenuItemTag.BrowserListBottom.rawValue
        menu.addItem(browserListBottom)
        menu.addItem(NSMenuItem(title: "Quit", action: Selector("terminate:"), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        // set up preferences
        browsersPopUp.removeAllItems()
        var selectedDefaultBrowser: NSMenuItem? = nil
        validBrowsers.sort().forEach { bid in
            let menuItem = BrowserMenuItem(title: getAppName(bid), action: nil, keyEquivalent: "")
            menuItem.bundleIdentifier = bid
            if defaults.defaultBrowser == bid {
                selectedDefaultBrowser = menuItem
            }
            browsersPopUp.menu?.addItem(menuItem)
        }
        browsersPopUp.selectItem(selectedDefaultBrowser)
        showWindowCheckbox.state = defaults.openWindowOnLaunch ? NSOnState : NSOffState
        descriptiveAppNamesCheckbox.state = defaults.detailedAppNames ? NSOnState : NSOffState
        
        updateApps(workspace.runningApplications)
        updateMenuItems()
    }
    
    func applicationShouldHandleReopen(sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
    
    func applicationWillBecomeActive(notification: NSNotification) {
        
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
            let theBrowser = explicitBrowser ?? runningBrowsers.first?.bundleIdentifier ?? defaults.defaultBrowser
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
    
    func updateApps(apps: NSArray?) {
        if let apps = apps as? Array<NSRunningApplication>  {
            /// Use one of the Dictionary extensions to merge the changes into procdict.
            procdict.merge(apps.filter({ return $0.bundleIdentifier != nil })) { (app) in
                let remove = app.terminated		// insert or remove?
                
                if (validBrowsers.contains(app.bundleIdentifier!)) {
                    if remove {
                        if let index = self.runningBrowsers.indexOf(app) {
                            self.runningBrowsers.removeAtIndex(index)
                        }
                    } else {
                        self.runningBrowsers.append(app)
                    }
                    print("remove: \(remove); \(app.bundleIdentifier!)")
                }
                
                return (app, remove ? nil : ProcessInfo(app))
            }
            
            ///	Produce a sorted Array of ProcessInfo as input for the NSTableView.
            ///	ProcessInfo conforms to Equatable and Comparable, so no predicate is needed.
            processes = procdict.values.sort()
            self.updateMenuItems()
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
                self.updateMenuItems()
            }
        }
        skipNextBrowserSort = false
    }
    
    func openWindow(sender: AnyObject) {
        window.makeKeyAndOrderFront(sender)
        NSApp.activateIgnoringOtherApps(true)
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
    
    @IBAction func defaultBrowserPopUpChange(sender: NSPopUpButton) {
        if let item = sender.selectedItem as? BrowserMenuItem {
            defaults.defaultBrowser = item.bundleIdentifier ?? ""
        }
    }

    @IBAction func descriptiveAppNamesChange(sender: NSButton) {
        defaults.detailedAppNames = sender.state == NSOnState
        updateMenuItems()
    }
    
    @IBAction func showWindowChange(sender: NSButton) {
        defaults.openWindowOnLaunch = sender.state == NSOnState
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
