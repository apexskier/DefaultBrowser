//
//  ImageTransforms.swift
//  Default Browser
//
//  Created by Cameron Little on 2025-05-06.
//  Copyright © 2025 Cameron Little. All rights reserved.
//

import AppKit

extension NSImage {
    /// Creates a semi-transparent version of the image
    /// - Parameter alpha: The transparency level (0.0 = fully transparent, 1.0 = fully opaque)
    /// - Returns: A new NSImage with the specified transparency
    func withAlpha(_ alpha: CGFloat) -> NSImage {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return self
        }

        return NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current else {
                return false
            }

            context.imageInterpolation = .high
            context.compositingOperation = .copy

            context.cgContext.setAlpha(alpha)
            context.cgContext.draw(cgImage, in: rect)

            return true
        }
    }
}

// converts a full color image into an inverted template image for use in the menu bar
func convertToTemplateImage(cgImage: CGImage) -> CGImage? {
    let width = cgImage.width
    let height = cgImage.height
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    ) else {
        return nil
    }

    // Draw original image
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Get image data
    guard let data = context.data else {
        return nil
    }

    // Process pixels - convert to grayscale and then to black with appropriate transparency
    let pixelData = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let pixelIndex = (width * y + x) * 4

            // Get RGB values
            let r = pixelData[pixelIndex]
            let g = pixelData[pixelIndex + 1]
            let b = pixelData[pixelIndex + 2]
            let a = pixelData[pixelIndex + 3]

            // Convert to grayscale using luminance formula
            let gray = UInt8((0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) * (Double(a) / 255.0))

            // Set black color with transparency based on grayscale value (255-gray)
            // Dark areas become opaque black, light areas become transparent
            pixelData[pixelIndex] = 0     // R = 0 (black)
            pixelData[pixelIndex + 1] = 0 // G = 0 (black)
            pixelData[pixelIndex + 2] = 0 // B = 0 (black)
            pixelData[pixelIndex + 3] = gray // Alpha (inverted from grayscale)
        }
    }

    // Create image from processed context
    return context.makeImage()
}

// convert a template image back to a normal image (invert black/white)
func convertFromTemplateImage(cgImage: CGImage) -> CGImage? {
    let width = cgImage.width
    let height = cgImage.height

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    ) else {
        return nil
    }

    // Draw original image
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Get image data
    guard let data = context.data else {
        return nil
    }

    // Process pixels - convert to grayscale and then to black with appropriate transparency
    let pixelData = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let pixelIndex = (width * y + x) * 4

            // Get RGB values
            let r = pixelData[pixelIndex]
            let g = pixelData[pixelIndex + 1]
            let b = pixelData[pixelIndex + 2]
            let a = pixelData[pixelIndex + 3]

            // invert black to white
            pixelData[pixelIndex] = 255 - r
            pixelData[pixelIndex + 1] = 255 - b
            pixelData[pixelIndex + 2] = 255 - g
            pixelData[pixelIndex + 3] = UInt8(Double(a) * 0.9) // scale by 90% to better match template behavior
        }
    }

    // Create image from processed context
    return context.makeImage()
}

class IconCacheKey: NSObject {
    var appearance: NSAppearance
    var style: MenuBarIconStyle
    var template: Bool
    var size: CGFloat
    var bundleId: String

    init(
        appearance: NSAppearance,
        style: MenuBarIconStyle,
        template: Bool,
        size: CGFloat,
        bundleId: String
    ) {
        self.appearance = appearance
        self.style = style
        self.template = template
        self.size = size
        self.bundleId = bundleId
    }
}

func generateIcon(
    key: IconCacheKey,
    base: NSImage,
    in workspace: NSWorkspace
) -> NSImage? {
    guard let iconUrl = workspace.urlForApplication(withBundleIdentifier: key.bundleId),
          let baseRep = base.bestRepresentation(
            for: NSRect(origin: .zero, size: NSSize(width: key.size, height: key.size)),
            context: nil,
            hints: [ .interpolation: NSImageInterpolation.high ]
          )
    else {
        return nil
    }

    var rect = CGRect(
        origin: .zero,
        size: CGSize(width: baseRep.pixelsWide, height: baseRep.pixelsHigh)
    )
    guard let baseCG = baseRep.cgImage(
        forProposedRect: &rect,
        context: nil,
        hints: nil
    ) else {
        return nil
    }

    // Create a bitmap context to draw into
    guard let context = CGContext(
        data: nil,
        width: baseRep.pixelsWide,
        height: baseRep.pixelsHigh,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
    ) else {
        return nil
    }

    // calculate the space the browser icon will be drawn into
    let browserIconRect: CGRect
    if baseRep.pixelsHigh == 32 {
        let h = 21.0
        browserIconRect = CGRect(
            x: 5.5,
            y: 32 - h - 9.0, // invert due to flipped coordinate system
            width: h,
            height: h
        )
    } else if baseRep.pixelsHigh == 16 {
        let h = 8.0
        browserIconRect = CGRect(
            x: 4,
            y: 16 - h - 7.0, // invert due to flipped coordinate system
            width: h,
            height: h
        )
    } else {
        return nil
    }

    // fetch browser icon, sized as small as we can to fit the space it'll go into
    // if the browser has a simplifed version at small size, it'll look a lot better
    guard let browserIconRep = workspace
        .icon(forFile: iconUrl.relativePath)
        .bestRepresentation(
            for: CGRect(origin: .zero, size: browserIconRect.size),
            context: nil,
            hints: [ .interpolation: NSImageInterpolation.high ]
        ),
          let browserIconCG = browserIconRep.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }

    // invert appropriatly if we're using a template image or not
    let baseDrawable: CGImage
    let browserDrawable: CGImage
    if key.template {
        guard let templateBrowserImageCG = convertToTemplateImage(cgImage: browserIconCG) else {
            return nil
        }
        baseDrawable = baseCG
        browserDrawable = templateBrowserImageCG
    } else {
        guard let baseConverted = convertFromTemplateImage(cgImage: baseCG) else {
            return nil
        }
        baseDrawable = baseConverted
        browserDrawable = browserIconCG
    }

    // assemble the menu bar icon
    switch key.style {
    case .browserIcon:
        context.draw(browserDrawable, in: rect)
    case .framed:
        context.draw(baseDrawable, in: rect)
        context.draw(browserDrawable, in: browserIconRect)
    }

    guard let outputCGImage = context.makeImage() else {
        return nil
    }

    let outputImage = NSImage(cgImage: outputCGImage, size: baseRep.size)
    outputImage.isTemplate = key.template

    return outputImage
}

