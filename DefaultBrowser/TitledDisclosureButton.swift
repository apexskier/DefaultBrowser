//
//  TitledDisclosureButton.swift
//  Default Browser
//
//  Created by Cameron Little on 2026-02-15.
//  Copyright © 2026 Cameron Little. All rights reserved.
//

import Foundation
import Cocoa

let TRIANGLE_PADDING: CGFloat = 20

class TitledDisclosureButton: NSButtonCell {
    override func titleRect(forBounds theRect: NSRect) -> NSRect {
        // Disclosure triangles don't return a proper title rect, so calculate it ourselves
        var titleRect = NSRect.zero

        titleRect.origin.x = theRect.origin.x + TRIANGLE_PADDING
        titleRect.origin.y = theRect.origin.y
        titleRect.size.width = theRect.size.width - TRIANGLE_PADDING
        titleRect.size.height = theRect.size.height

        return titleRect
    }

    override func drawBezel(withFrame frame: NSRect, in controlView: NSView) {
        var bezelFrame = frame
        bezelFrame.size.width = TRIANGLE_PADDING

        super.drawBezel(withFrame: bezelFrame, in: controlView)
    }

    private var attributes: [NSAttributedString.Key: Any] {
        [
            .font: font ?? NSFont.labelFont(ofSize: NSFont.labelFontSize),
            .foregroundColor: isEnabled ? NSColor.controlTextColor : NSColor.disabledControlTextColor
        ]
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        // Draw the title text to the right of the triangle, vertically centered
        guard let title, !title.isEmpty else {
            return
        }

        let titleSize = (title as NSString).size(withAttributes: attributes)

        // Calculate vertically centered rect
        var titleFrame = NSRect.zero
        titleFrame.origin.x = cellFrame.origin.x + TRIANGLE_PADDING
        titleFrame.origin.y = cellFrame.origin.y + (cellFrame.size.height - titleSize.height) / 2.0
        titleFrame.size.width = cellFrame.size.width - TRIANGLE_PADDING
        titleFrame.size.height = titleSize.height

        (title as NSString).draw(in: titleFrame, withAttributes: attributes)
    }

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)

        // Calculate width needed for triangle + title
        if let title, !title.isEmpty {
            let titleSize = (title as NSString).size(withAttributes: attributes)
            size.width = TRIANGLE_PADDING + titleSize.width
        } else {
            size.width = TRIANGLE_PADDING
        }

        return size
    }
}
