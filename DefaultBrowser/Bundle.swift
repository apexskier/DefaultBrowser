//
//  Bundle.swift
//  Default Browser
//
//  Created by Cameron Little on 2022-11-26.
//  Copyright © 2022 Cameron Little. All rights reserved.
//

import Foundation

extension Bundle {
    var appName: String? {
        let infoDict = (self.localizedInfoDictionary ?? self.infoDictionary)
        let localizedName = infoDict?["CFBundleDisplayName"] ?? infoDict?["CFBundleName"]
        return localizedName as? String
    }
}
