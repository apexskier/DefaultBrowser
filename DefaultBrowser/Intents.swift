//
//  Intents.swift
//  Default Browser
//
//  Created by Cameron Little on 2022-11-23.
//  Copyright © 2022 Cameron Little. All rights reserved.
//

import Intents
import AppKit

@available(macOS 11.0, *)
class GetUsePrimaryBrowserIntentHandler: NSObject, GetUsePrimaryBrowserIntentHandling {
    func handle(intent: GetUsePrimaryBrowserIntent) async -> GetUsePrimaryBrowserIntentResponse {
        guard let appDelegate = await NSApplication.shared.delegate as? AppDelegate else {
            return GetUsePrimaryBrowserIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil)
        }

        let response = GetUsePrimaryBrowserIntentResponse(code: .success, userActivity: nil)
        response.usingPrimaryBrowser = NSNumber(booleanLiteral: appDelegate.usePrimaryBrowser == true)
        return response
    }
}

@available(macOS 11.0, *)
class SetUsePrimaryBrowserIntentHandler: NSObject, SetUsePrimaryBrowserIntentHandling {
    func handle(intent: SetUsePrimaryBrowserIntent) async -> SetUsePrimaryBrowserIntentResponse {
        guard let appDelegate = await NSApplication.shared.delegate as? AppDelegate else {
            return SetUsePrimaryBrowserIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil)
        }

        let newState: Bool
        switch intent.usePrimaryBrowser {
        case .on:
            newState = true
        case .off:
            newState = false
        default:
            return SetUsePrimaryBrowserIntentResponse(code: .failure, userActivity: nil)
        }

        DispatchQueue.main.sync {
            appDelegate.setUsePrimary(state: newState)
        }

        return SetUsePrimaryBrowserIntentResponse(code: .success, userActivity: nil)
    }

    func resolveUsePrimaryBrowser(for intent: SetUsePrimaryBrowserIntent) async -> UsePrimaryBrowserStateResolutionResult {
        UsePrimaryBrowserStateResolutionResult.success(with: intent.usePrimaryBrowser)
    }
}

@available(macOS 11.0, *)
func genericResolveBrowser(for browser: String?) async -> INStringResolutionResult {
    guard let inputBrowser = browser else {
        return INStringResolutionResult.unsupported()
    }

    let browsers = getAllBrowsers()
    if browsers.contains(inputBrowser) {
        return INStringResolutionResult.success(with: inputBrowser)
    }

    let matchingBrowsers = browsers.filter({ browser in
        browser.contains(inputBrowser)
    })
    if matchingBrowsers.count == 0 {
        return INStringResolutionResult.unsupported()
    }
    if matchingBrowsers.count == 1 {
        return INStringResolutionResult.confirmationRequired(with: matchingBrowsers.first)
    }
    return INStringResolutionResult.disambiguation(with: matchingBrowsers)
}

@available(macOS 11.0, *)
func genericProvideBrowserOptionsCollection() async throws -> INObjectCollection<NSString> {
    let browsers = getAllBrowsers()
    return INObjectCollection(items: browsers.map({ NSString(string: $0) }))
}

@available(macOS 11.0, *)
class SetPrimaryBrowserIntentHandler: NSObject, SetPrimaryBrowserIntentHandling {
    // user settings
    private static let defaults = ThisDefaults()

    func handle(intent: SetPrimaryBrowserIntent) async -> SetPrimaryBrowserIntentResponse {
        guard let browser = intent.browser else {
            return SetPrimaryBrowserIntentResponse(code: .failure, userActivity: nil)
        }

        SetPrimaryBrowserIntentHandler.defaults.primaryBrowser = browser

        return SetPrimaryBrowserIntentResponse(code: .success, userActivity: nil)
    }

    func resolveBrowser(for intent: SetPrimaryBrowserIntent) async -> INStringResolutionResult {
        return await genericResolveBrowser(for: intent.browser)
    }

    func provideBrowserOptionsCollection(for intent: SetPrimaryBrowserIntent) async throws -> INObjectCollection<NSString> {
        return try await genericProvideBrowserOptionsCollection()
    }
}

@available(macOS 11.0, *)
class SetCurrentBrowserIntentHandler: NSObject, SetCurrentBrowserIntentHandling {
    // user settings
    private static let defaults = ThisDefaults()

    func handle(intent: SetCurrentBrowserIntent) async -> SetCurrentBrowserIntentResponse {
        guard let appDelegate = await NSApplication.shared.delegate as? AppDelegate else {
            return SetCurrentBrowserIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil)
        }

        guard let browser = intent.browser else {
            return SetCurrentBrowserIntentResponse(code: .failure, userActivity: nil)
        }

        DispatchQueue.main.sync {
            appDelegate.setExplicitBrowser(bundleId: browser)
        }

        return SetCurrentBrowserIntentResponse(code: .success, userActivity: nil)
    }

    func resolveBrowser(for intent: SetCurrentBrowserIntent) async -> INStringResolutionResult {
        return await genericResolveBrowser(for: intent.browser)
    }

    func provideBrowserOptionsCollection(for intent: SetCurrentBrowserIntent) async throws -> INObjectCollection<NSString> {
        return try await genericProvideBrowserOptionsCollection()
    }
}

@available(macOS 11.0, *)
class ClearCurrentBrowserIntentHandler: NSObject, ClearCurrentBrowserIntentHandling {
    func handle(intent: ClearCurrentBrowserIntent) async -> ClearCurrentBrowserIntentResponse {
        guard let appDelegate = await NSApplication.shared.delegate as? AppDelegate else {
            return ClearCurrentBrowserIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil)
        }

        DispatchQueue.main.sync {
            appDelegate.setExplicitBrowser(bundleId: nil)
        }

        return ClearCurrentBrowserIntentResponse(code: .success, userActivity: nil)
    }
}
