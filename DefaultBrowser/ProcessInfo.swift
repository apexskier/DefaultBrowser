//
//  ProcessInfo.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 17/7/14.
//  Copyright (c) 2014-2015 Rainer Brockerhoff. All rights reserved.
//

import Cocoa

public class ProcessInfo: Comparable {
    let bundleName: String
    let app: NSRunningApplication
    let name: String
    let url: NSURL
    let fpath: String
    
    init(_ app: NSRunningApplication) {
        //	Fetch some values I'll need later on.
        self.app = app
        self.name = app.localizedName!
        self.url = app.bundleURL!
        self.fpath = url.URLByDeletingLastPathComponent!.path!
        
        bundleName = name
    }
    
    lazy var icon: NSImage = {
        let image = self.app.icon!
        image.size = NSSize(width: 64, height: 64)		// hardcoded to match the table column size
        return image
    }()
    
    lazy var text: NSAttributedString = {//	Start off with the localized bundle name in bold
        var result = NSMutableAttributedString(string: self.name, attributes: styleBOLD12)
        
        //	Add the architecture as a bonus value
        switch self.app.executableArchitecture {
        case NSBundleExecutableArchitectureI386:
            result += (" (32-bit)", styleRED)		// red text: most apps should be 64 by now
        case NSBundleExecutableArchitectureX86_64:
            result += " (64-bit)"
        default:
            break
        }
        
        //	Add the containing folder path — path components should be localized, perhaps?
        //	Check down below for the += operator for NSMutableAttributedStrings.
        result += (" in “\(self.fpath)”\n...", styleNORM12)
        
        //	GetCodeSignatureForURL() may return nil, an empty dictionary, or a dictionary with parts missing.
        if let signature = GetCodeSignatureForURL(self.url) {
            
            //	The entitlements dictionary may also be missing.
            if let entitlements = signature["entitlements-dict"] as? NSDictionary,
                sandbox = entitlements["com.apple.security.app-sandbox"] as? NSNumber {
                    
                    //	Even if the sandbox entitlement is present it may be 0 or NO
                    if  sandbox.boolValue {
                        result += ("sandboxed, ", styleBLUE)	// blue text to stand out
                    }
            }
            
            result += "signed "
            
            //	The certificates array may be empty or missing entirely. Finally it's possible to cast
            //	directly to Array<SecCertificate> instead of going over CFTypeRef.
            let certificates = signature["certificates"] as? Array<SecCertificate>
            
            //	Using optional chaining here checks for both empty or missing.
            if certificates?.count > 0 {
                
                //	This gets the summaries for all certificates.
                let summaries = certificates!.map { (cert) -> String in
                    return SecCertificateCopySubjectSummary(cert) as String
                }
                
                //	Concatenating with commas is easy now
                result += "by " + summaries.joinWithSeparator(", ")
                
            } else {	// signed but no certificates
                result += "without certificates"
            }
            
        } else {	// code signature missing
            result += ("unsigned", styleRED)	// red text to stand out; most processes should be signed
        }
        
        return result
    }()
}	// end of ProcessInfo

//	================================================================================
/**
The following operators, globals and functions are here because they're used or
required by the `ProcessInfo` class.
*/

//	--------------------------------------------------------------------------------
//MARK:	public operators for comparing `ProcessInfo`s
/**
must define < and == to conform to the `Comparable` and `Equatable` protocols.

Here I use the `bundleName` in Finder order, convenient for sorting.
*/
public func < (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {	// required by Comparable
    return lhs.bundleName.localizedStandardCompare(rhs.bundleName) == NSComparisonResult.OrderedAscending
}

public func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {	// required by Equatable and Comparable
    return lhs.bundleName.localizedStandardCompare(rhs.bundleName) == NSComparisonResult.OrderedSame
}

//	--------------------------------------------------------------------------------
//MARK:	public operators for appending a string to a NSMutableAttributedString.
/*
var someString = NSMutableAttributedString()
someString += "text" // will append "text" to the string
someString += ("text", [NSForegroundColorAttributeName : NSColor.redColor()]) // will append red "text"

+= is already used for appending to a mutable string, so this is a useful shortcut.

Notice a useful feature in the second case: passing a tuple to an operator.
*/

/// The right-hand String is appended to the left-hand NSMutableString.
public func += (inout left: NSMutableAttributedString, right: String) {
    left.appendAttributedString(NSAttributedString(string: right, attributes: [ : ]))
}

/// The right-hand tuple contains a String with an attribute NSDictionary to append
/// to the left-hand NSMutableString.

public func += (inout left: NSMutableAttributedString, right: (str: String, att: [String : AnyObject])) {
    left.appendAttributedString(NSAttributedString(string: right.str, attributes: right.att))
}

//	Some preset style attributes for that last function.

public let styleRED: [String : AnyObject] = [NSForegroundColorAttributeName : NSColor.redColor()]
public let styleBLUE: [String : AnyObject] = [NSForegroundColorAttributeName : NSColor.blueColor()]
public let styleBOLD12: [String : AnyObject] = [NSFontAttributeName : NSFont.boldSystemFontOfSize(12)]
public let styleNORM12: [String : AnyObject] = [NSFontAttributeName : NSFont.systemFontOfSize(12)]


//	--------------------------------------------------------------------------------
//MARK: functions that get data from the Security framework

/**
This function returns an Optional NSDictionary containing code signature data for the
argument file URL.

Instead of the `Unmanaged` idiom used in previous versions, the (new in 7.0b4) annotations
for the Security framework use the `UnsafeMutablePointer` idiom.
*/
private func GetCodeSignatureForURL(url: NSURL?) -> NSDictionary? {
    var result: NSDictionary? = nil
    if let url = url {	// immediate unwrap if not nil, reuse the name
        
        var code: SecStaticCode? = nil
        
        // Note the nested withUnsafeMutablePointer() calls here for the Security APIs.
        result = withUnsafeMutablePointer(&code) { codePtr in
            let err: OSStatus = SecStaticCodeCreateWithPath(url, SecCSFlags.DefaultFlags, codePtr)
            if err == OSStatus(noErr) && code != nil {
                
                var dict: CFDictionary? = nil
                
                let err: OSStatus = withUnsafeMutablePointer(&dict) { dictPtr in
                    // we can force unwrap `code` here after the test for non-nil
                    return SecCodeCopySigningInformation(code!, SecCSFlags(rawValue: kSecCSSigningInformation), dictPtr)
                }
                return err == OSStatus(noErr) ? dict as NSDictionary? : nil
            }
            return nil
        }
    }
    return result	// if anything untoward happens, this will be nil.
}


