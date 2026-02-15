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

// return bundle ids for all applications that can open links
func getAllBrowsers() -> [String] {
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
            if let bundle = Bundle(url: handlerUrl), let bundleID = bundle.bundleIdentifier {
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
        .sorted(by: { getAppName(bundleId: $0) < getAppName(bundleId: $1) })
}

// return bundle ids for all applications that can open links
func getUserScopedBrowsers() -> Set<URL> {
    if #available(macOS 12.0, *) {
        let workspace = NSWorkspace.shared
        var handlerUrls = Set<URL>()
        for scheme in browserQualifyingSchemes {
            handlerUrls.formUnion(workspace.urlsForApplications(toOpen: URL(string: "\(scheme)://")!))
        }

        return Set(handlerUrls.filter({ Bundle(url: $0) == nil }))
    } else {
        return []
    }
}

// return a name for an application's bundle id
func getAppName(bundleId: String) -> String {
    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
       let appBundle = Bundle(url: appUrl),
       let name = appBundle.appName
        ?? appBundle.infoDictionary?["CFBundleExecutable"] as? String
        ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.lastPathComponent {
        return name
    }
    return bundleId
}

// return a descriptive name for an application's bundle id
func getDetailedAppName(bundleId: String) -> String {
    var name = getAppName(bundleId: bundleId)
    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
       let appBundle = Bundle(url: appUrl),
       let version = appBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
        name += " (\(version))"
    }
    return name
}
