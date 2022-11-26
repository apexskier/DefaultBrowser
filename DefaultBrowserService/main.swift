//
//  main.swift
//  DefaultBrowserServices
//
//  Created by Cameron Little on 2022-11-26.
//  Copyright © 2022 Cameron Little. All rights reserved.
//

import Foundation
import AppKit

print("Hello, World!")

let provider = ServiceProvider()

NSRegisterServicesProvider(provider, "DefaultBrowserService")

RunLoop.current.run()
