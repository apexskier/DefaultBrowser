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

// return a name for an application's bundle id
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

// return a descriptive name for an application's bundle id
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