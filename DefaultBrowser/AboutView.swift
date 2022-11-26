//
//  About.swift
//  Default Browser
//
//  Created by Cameron Little on 2022-11-26.
//  Copyright © 2022 Cameron Little. All rights reserved.
//

import SwiftUI

let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "<unknown>"
let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "<unknown>"

@available(macOS 10.15, *)
extension Text {
    func withSmallFontStyle() -> some View {
        self
            .font(.system(size: NSFont.smallSystemFontSize))
            .multilineTextAlignment(.center)
    }
}

@available(macOS 10.15, *)
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("AppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 100)
            Text("DefaultBrowser will automatically open links using the last browser you've used. You can disable this temporarily by clicking the menu icon and choosing a browser.")
            VStack(spacing: 8) {
                Text("Version \(shortVersion) (\(buildNumber))")
                Text("Built by [Cameron Little](https://camlittle.com)")
                Text("[GitHub project](https://github.com/apexskier/DefaultBrowser)")
            }
            .font(.system(size: NSFont.smallSystemFontSize))
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 340)
        .padding(.all)
    }
}

@available(macOS 10.15.0, *)
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
