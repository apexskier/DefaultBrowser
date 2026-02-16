//
//  SystemUtilities.swift
//  DefaultBrowser
//
//  Created by Cameron Little on 11/4/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Cocoa

let browserQualifyingSchemes = ["https", "http"]

struct CoreBundle {
    let cfBundle: CFBundle

    init?(url: URL) {
        cfBundle = CFBundleCreate(kCFAllocatorDefault, url as CFURL)
    }

    var bundleIdentifier: String? {
        CFBundleGetIdentifier(cfBundle) as String?
    }

    var infoDictionary: [String : Any]? {
        CFBundleGetInfoDictionary(cfBundle) as? [String : Any]
    }

    func object(forInfoDictionaryKey key: String) -> Any? {
        CFBundleGetValueForInfoDictionaryKey(cfBundle, key as CFString) as Any?
    }
}

// BundleInfo holds bundle information in memory so we can access it after we've stopped reading from
// a security scoped url
struct BundleInfo {
    let bundleIdentifier: String
    let infoDictionary: [String: Any]?
    let appName: String?

    init?(bundle: Bundle) {
        guard let id = bundle.bundleIdentifier else {
            return nil
        }

        self.bundleIdentifier = id
        self.infoDictionary = bundle.infoDictionary
        self.appName = bundle.appName
    }
}

// bundle accesses a bundle, using security-scoped bookmarks if necessary
func bundle(url: URL, defaults: ThisDefaults) -> BundleInfo? {
    if let bundle = Bundle(url: url) {
        return .init(bundle: bundle)
    }

    // Find the most specific bookmark that covers this file path
    let matchingBookmark = defaults.bookmarks.first { bookmarkUrl, _ in
        url.path.hasPrefix(bookmarkUrl.path)
    }

    guard let (bookmarkPath, bookmarkData) = matchingBookmark else {
        return nil
    }

    var isStale = false
    let bookmarkUrl = try! URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    )

    // generate a relative path from the `url` to the `bookmarkPath`, then generate `bundleUrl` to the `bookmarkUrl` with the same relative path. This allows us to support bookmarks to parent directories of the actual app bundle, which is necessary for some browsers like Chrome that have helper apps in subdirectories of the main app bundle
    let relativePath = String(url.path.dropFirst(bookmarkPath.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let bundleUrl = relativePath.isEmpty ? bookmarkUrl : bookmarkUrl.appendingPathComponent(relativePath)

    if isStale {
        print("⚠️ Bookmark is stale - need to request permission again")
        return nil
    }

    guard bookmarkUrl.startAccessingSecurityScopedResource() else {
        print("❌ Failed to access security-scoped resource")
        return nil
    }

    guard let bundle = Bundle(url: bundleUrl) else {
        return nil
    }

    let bi = BundleInfo(bundle: bundle)

    bookmarkUrl.stopAccessingSecurityScopedResource()

    return bi
}

// return bundle ids for all applications that can open links
func getAllBrowsers(defaults: ThisDefaults) -> [String] {
    let browserBids: Set<String>
    if #available(macOS 12.0, *) {
        let workspace = NSWorkspace.shared
        var handlerUrls = Set<URL>()
        for scheme in browserQualifyingSchemes {
            handlerUrls.formUnion(workspace.urlsForApplications(toOpen: URL(string: "\(scheme)://")!))
        }

        var localBrowserBids: Set<String> = []
        var userAccessRequiredUrls: Set<URL> = []

        for handlerUrl in handlerUrls {
            if let bundleID = bundle(url: handlerUrl, defaults: defaults)?.bundleIdentifier {
                localBrowserBids.insert(bundleID)
            } else {
                userAccessRequiredUrls.insert(handlerUrl)
            }
        }

        browserBids = localBrowserBids
    } else {
        var handlers = Set<String>()
        for scheme in browserQualifyingSchemes {
            handlers.formUnion(LSCopyAllHandlersForURLScheme(scheme as CFString)?.takeRetainedValue() as? [String] ?? [])
        }
        browserBids = handlers
    }

    let selfBid = Bundle.main.bundleIdentifier?.lowercased()
    return browserBids
        .filter({ $0.lowercased() != selfBid })
        .sorted(by: { getAppName(bundleId: $0, defaults: defaults) < getAppName(bundleId: $1, defaults: defaults) })
}

// return bundle ids for all applications that can open links
func getUserScopedBrowsers(defaults: ThisDefaults) -> [URL] {
    if #available(macOS 12.0, *) {
        let workspace = NSWorkspace.shared
        var handlerUrls = Set<URL>()
        for scheme in browserQualifyingSchemes {
            handlerUrls.formUnion(workspace.urlsForApplications(toOpen: URL(string: "\(scheme)://")!))
        }

        let urls = Array(handlerUrls.filter { bundle(url: $0, defaults: defaults) == nil })
        return urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    } else {
        return []
    }
}

// return a name for an application's bundle id
func getAppName(bundleId: String, defaults: ThisDefaults) -> String {
    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
       let appBundle = bundle(url: appUrl, defaults: defaults),
       let name = appBundle.appName
        ?? appBundle.infoDictionary?["CFBundleExecutable"] as? String
        ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.lastPathComponent {
        return name
    }
    return bundleId
}

// return a descriptive name for an application's bundle id
func getDetailedAppName(bundleId: String, defaults: ThisDefaults) -> String {
    var name = getAppName(bundleId: bundleId, defaults: defaults)
    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
       let appBundle = bundle(url: appUrl, defaults: defaults),
       let version = appBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
        name += " (\(version))"
    }
    return name
}

