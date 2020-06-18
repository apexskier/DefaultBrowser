//
//  SystemUtilities.swift
//  DefaultBrowser
//
//  Created by Cameron Little on 11/4/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Cocoa

// return bundle ids for all applications that can open links
func getAllBrowsers() -> [String] {
    let httpHandlers = LSCopyAllHandlersForURLScheme("http" as CFString)?.takeRetainedValue() as? [String] ?? []
    let httpsHandlers = LSCopyAllHandlersForURLScheme("https" as CFString)?.takeRetainedValue() as? [String] ?? []
    var urlHandlers = [String]()
    for bid in httpHandlers {
        urlHandlers.append(bid)
    }
    for bid in httpsHandlers {
        if !urlHandlers.contains(bid) {
            urlHandlers.append(bid)
        }
    }
    let selfBid = Bundle.main.bundleIdentifier!.lowercased()
    urlHandlers = urlHandlers.filter({ return $0.lowercased() != selfBid })
    urlHandlers.sort { getAppName(bundleId: $0) < getAppName(bundleId: $1) }
    return urlHandlers
}

// return a name for an application's bundle id
func getAppName(bundleId: String) -> String {
    var name = "Unknown Application"
    if let appPath = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleId) {
        if let appBundle = Bundle(path: appPath) {
            name = (appBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (appBundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? (appBundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String)
                ?? ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
        } else {
            name = ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
        }
    }
    return name
}

// return a descriptive name for an application's bundle id
func getDetailedAppName(bundleId: String) -> String {
    var name = "Unknown Application"
    if let appPath = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleId) {
        if let appBundle = Bundle(path: appPath) {
            name = (appBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (appBundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? (appBundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String)
                ?? ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
            if let version = appBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                name += " (\(version))"
            }
        } else {
            name = ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
        }
    }
    return name
}
