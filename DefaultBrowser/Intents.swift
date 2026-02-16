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
class SetCurrentBrowserIntentHandler: NSObject, SetCurrentBrowserIntentHandling {
    let defaults = ThisDefaults()

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
        guard let inputBrowser = intent.browser else {
            return INStringResolutionResult.unsupported()
        }

        let browsers = getAllBrowsers(defaults: defaults)

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

    func provideBrowserOptionsCollection(for intent: SetCurrentBrowserIntent) async throws -> INObjectCollection<NSString> {
        let browsers = getAllBrowsers(defaults: defaults)
        return INObjectCollection(items: browsers.map({ NSString(string: $0) }))
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
