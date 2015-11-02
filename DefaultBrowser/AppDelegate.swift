//
//  AppDelegate.swift
//  DefaultBrowser
//
//  Created by Cameron Little on 10/23/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Cocoa

private var KVOContext = 0

let validBrowsers = [
    "com.apple.Safari",
    "com.google.Chrome",
    "com.operasoftware.Opera",
    "org.mozilla.firefox"
]

enum MenuItemTag: Int {
    case BrowserListTop = 1
    case BrowserListBottom = 2
}

class BrowserMenuItem: NSMenuItem {
    var bundleIdentifier: String?
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    let workspace = NSWorkspace.sharedWorkspace()
    
    let currentBrowser: NSRunningApplication? = nil
    var procdict: [NSRunningApplication: ProcessInfo] = [:]
    var processes: [ProcessInfo] = []
    var runningBrowsers: [NSRunningApplication] = []
    var skipNextBrowserSort = true
    var explicitBrowser: String? = nil
    
    let toggleEnableMenuItem = NSMenuItem(title: "Loading Toggle", action: Selector("toggleEnabled:"), keyEquivalent: "")
    internal var _enabled: Bool = true
    var enabled: Bool {
        get {
            return _enabled
        }
        set (value) {
            if value {
                toggleEnableMenuItem.title = "Disable"
                toggleEnableMenuItem.keyEquivalent = "d"
            } else {
                toggleEnableMenuItem.title = "Activate"
                toggleEnableMenuItem.keyEquivalent = "a"
            }
            _enabled = value
        }
    }
    
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
                    let item = BrowserMenuItem(title: app.localizedName ?? "Unknown Browser", action: Selector("selectBrowser:"), keyEquivalent: "\(idx - top)")
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
        NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: Selector("handleGetURLEvent:withReplyEvent:"), forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        window.releasedWhenClosed = false
        
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
        }
        
        let menu = NSMenu()
        menu.addItem(toggleEnableMenuItem)
        menu.addItem(NSMenuItem(title: "Preferences...", action: Selector("openWindow:"), keyEquivalent: ","))
        let browserListTop = NSMenuItem.separatorItem()
        browserListTop.tag = MenuItemTag.BrowserListTop.rawValue
        menu.addItem(browserListTop)
        let browserListBottom = NSMenuItem.separatorItem()
        browserListBottom.tag = MenuItemTag.BrowserListBottom.rawValue
        menu.addItem(browserListBottom)
        menu.addItem(NSMenuItem(title: "Quit", action: Selector("terminate:"), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        enabled = true
        
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
        NSWorkspace.sharedWorkspace().removeObserver(self, forKeyPath: "runningApplications")
        workspace.removeObserver(self, forKeyPath: NSWorkspaceDidActivateApplicationNotification)
        NSAppleEventManager.sharedAppleEventManager().removeEventHandlerForEventClass(UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
    }

    func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // not sure if the format always matches what I expect
        if let urlDescriptor = event.descriptorAtIndex(1), urlStr = urlDescriptor.stringValue, url = NSURL(string: urlStr) {
            let theBrowser = explicitBrowser ?? runningBrowsers.first?.bundleIdentifier ?? validBrowsers[0]
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
    }
    
    func toggleEnabled(sender: AnyObject) {
        enabled = !enabled
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
