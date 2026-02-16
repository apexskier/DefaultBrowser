//
//  EnterKeyTableView.swift
//  DefaultBrowser
//
//  Created by Cameron Little on 2/15/26.
//  Copyright © 2026 Cameron Little. All rights reserved.
//

import Cocoa

// Custom NSTableView that triggers doubleAction on Enter key
class EnterKeyTableView: NSTableView {
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { // Return or Enter
            if let action = doubleAction, selectedRow >= 0 {
                NSApp.sendAction(action, to: nil, from: self)
                return
            }
        }
        super.keyDown(with: event)
    }
}

// Custom NSTableView that triggers doubleAction on Enter key
class DeleteKeyTableView: NSTableView {
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 { // Delete
            if let action = doubleAction, selectedRow >= 0 {
                NSApp.sendAction(action, to: nil, from: self)
                return
            }
        }
        super.keyDown(with: event)
    }
}
