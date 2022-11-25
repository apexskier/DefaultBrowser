//
//  DefaultBrowserLauncherApp.swift
//  DefaultBrowserLauncher
//
//  Created by Cameron Little on 2022-11-24.
//  Copyright © 2022 Cameron Little. All rights reserved.
//

import SwiftUI

let mainAppIdentifier = "com.camlitte.DefaultBrowser"

@NSApplicationMain
class AppDelegate: NSObject {
    @objc func terminate() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty

        if !isRunning {
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(self.terminate),
                name: .killLauncher,
                object: mainAppIdentifier
            )

            let mainAppURL = Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("MacOS")
                .appendingPathComponent("DefaultBrowser")

            let openConfig = NSWorkspace.OpenConfiguration()
            openConfig.allowsRunningApplicationSubstitution = true
            NSWorkspace.shared.openApplication(at: mainAppURL, configuration: openConfig)
        } else {
            self.terminate()
        }
    }
}

