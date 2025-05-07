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

