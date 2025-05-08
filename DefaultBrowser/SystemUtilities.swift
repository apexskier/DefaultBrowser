//
//  SystemUtilities.swift
//  DefaultBrowser
//
//  Created by Cameron Little on 11/4/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Cocoa

let browserQualifyingSchemes = ["https", "http"]

// return bundle ids for all applications that can open links
func getAllBrowsers() -> [String] {
    let browserBids: Set<String>
    if #available(macOS 12.0, *) {
        let workspace = NSWorkspace.shared
        var urlHandlers = Set<URL>()
        for scheme in browserQualifyingSchemes {
            urlHandlers.formUnion(workspace.urlsForApplications(toOpen: URL(string: "\(scheme)://")!))
        }
        browserBids = Set(urlHandlers.compactMap({ Bundle(url: $0)?.bundleIdentifier }))
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

// return a name for an application's bundle id
func getAppName(bundleId: String) -> String {
    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
       let appBundle = Bundle(url: appUrl),
       let name = appBundle.appName
        ?? appBundle.infoDictionary?["CFBundleExecutable"] as? String
        ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.lastPathComponent {
        return name
    }
    return "Unknown Application"
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
