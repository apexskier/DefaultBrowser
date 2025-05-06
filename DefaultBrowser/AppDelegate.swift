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

// Menu item tags used to fetch them without a direct reference
enum MenuItemTag: Int {
    case BrowserListTop = 1
    case BrowserListBottom
    case usePrimary
}

// Height of each menu item's icon
let MENU_ITEM_HEIGHT: CGFloat = 16

let supportedSchemes = [
    "http",
    "https",
    "file",
    "html",
]

// converts a full color image into an inverted template image for use in the menu bar
func convertToTemplateImage(cgImage: CGImage) -> CGImage? {
    // Create bitmap context with alpha channel
    let width = cgImage.width
    let height = cgImage.height
    let bitsPerComponent = 8
    let bytesPerRow = width * 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo.rawValue) else {
        return nil
    }

    // Draw original image
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Get image data
    guard let data = context.data else {
        return nil
    }

    // Process pixels - convert to grayscale and then to black with appropriate transparency
    let pixelData = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let pixelIndex = (width * y + x) * 4

            // Get RGB values
            let r = pixelData[pixelIndex]
            let g = pixelData[pixelIndex + 1]
            let b = pixelData[pixelIndex + 2]
            let a = pixelData[pixelIndex + 3]

            // Convert to grayscale using luminance formula
            let gray = UInt8((0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) * (Double(a) / 255.0))

            // Set black color with transparency based on grayscale value (255-gray)
            // Dark areas become opaque black, light areas become transparent
            pixelData[pixelIndex] = 0     // R = 0 (black)
            pixelData[pixelIndex + 1] = 0 // G = 0 (black)
            pixelData[pixelIndex + 2] = 0 // B = 0 (black)
            pixelData[pixelIndex + 3] = gray // Alpha (inverted from grayscale)
        }
    }

    // Create image from processed context
    return context.makeImage()
}

// convert a template image back to a normal image (invert black/white)
func convertFromTemplateImage(cgImage: CGImage) -> CGImage? {
    // Create bitmap context with alpha channel
    let width = cgImage.width
    let height = cgImage.height
    let bitsPerComponent = 8
    let bytesPerRow = width * 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo.rawValue) else {
        return nil
    }

    // Draw original image
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Get image data
    guard let data = context.data else {
        return nil
    }

    // Process pixels - convert to grayscale and then to black with appropriate transparency
    let pixelData = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let pixelIndex = (width * y + x) * 4

            // Get RGB values
            let r = pixelData[pixelIndex]
            let g = pixelData[pixelIndex + 1]
            let b = pixelData[pixelIndex + 2]
            let a = pixelData[pixelIndex + 3]

            // invert black to white
            pixelData[pixelIndex] = 255 - r
            pixelData[pixelIndex + 1] = 255 - b
            pixelData[pixelIndex + 2] = 255 - g
            pixelData[pixelIndex + 3] = UInt8(Double(a) * 0.9) // scale by 90% to better match template behavior
        }
    }

    // Create image from processed context
    return context.makeImage()
}

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
            if let bid = self.bundleIdentifier, let url = workspace.urlForApplication(withBundleIdentifier: bid) {
                image = workspace.icon(forFile: url.relativePath)
                if let size = self.height {
                    image?.size = NSSize(width: size, height: size)
                }
            }
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject {
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var descriptiveAppNamesCheckbox: NSButton!
    @IBOutlet weak var templateMenuBarIconCheckbox: NSButton!
    @IBOutlet weak var disclosureTriangle: NSButton!
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
    
    var lastActiveApplication: NSRunningApplication = NSRunningApplication()
    
    // maybe will be used when manually opening a link in a specific app
    var skipNextBrowserSort = true
    
    // an explicitly chosen default browser
    var explicitBrowser: String? = nil
    
    // the user's "system" default browser
    var usePrimaryBrowser: Bool? = false
    
    // user settings
    let defaults = ThisDefaults()
    
    // get around a bug in the browser list when this app wasn't set as the default OS browser
    var firstTime = false

    var primaryBrowserObserver: NSKeyValueObservation?

    // MARK: Signal/Notification Responses
    
    // Respond to the user opening a link
    @objc func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        // not sure if the format always matches what I expect
        if let urlDescriptor = event.atIndex(1), let urlStr = urlDescriptor.stringValue, let url = URL(string: urlStr) {
            let _ = openUrl(url: url, additionalEventParamDescriptor: replyEvent)
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

    // Respond to the user changing appearance
    @objc func appearanceChange(notification: NSNotification) {
        updateMenuItems()
    }

    func openUrl(url: URL, additionalEventParamDescriptor descriptor: NSAppleEventDescriptor?) -> Bool {
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

        print("opening: \(url) in \(theBrowser)")
        let openConfiguration = NSWorkspace.OpenConfiguration()
        openConfiguration.activates = true
        workspace.open([url], withApplicationAt: browserUrl, configuration: openConfiguration) { runningApplication, error in
        }
        return true
    }
    
    // MARK: Management Methods

    private func updatePreferencesBrowsersPopup() {
        browsersPopUp.removeAllItems()
        var selectedPrimaryBrowser: NSMenuItem? = nil
        for bid in validBrowsers {
            let name = defaults.detailedAppNames ? getDetailedAppName(bundleId: bid) : getAppName(bundleId: bid)
            let menuItem = BrowserMenuItem(title: name, action: nil, keyEquivalent: "")
            menuItem.height = MENU_ITEM_HEIGHT
            menuItem.bundleIdentifier = bid
            if defaults.primaryBrowser?.lowercased() == bid.lowercased() {
                selectedPrimaryBrowser = menuItem
            }
            browsersPopUp.menu?.addItem(menuItem)
        }
        browsersPopUp.select(selectedPrimaryBrowser)
    }

    // update list of currently running browsers
    func updateBrowsers(apps: [NSRunningApplication]?) {
        if let apps = apps {
            /// Use one of the Dictionary extensions to merge the changes into procdict.
            for app in apps.filter({ return $0.bundleIdentifier != nil }) {
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
        if let primaryBrowser = defaults.primaryBrowser, usePrimaryBrowser == true {
            return primaryBrowser
        }
        let blocklist = defaults.browserBlocklist
        if let explicitBrowser = explicitBrowser {
            return explicitBrowser
        }
        if let firstRunningBrowser = runningBrowsers.filter({ browser in
            guard let bundleId = browser.bundleIdentifier else {
                return true
            }
            if browser.bundleIdentifier == Bundle.main.bundleIdentifier {
                return false
            }
            return !blocklist.contains(bundleId)
        }).first?.bundleIdentifier {
            return firstRunningBrowser
        }
        if let primaryBrowser = defaults.primaryBrowser {
            return primaryBrowser
        }
        if let firstAvailableBrowser = getAllBrowsers().filter({ bundleId in
            if bundleId == Bundle.main.bundleIdentifier {
                return false
            }
            return blocklist.contains(bundleId)
        }).first {
            return firstAvailableBrowser
        }
        return nil
    }
    
    // check if DefaultBrowser is the OS level link handler
    func isCurrentlyDefault() -> Bool {
        let selfBundleID = Bundle.main.bundleIdentifier!
        
        var currentlyDefault = true
        // TODO LSCopyDefaultHandlerForURLScheme is deprecated but I don't know a replacement
        if let currentDefaultBrowser = LSCopyDefaultHandlerForURLScheme(supportedSchemes[0] as CFString)?.takeRetainedValue() as String? {
            if currentDefaultBrowser.lowercased() != selfBundleID.lowercased() {
                currentlyDefault = false
                defaults.primaryBrowser = currentDefaultBrowser
                defaults.browserBlocklist = defaults.browserBlocklist.filter { $0 == currentDefaultBrowser }
            }
        }

        return currentlyDefault
    }
    
    // set DefaultBrowser as the OS level link handler
    func setAsDefault() {
        let selfBundleID = Bundle.main.bundleIdentifier! as CFString
        let selfURL = Bundle.main.bundleURL
        for scheme in supportedSchemes {
            if #available(macOS 12.0, *) {
                workspace.setDefaultApplication(at: selfURL, toOpenURLsWithScheme: scheme)
            } else {
                LSSetDefaultHandlerForURLScheme(scheme as CFString, selfBundleID)
            }
        }

        updateMenuItems()
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
        updateBrowsers(apps: workspace.runningApplications.sorted { (a, b) -> Bool in
            return (a.bundleIdentifier ?? "") == defaults.primaryBrowser
        })
        updateBlocklistTable()
        updatePreferencesBrowsersPopup()
    }

    class IconCacheKey: NSObject {
        var appearance: NSAppearance
        var template: Bool
        var size: CGFloat
        var bundleId: String

        init(appearance: NSAppearance, template: Bool, size: CGFloat, bundleId: String) {
            self.appearance = appearance
            self.template = template
            self.size = size
            self.bundleId = bundleId
        }
    }

    private var iconCache = NSCache<IconCacheKey, NSImage>()

    func getMenuBarIcon(for bundleId: String) -> NSImage? {
        guard let h = NSApplication.shared.mainMenu?.menuBarHeight else {
            return nil
        }

        let useTemplate = defaults.templateMenuBarIcon
        let key = IconCacheKey(
            appearance: NSApplication.shared.effectiveAppearance,
            template: useTemplate,
            size: h,
            bundleId: bundleId
        )
        if let image = iconCache.object(forKey: key) {
            return image
        }

        guard let iconUrl = workspace.urlForApplication(withBundleIdentifier: bundleId),
              let base = NSImage(named: "StatusBarButtonImage"),
              let baseRep = base.bestRepresentation(
                for: NSRect(origin: .zero, size: NSSize(width: h, height: h)),
                context: nil,
                hints: [ .interpolation: NSImageInterpolation.high ]
              )
        else {
            return nil
        }

        var rect = CGRect(
            origin: .zero,
            size: CGSize(width: baseRep.pixelsWide, height: baseRep.pixelsHigh)
        )
        guard let baseCG = baseRep.cgImage(
            forProposedRect: &rect,
            context: nil,
            hints: nil
        ) else {
            return nil
        }

        // Create a bitmap context to draw into
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: nil,
            width: baseRep.pixelsWide,
            height: baseRep.pixelsHigh,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // calculate the space the browser icon will be drawn into
        let browserIconRect: CGRect
        if baseRep.pixelsHigh == 32 {
            let h = 21.0
            browserIconRect = CGRect(
                x: 5.5,
                y: 32 - h - 9.0, // invert due to flipped coordinate system
                width: h,
                height: h
            )
        } else if baseRep.pixelsHigh == 16 {
            let h = 8.0
            browserIconRect = CGRect(
                x: 4,
                y: 16 - h - 7.0, // invert due to flipped coordinate system
                width: h,
                height: h
            )
        } else {
            return nil
        }

        // fetch browser icon, sized as small as we can to fit the space it'll go into
        // if the browser has a simplifed version at small size, it'll look a lot better
        guard let browserIconRep = workspace
            .icon(forFile: iconUrl.relativePath)
            .bestRepresentation(
                for: CGRect(origin: .zero, size: browserIconRect.size),
                context: nil,
                hints: [ .interpolation: NSImageInterpolation.high ]
            ),
              let browserIconCG = browserIconRep.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // invert appropriatly if we're using a template image or not
        let baseDrawable: CGImage
        let browserDrawable: CGImage
        if useTemplate {
            guard let templateBrowserImageCG = convertToTemplateImage(cgImage: browserIconCG) else {
                return nil
            }
            baseDrawable = baseCG
            browserDrawable = templateBrowserImageCG
        } else {
            guard let baseConverted = convertFromTemplateImage(cgImage: baseCG) else {
                return nil
            }
            baseDrawable = baseConverted
            browserDrawable = browserIconCG
        }

        // assemble the menu bar icon
        context.draw(baseDrawable, in: rect)
        context.draw(browserDrawable, in: browserIconRect)

        guard let outputCGImage = context.makeImage() else {
            return nil
        }

        let outputImage = NSImage(cgImage: outputCGImage, size: baseRep.size)
        outputImage.isTemplate = useTemplate

        // cache so we don't have to go through all this again
        iconCache.setObject(outputImage, forKey: key)

        return outputImage
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
        for app in runningBrowsers {
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
        }
        if let browser = explicitBrowser {
            if runningBrowsers.filter({ $0.bundleIdentifier == explicitBrowser }).isEmpty {
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
        if let item = sender.selectedItem as? BrowserMenuItem, let bid = item.bundleIdentifier {
            defaults.primaryBrowser = bid
            defaults.browserBlocklist = defaults.browserBlocklist.filter { $0 != bid }
            updateBlocklistTable()
            updateMenuItems()
        }
    }

    @IBAction func templateMenuBarIcon(sender: NSButton) {
        defaults.templateMenuBarIcon = sender.state == .off
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
        setAsDefault()
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

        showWindowCheckbox.state = defaults.openWindowOnLaunch ? .on : .off
        descriptiveAppNamesCheckbox.state = defaults.detailedAppNames ? .on : .off
        templateMenuBarIconCheckbox.state = defaults.templateMenuBarIcon ? .off : .on
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
        return false
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        workspace.removeObserver(self, forKeyPath: "runningApplications")
        workspace.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSAppleEventManager.shared().removeEventHandler(forEventClass: UInt32(kInternetEventClass), andEventID: UInt32(kAEGetURL))
        primaryBrowserObserver?.invalidate()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        return openUrl(url: URL(fileURLWithPath: filename), additionalEventParamDescriptor: nil)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let _ = self.application(sender, openFile: filename)
        }
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
        return validBrowsers.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = validBrowsers[row]
        if let col = tableColumn {
            let cell = tableView.makeView(withIdentifier: col.identifier, owner: self) as! NSTableCellView
            if let url = workspace.urlForApplication(withBundleIdentifier: app) {
                let image = workspace.icon(forFile: url.relativePath)
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
        if let primaryBrowser = defaults.primaryBrowser,
           let primaryIndex = validBrowsers.firstIndex(of: primaryBrowser) {
            let newSelection = NSMutableIndexSet(indexSet: proposedSelectionIndexes)
            newSelection.remove(primaryIndex)
            return newSelection as IndexSet
        }
        return proposedSelectionIndexes
    }
}
