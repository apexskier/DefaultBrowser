//
//  main.swift
//  IconGenerator
//
//  Created by Cameron Little on 2025-05-08.
//  Copyright © 2025 Cameron Little. All rights reserved.
//

import Foundation
import AppKit

let browsers = getAllBrowsers()

let workspace = NSWorkspace.shared

print(CommandLine.arguments)
if CommandLine.arguments.count < 3 {
    print("usage: \(CommandLine.arguments[0]) <path to base icon> <output dir>")
    exit(1)
}

guard let base = NSImage(byReferencingFile: CommandLine.arguments[1]) else {
    print("didn't find base image at: \(CommandLine.arguments[1])")
    exit(1)
}

let baseDir = URL(fileURLWithPath: CommandLine.arguments[2])

for useTemplate in [true, false] {
    for bundleId in browsers {
        guard var image = generateIcon(
            bundleId,
            size: 32,
            useTemplate: useTemplate,
            base: base,
            in: workspace
        ) else {
            fatalError()
        }

        if useTemplate,
           let cgimage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let reversed = convertFromTemplateImage(cgImage: cgimage) {
            image = NSImage(cgImage: reversed, size: image.size)
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            fatalError()
        }

        do {
            try pngData.write(to: baseDir.appending(path: "DefaultBrowserIcon_\(bundleId)\(useTemplate ? "_template" : "").png"))
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
