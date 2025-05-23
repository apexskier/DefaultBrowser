//
//  AppDelegate.swift
//  DefaultBrowser
//
//  Created by Cameron Little on 10/23/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Cocoa
import CoreServices
import Intents
import ServiceManagement
import UniformTypeIdentifiers

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
    var height: CGFloat?
    var bundleIdentifier: String? {
        didSet {
            let workspace = NSWorkspace.shared
            if let bid = bundleIdentifier,
               let url = workspace.urlForApplication(withBundleIdentifier: bid) {
                image = workspace.icon(forFile: url.relativePath)
                if let height {
                    image?.size = NSSize(width: height, height: height)
                }
            }
        }
    }
}

class MenuBarIconMenuItem: NSMenuItem {
    var template: Bool?
    var style: MenuBarIconStyle?
}

@NSApplicationMain
class AppDelegate: NSObject {
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var descriptiveAppNamesCheckbox: NSButton!
    @IBOutlet weak var disclosureTriangle: NSButton!
    @IBOutlet weak var menuBarIconPopUp: NSPopUpButton!
    @IBOutlet weak var browsersPopUp: NSPopUpButton!
    @IBOutlet weak var showWindowCheckbox: NSButton!
    @IBOutlet weak var blocklistTable: NSTableView!
    @IBOutlet weak var blocklistView: NSScrollView!
    @IBOutlet weak var blocklistHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var setDefaultButton: NSButton!

    @IBOutlet weak var aboutWindow: NSWindow!
    @IBOutlet weak var logo: NSImageView!
    @IBOutlet weak var versionString: NSTextField!
    @IBOutlet weak var builtByString: NSTextField!
    @IBOutlet weak var githubString: NSTextField!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let workspace = NSWorkspace.shared

    // a list of all valid browsers installed
    var validBrowsers = getAllBrowsers()

    // keep an ordered list of running browsers
    var runningBrowsers: [NSRunningApplication] = []

    var runningBrowsersNotBlocked: [NSRunningApplication] {
        runningBrowsers.filter({ runningBrowser in
            !defaults.browserBlocklist.contains(where: { blockedBrowser in
                runningBrowser.bundleIdentifier == blockedBrowser
            })
        })
    }

    // an explicitly chosen default browser
    var explicitBrowser: String? = nil

    // the user's "system" default browser
    var usePrimaryBrowser: Bool? = false

    // user settings
    let defaults = ThisDefaults()

    // get around a bug in the browser list when this app wasn't set as the default OS browser
    var firstTime = false

    var primaryBrowserObserver: NSKeyValueObservation?
    var blockedBrowserObserver: NSKeyValueObservation?

    // MARK: Signal/Notification Responses

    // Respond to the user opening a link
    @objc func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // not sure if the format always matches what I expect
        if let urlDescriptor = event.atIndex(1),
           let urlStr = urlDescriptor.stringValue,
           let url = URL(string: urlStr) {
            _ = openUrls(urls: [url], additionalEventParamDescriptor: replyEvent)
        } else {
            let errorAlert = NSAlert()
            let appName = FileManager.default.displayName(atPath: Bundle.main.bundlePath)
            errorAlert.messageText = "Error"
            errorAlert.informativeText = "\(appName) couldn't understand an URL. Please report this error."
            errorAlert.alertStyle = .critical
            errorAlert.addButton(withTitle: "Okay")
            errorAlert.addButton(withTitle: "Report")
            switch errorAlert.runModal() {
            case NSApplication.ModalResponse.alertSecondButtonReturn:
                let titleText = "Failed to open URL"
                let bodyText = "\(appName) couldn't handle to some url.\n\nInformation:\n```\n\(event.data.base64EncodedString())\n```".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!

                var components = URLComponents()
                components.scheme = "https"
                components.host = "github.com"
                components.path = "apexskier/DefaultBrowser/issues/new"
                components.queryItems = [
                    URLQueryItem(name: "title", value: titleText),
                    URLQueryItem(name: "body", value: bodyText)
                ]

                workspace.open(components.url!)
            default:
                break
            }
        }
    }

    // Respond to the user opening or quitting applications
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard let change = change else {
            return
        }

        var apps: [NSRunningApplication]? = nil

        if let rv = change[NSKeyValueChangeKey.kindKey] as? UInt, let kind = NSKeyValueChange(rawValue: rv) {
            switch kind {
            case .insertion:
                // Get the inserted apps (usually only one, but you never know)
                apps = change[NSKeyValueChangeKey.newKey] as? [NSRunningApplication]
            case .removal:
                // Get the removed apps (usually only one, but you never know)
                apps = change[NSKeyValueChangeKey.oldKey] as? [NSRunningApplication]
            default:
                return // nothing to refresh; should never happen, but...
            }
        }

        updateBrowsers(apps: apps)
    }

    // Respond to the user changing applications
    @objc func applicationChange(notification: NSNotification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            runningBrowsers.sort { a, _ in
                a.bundleIdentifier == app.bundleIdentifier
            }
            updateMenuItems()
        }
    }

    // Respond to the user changing appearance
    @objc func appearanceChange(notification: NSNotification) {
        updateMenuItems()
        updateMenuBarIconPopUp()
    }

    func openUrls(urls: [URL], additionalEventParamDescriptor descriptor: NSAppleEventDescriptor?) -> Bool {
        guard let theBrowser = getOpeningBrowserId() else {
            let noBrowserAlert = NSAlert()
            let selfName = getAppName(bundleId: Bundle.main.bundleIdentifier!)
            noBrowserAlert.messageText = "No Browsers Found"
            noBrowserAlert.informativeText = "\(selfName) couldn't find any other installed browsers to use. Install something!"
            noBrowserAlert.alertStyle = .warning
            noBrowserAlert.runModal()
            return false
        }

        guard let browserUrl = workspace.urlForApplication(withBundleIdentifier: theBrowser) else {
            let alert = NSAlert()
            let selfName = getAppName(bundleId: Bundle.main.bundleIdentifier!)
            alert.messageText = "Browser Not Found"
            alert.informativeText = "\(selfName) couldn't find \(theBrowser)."
            alert.alertStyle = .warning
            alert.runModal()
            return false
        }

        print("opening: \(urls) in \(theBrowser)")
        let openConfiguration = NSWorkspace.OpenConfiguration()
        workspace.open(urls, withApplicationAt: browserUrl, configuration: openConfiguration)
        return true
    }

    // MARK: Management Methods

    private func updatePreferencesBrowsersPopup() {
        browsersPopUp.removeAllItems()
        var selectedPrimaryBrowser: NSMenuItem? = nil
        for bid in validBrowsers {
            let menuItem = BrowserMenuItem(title: appName(for: bid), action: nil, keyEquivalent: "")
            menuItem.height = MENU_ITEM_HEIGHT
            menuItem.bundleIdentifier = bid
            if defaults.primaryBrowser?.lowercased() == bid.lowercased() {
                selectedPrimaryBrowser = menuItem
            }
            browsersPopUp.menu?.addItem(menuItem)
        }
        browsersPopUp.select(selectedPrimaryBrowser)
    }

    private var menuBarCases = MenuBarIconStyle.allCases.flatMap({ [(true, $0), (false, $0)] })

    private func updateMenuBarIconPopUp() {
        menuBarIconPopUp.removeAllItems()
        var selected: MenuBarIconMenuItem? = nil

        guard let base = NSImage(named: "StatusBarButtonImage") else {
            return
        }

        for style in MenuBarIconStyle.allCases {
            for template in [true, false] {
                let menuItem = MenuBarIconMenuItem(title: "\(template ? "Adaptive" : "Full Color") \(style.description)", action: nil, keyEquivalent: "")
                menuItem.style = style
                menuItem.template = template
                if defaults.templateMenuBarIcon == template && defaults.menuBarIconStyle == style {
                    selected = menuItem
                }
                menuItem.image = generateIcon(
                    key: IconCacheKey(
                        appearance: NSApplication.shared.effectiveAppearance,
                        style: style,
                        template: template,
                        size: MENU_ITEM_HEIGHT * 2,
                        bundleId: defaults.primaryBrowser ?? "com.apple.Safari"
                    ),
                    base: base,
                    in: workspace
                )
                menuBarIconPopUp.menu?.addItem(menuItem)
            }
        }

        menuBarIconPopUp.select(selected)
    }

    // update list of currently running browsers
    func updateBrowsers(apps: [NSRunningApplication]?) {
        if let apps = apps {
            /// Use one of the Dictionary extensions to merge the changes into procdict.
            for app in apps.filter({ $0.bundleIdentifier != nil }) {
                let remove = app.isTerminated // insert or remove?

                if (validBrowsers.contains(app.bundleIdentifier!)) {
                    if remove {
                        if let index = runningBrowsers.firstIndex(of: app) {
                            runningBrowsers.remove(at: index)
                        }
                    } else {
                        runningBrowsers.append(app)
                    }
                }
            }
            updateMenuItems()
        }
    }

    // decide which browser should be used to open a link
    func getOpeningBrowserId() -> String? {
        // if usePrimaryBrowser is true, use that
        if let primaryBrowser = defaults.primaryBrowser, usePrimaryBrowser == true {
            return primaryBrowser
        }
        // if an explicit browser is chosen, use that
        if let explicitBrowser {
            return explicitBrowser
        }
        // use the last used browser that's running
        let blocklist = defaults.browserBlocklist
        if let firstRunningBrowser = runningBrowsers
            .filter({ runningBrowser in
                !blocklist.contains(where: { blockedBrowser in
                    runningBrowser.bundleIdentifier == blockedBrowser
                })
            })
                .first?.bundleIdentifier {
            return firstRunningBrowser
        }
        // if no browsers are running, use the primary one
        if let primaryBrowser = defaults.primaryBrowser {
            return primaryBrowser
        }
        // if no primary browser is chosen, pick the first non-blocked one
        if let firstAvailableBrowser = validBrowsers.filter({ blocklist.contains($0) }).first {
            return firstAvailableBrowser
        }
        return nil
    }

    // check if DefaultBrowser is the OS level link handler
    func isCurrentlyDefaultHttpHandler() -> Bool? {
        guard let selfBundleID = Bundle.main.bundleIdentifier,
              let testUrl = URL(string: "http:"),
              let defaultApplicationUrl = workspace.urlForApplication(toOpen: testUrl),
              let currentDefaultBrowser = Bundle(url: defaultApplicationUrl)?.bundleIdentifier else {
            return nil
        }
        return currentDefaultBrowser.lowercased() == selfBundleID.lowercased()
    }

    // check if DefaultBrowser is the OS level html file handler
    func isCurrentlyDefaultHTMLHandler() -> Bool? {
        guard let selfBundleID = Bundle.main.bundleIdentifier else {
            return nil
        }

        if #available(macOS 12.0, *) {
            guard let defaultApplicationUrl = workspace.urlForApplication(toOpen: UTType.html),
                  let currentDefault = Bundle(url: defaultApplicationUrl)?.bundleIdentifier else {
                return nil
            }
            return currentDefault.lowercased() == selfBundleID.lowercased()
        } else {
            guard let testUrl = Bundle.main.url(forResource: "test", withExtension: "html") else {
                return nil
            }
            var err: Unmanaged<CFError>?
            let applicationUrl = LSCopyDefaultApplicationURLForURL(testUrl as CFURL, .viewer, &err)
            if let err {
                print(err)
                return nil
            }
            guard let applicationUrl,
                  let handlerBundleId = Bundle(url: applicationUrl.takeUnretainedValue() as URL)?.bundleIdentifier else {
                return nil
            }
            return handlerBundleId.lowercased() == selfBundleID.lowercased()
        }
    }

    // set DefaultBrowser as the OS level link handler
    func setAsDefaultHttpHandler() {
        if #available(macOS 12.0, *) {
            if let testUrl = URL(string: "http:"),
               let defaultApplicationUrl = workspace.urlForApplication(toOpen: testUrl),
               let currentDefaultBrowser = Bundle(url: defaultApplicationUrl)?.bundleIdentifier {
                defaults.primaryBrowser = currentDefaultBrowser
            }
            Task {
                do {
                    try await workspace.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http")
                } catch {
                    print("failed to set default http scheme handler: \(error)")
                    let errorAlert = await NSAlert(error: error)
                    await errorAlert.runModal()
                }
                await MainActor.run {
                    updateMenuItems()
                }
            }
        } else {
            let selfBundleID = Bundle.main.bundleIdentifier! as CFString
            for scheme in browserQualifyingSchemes {
                let error = LSSetDefaultHandlerForURLScheme(scheme as CFString, selfBundleID)
                if error != noErr {
                    print("failed to set handler for scheme \(scheme)")
                }
            }
            updateMenuItems()
        }
    }

    func setAsDefaultHTMLHandler() {
        if #available(macOS 12.0, *) {
            Task {
                do {
                    try await workspace.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: .html)
                } catch {
                    print("failed to set default html file handler: \(error)")
                    // this appears to be intentional by Apple, unfortunately
                    // https://github.com/Hammerspoon/hammerspoon/issues/2205#issuecomment-541972453
                }
            }
        } else {
            let selfBundleID = Bundle.main.bundleIdentifier! as CFString
            let error = LSSetDefaultRoleHandlerForContentType("public.html" as CFString, .viewer, selfBundleID)
            if error != noErr {
                print("failed to set html file handler")
            }
        }
    }

    // set to open automatically at login
    func setOpenOnLogin() {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status != .enabled {
                try? SMAppService.mainApp.register()
            }
        } else {
            if
                let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() as LSSharedFileList?,
                let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil)?.takeRetainedValue() as? NSArray
            {
                let appURL = Bundle.main.bundleURL
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
    }

    // reset lists of browsers
    func resetBrowsers() {
        validBrowsers = getAllBrowsers()
        runningBrowsers = []
        updateBrowsers(apps: workspace.runningApplications.sorted { a, _ in
            (a.bundleIdentifier ?? "") == defaults.primaryBrowser
        })
        updateBlocklistTable()
        updatePreferencesBrowsersPopup()
    }

    private var iconCache = NSCache<IconCacheKey, NSImage>()

    func getMenuBarIcon(for bundleId: String) -> NSImage? {
        guard let h = NSApplication.shared.mainMenu?.menuBarHeight else {
            return nil
        }

        let key = IconCacheKey(
            appearance: NSApplication.shared.effectiveAppearance,
            style: defaults.menuBarIconStyle,
            template: defaults.templateMenuBarIcon,
            size: h,
            bundleId: bundleId
        )
        if let image = iconCache.object(forKey: key) {
            return image
        }
        guard let base = NSImage(named: "StatusBarButtonImage") else {
            return nil
        }

        if let image = generateIcon(key: key, base: base,in: workspace) {
            // cache so we don't have to go through all this again
            iconCache.setObject(image, forKey: key)
            return image
        }

        return nil
    }

    func appName(for bundleId: String) -> String {
        defaults.detailedAppNames
            ? getDetailedAppName(bundleId: bundleId)
            : getAppName(bundleId: bundleId)
    }

    func appName(for app: NSRunningApplication) -> String {
        defaults.detailedAppNames
            ? getDetailedAppName(bundleId: app.bundleIdentifier ?? "")
            : (app.localizedName ?? getAppName(bundleId: app.bundleIdentifier ?? ""))
    }

    // refresh menu bar ui
    func updateMenuItems() {
        guard let menu = statusItem.menu else {
            return
        }

        let top = menu.indexOfItem(withTag: MenuItemTag.BrowserListTop.rawValue)
        let bottom = menu.indexOfItem(withTag: MenuItemTag.BrowserListBottom.rawValue)
        for i in ((top+1)..<bottom).reversed() {
            statusItem.menu?.removeItem(at: i)
        }

        var idx = top + 1

        let menuBrowsers = validBrowsers
        // don't show blocked browsers
            .filter({ browser in
                !defaults.browserBlocklist.contains(where: { blockedBrowser in
                    browser == blockedBrowser
                })
            })
        // sort alphabetically, to be more stable
            .sorted { appName(for: $0) < appName(for: $1) }

        for app in menuBrowsers {
            let item = BrowserMenuItem(
                title: appName(for: app),
                action: #selector(selectBrowser),
                keyEquivalent: "\(idx - top)"
            )
            item.height = MENU_ITEM_HEIGHT
            item.bundleIdentifier = app
            if !runningBrowsers.contains(where: { $0.bundleIdentifier == app }) {
                // I want the item's image to be semi-transparent in this case
                item.image = item.image?.withAlpha(0.5)
            }
            if item.bundleIdentifier == explicitBrowser {
                item.state = .on
            }
            menu.insertItem(item, at: idx)
            idx += 1
        }
        if let explicitBrowser, !menuBrowsers.contains(where: { $0 == explicitBrowser }) {
            let item = BrowserMenuItem(
                title: appName(for: explicitBrowser),
                action: #selector(selectBrowser),
                keyEquivalent: "\(idx - top)"
            )
            item.height = MENU_ITEM_HEIGHT
            item.bundleIdentifier = explicitBrowser
            item.state = .on
            menu.insertItem(item, at: idx)
        }
        if let button = statusItem.button {
            if isCurrentlyDefaultHttpHandler() != true {
                button.image = NSImage(named: "StatusBarButtonImageError")
                setDefaultButton.isEnabled = true
            } else {
                if firstTime {
                    firstTime = true
                    resetBrowsers()
                    return
                }
                setDefaultButton.isEnabled = false

                if let openingBrowser = getOpeningBrowserId() {
                    button.image = getMenuBarIcon(for: openingBrowser) ?? NSImage(named: "StatusBarButtonImage")
                } else {
                    button.image = NSImage(named: "StatusBarButtonImageError")
                }
            }
        }

        let item = menu.item(withTag: MenuItemTag.usePrimary.rawValue)!
        switch usePrimaryBrowser {
        case .none:
            item.state = .mixed
        case .some(let wrapped):
            item.state = wrapped ? .on : .off
        }
    }

    // refresh blocklist bar ui
    private func updateBlocklistTable() {
        blocklistTable.needsDisplay = true
        blocklistTable.reloadData()
        let blocklist = defaults.browserBlocklist
        let primaryDefault = defaults.primaryBrowser
        let selectedRows = NSMutableIndexSet()
        validBrowsers.enumerated().forEach { (i, browser) in
            if (blocklist.contains(browser) && primaryDefault != browser) {
                selectedRows.add(i)
            }
        }
        blocklistTable.deselectAll(self)
        blocklistTable.selectRowIndexes(selectedRows as IndexSet, byExtendingSelection: false)
    }

    // MARK: UI Actions

    // user clicked a browser from the menu
    @objc func selectBrowser(sender: NSMenuItem) {
        if let menuItem = sender as? BrowserMenuItem {
            if explicitBrowser == menuItem.bundleIdentifier {
                setExplicitBrowser(bundleId: nil)
            } else {
                setExplicitBrowser(bundleId: menuItem.bundleIdentifier)
            }
        }
    }

    // user clicked a browser from the menu
    func setExplicitBrowser(bundleId: String?) {
        if #available(macOS 11.0, *) {
            let intent: INIntent
            if let bid = bundleId {
                let setBrowserIntent = SetCurrentBrowserIntent()
                setBrowserIntent.browser = bid
                if let browserAppUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid),
                   let browserBundle = Bundle(url: browserAppUrl),
                   let appName = browserBundle.appName {
                    setBrowserIntent.suggestedInvocationPhrase = "Set browser to \(appName)"
                }
                intent = setBrowserIntent
            } else {
                intent = ClearCurrentBrowserIntent()
                intent.suggestedInvocationPhrase = "Use last used browser"
            }
            let donatedInteraction = INInteraction(intent: intent, response: nil)
            donatedInteraction.donate()
        }

        explicitBrowser = bundleId
        updateMenuItems()
    }

    // use user's primary browser -- user clicked the menu button
    @objc func usePrimary(sender: NSMenuItem) {
        setUsePrimary(state: sender.state != .on)
    }

    func setUsePrimary(state: Bool) {
        if defaults.primaryBrowser != "" {
            usePrimaryBrowser = state
            statusItem.button?.appearsDisabled = state
            explicitBrowser = nil
            updateMenuItems()
        }
    }

    @objc func openPreferencesWindow(sender: AnyObject) {
        preferencesWindow.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openAboutWindow(sender: AnyObject) {
        aboutWindow.center()
        aboutWindow.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func terminate() {
        NSApplication.shared.terminate(self)
    }

    // MARK: IB Actions

    @IBAction func primaryBrowserPopUpChange(sender: NSPopUpButton) {
        guard let item = sender.selectedItem as? BrowserMenuItem,
              let bid = item.bundleIdentifier else {
            return
        }
        defaults.primaryBrowser = bid
        defaults.browserBlocklist = defaults.browserBlocklist.filter { $0 != bid }
        updateBlocklistTable()
        updateMenuItems()
    }

    @IBAction func menuBarIconPopupChange(sender: NSPopUpButton) {
        guard let item = sender.selectedItem as? MenuBarIconMenuItem,
        let template = item.template,
        let style = item.style else { return }
        defaults.templateMenuBarIcon = template
        defaults.menuBarIconStyle = style
        updateMenuBarIconPopUp()
        updateMenuItems()
    }

    @IBAction func descriptiveAppNamesChange(sender: NSButton) {
        defaults.detailedAppNames = sender.state == .on
        updateMenuItems()
        updateBlocklistTable()
        updatePreferencesBrowsersPopup()
    }

    @IBAction func showWindowChange(sender: NSButton) {
        defaults.openWindowOnLaunch = sender.state == .on
    }

    @IBAction func refreshBrowsersPress(sender: AnyObject?) {
        resetBrowsers()
    }

    @IBAction func setAsDefaultPress(sender: AnyObject) {
        setAsDefaultHttpHandler()
    }

	func doDisclosure(sender: NSButton) {
		if sender.state == .on {
			blocklistHeightConstraint.constant = 160
		} else {
			blocklistHeightConstraint.constant = 0
		}
        updateBlocklistTable()
        updatePreferencesBrowsersPopup()
	}

    @IBAction func blocklistDisclosurePress(sender: NSButton) {
		doDisclosure(sender: sender)
    }
}

extension AppDelegate: NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Watch for when the user opens and quits applications
        workspace.addObserver(self, forKeyPath: "runningApplications", options: [.old, .new], context: nil)
        // Watch for when the user switches applications
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(applicationChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // Watch for dark mode change
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(appearanceChange),
            name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        // Watch for the user opening links
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent),
            forEventClass: UInt32(kInternetEventClass),
            andEventID: UInt32(kAEGetURL)
        )
        // Watch for user defaults changes
        primaryBrowserObserver = defaults.observe(\.PrimaryBrowser) { _, _ in
            DispatchQueue.main.async {
                self.resetBrowsers()
            }
        }
        blockedBrowserObserver = defaults.observe(\.BrowserBlocklist) { _, _ in
            DispatchQueue.main.async {
                self.resetBrowsers()
            }
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

        let selfBundleID = Bundle.main.bundleIdentifier!
        var selfName = getAppName(bundleId: selfBundleID)
        if selfName == "Unknown Application" {
            selfName = "Default Browser"
        }

        defaults.register(defaults: defaultSettings)

        if isCurrentlyDefaultHttpHandler() == false {
            let notDefaultAlert = NSAlert()
            notDefaultAlert.addButton(withTitle: "Set As Default")
            notDefaultAlert.addButton(withTitle: "Cancel")
            notDefaultAlert.messageText = "Set Default Browser"
            notDefaultAlert.informativeText = "\(selfName) must be set as your default browser. Your current default will be remembered."
            notDefaultAlert.alertStyle = .warning
            switch notDefaultAlert.runModal() {
            case NSApplication.ModalResponse.alertFirstButtonReturn:
                setAsDefaultHttpHandler()
            default:
                break
            }
        } else {
            self.setDefaultButton.isEnabled = false
        }

        setOpenOnLogin()

        // open window?
        preferencesWindow.isReleasedWhenClosed = false
        if defaults.openWindowOnLaunch {
            preferencesWindow.makeKeyAndOrderFront(self)
        }

        // set up menu bar
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
            button.allowsMixedState = true
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About \(selfName)", action: #selector(openAboutWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferencesWindow), keyEquivalent: ","))
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
        updateMenuBarIconPopUp()

        showWindowCheckbox.state = defaults.openWindowOnLaunch ? .on : .off
        descriptiveAppNamesCheckbox.state = defaults.detailedAppNames ? .on : .off
        blocklistHeightConstraint.constant = 0

        blocklistTable.dataSource = self
        blocklistTable.delegate = self

        updateBlocklistTable()
        updatePreferencesBrowsersPopup()

		// show blocklist contents if it's being used
		if blocklistTable.numberOfSelectedRows > 0 {
			disclosureTriangle.state = .on
			doDisclosure(sender: disclosureTriangle)
		}

        logo.image = NSImage(named: "AppIcon")

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)

        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "<unknown>"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "<unknown>"
        versionString.attributedStringValue = NSAttributedString(
            string: "Version \(shortVersion) (\(buildNumber))",
            attributes: [
                .paragraphStyle: paragraph,
                .font: font,
            ]
        )

        let cameronLink = NSAttributedString(
            string: "Cameron Little",
            attributes: [
                .link: "https://camlittle.com",
                .paragraphStyle: paragraph,
                .font: font,
            ]
        )
        let builtBy = NSMutableAttributedString(
            string: "Built by ",
            attributes: [
                .paragraphStyle: paragraph,
                .font: font,
            ]
        )
        builtBy.append(cameronLink)
        builtByString.allowsEditingTextAttributes = true
        builtByString.attributedStringValue = builtBy

        let githubLink = NSAttributedString(
            string: "GitHub project",
            attributes: [
                .link: "https://github.com/apexskier/DefaultBrowser",
                .paragraphStyle: paragraph,
                .font: font,
            ]
        )
        githubString.allowsEditingTextAttributes = true
        githubString.attributedStringValue = githubLink
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        workspace.removeObserver(self, forKeyPath: "runningApplications")
        workspace.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSAppleEventManager.shared().removeEventHandler(forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
        primaryBrowserObserver?.invalidate()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openUrls(urls: [URL(fileURLWithPath: filename)], additionalEventParamDescriptor: nil)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        _ = openUrls(urls: filenames.map({ URL(fileURLWithPath: $0) }), additionalEventParamDescriptor: nil)
    }

    @available(macOS 11.0, *)
    func application(_ application: NSApplication, handlerFor intent: INIntent) -> Any? {
        switch intent {
        case is SetCurrentBrowserIntent:
            return SetCurrentBrowserIntentHandler()
        case is ClearCurrentBrowserIntent:
            return ClearCurrentBrowserIntentHandler()
        default:
            return nil
        }
    }
}

extension AppDelegate: NSTableViewDataSource {
}

extension AppDelegate: NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        validBrowsers.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let col = tableColumn else {
            return nil
        }

        let app = validBrowsers[row]
        let cell = tableView.makeView(withIdentifier: col.identifier, owner: self) as! NSTableCellView
        if let url = workspace.urlForApplication(withBundleIdentifier: app) {
            let image = workspace.icon(forFile: url.relativePath)
            image.size = NSSize(width: MENU_ITEM_HEIGHT, height: MENU_ITEM_HEIGHT)
            cell.imageView?.image = image
        }
        cell.textField?.textColor = app == defaults.primaryBrowser
        ? .disabledControlTextColor
        : .controlTextColor
        cell.textField?.stringValue = appName(for: app)
        return cell
    }

    func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        defaults.browserBlocklist = proposedSelectionIndexes
            .map { validBrowsers[$0] }
            .filter { $0 != defaults.primaryBrowser }
        if let primaryBrowser = defaults.primaryBrowser,
           let primaryIndex = validBrowsers.firstIndex(of: primaryBrowser) {
            let newSelection = NSMutableIndexSet(indexSet: proposedSelectionIndexes)
            newSelection.remove(primaryIndex)
            return newSelection as IndexSet
        }
        return proposedSelectionIndexes
    }
}
