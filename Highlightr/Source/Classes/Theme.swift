//
//  Theme.swift
//  Pods
//
//  Created by Illanes, J.P. on 4/24/16.
//
//

import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
    public typealias RPColor = UIColor
    public typealias RPFont = UIFont
#else
    import AppKit
    public typealias RPColor = NSColor
    public typealias RPFont = NSFont
#endif

private typealias RPThemeDict = [String: [String: AnyObject]]
private typealias RPThemeStringDict = [String: [String: String]]

open class Theme {
    let theme: String
    var lightTheme: String!

    open var codeFont: RPFont!
    open var boldCodeFont: RPFont!
    open var italicCodeFont: RPFont!

    private var themeDict: RPThemeDict!
    private var strippedTheme: RPThemeStringDict!

    open var lineSpacing: CGFloat = 0 {
        didSet {
            paragraphStyle.lineSpacing = lineSpacing
        }
    }

    private var paragraphStyle = NSMutableParagraphStyle()

    /// Default background color for the current theme.
    open var themeBackgroundColor: RPColor!

    init(themeString: String) {
        theme = themeString
        set(RPFont(name: "Courier", size: 14)!)
        strippedTheme = stripTheme(themeString)
        lightTheme = strippedThemeToString(strippedTheme)
        themeDict = strippedThemeToTheme(strippedTheme)

        var bkgColorHex = strippedTheme[".hljs"]?["background"]
        if bkgColorHex == nil {
            bkgColorHex = strippedTheme[".hljs"]?["background-color"]
        }

        if let bkgColorHex = bkgColorHex {
            if bkgColorHex == "white" {
                themeBackgroundColor = RPColor(white: 1, alpha: 1)
            } else if(bkgColorHex == "black") {
                themeBackgroundColor = RPColor(white: 0, alpha: 1)
            } else {
                let range = bkgColorHex.range(of: "#")
                let str = bkgColorHex.substring(from: (range?.lowerBound)!)
                themeBackgroundColor = colorWithHexString(str)
            }
        } else {
            themeBackgroundColor = RPColor.white
        }
    }

    /// Changes the theme font.
    ///
    /// - parameter font: UIFont (iOS or tvOS) or NSFont (OSX)
    open func set(_ codeFont: RPFont) {
        set(codeFont, italicCodeFont: nil, boldCodeFont: nil)
    }

    open func set(_ codeFont: RPFont, italicCodeFont: RPFont?, boldCodeFont: RPFont?) {
        self.codeFont = codeFont

        #if os(iOS) || os(tvOS)
        let boldDescriptor = UIFontDescriptor(fontAttributes: [UIFontDescriptorFamilyAttribute: codeFont.familyName, UIFontDescriptorFaceAttribute: "Bold"])
        let italicDescriptor = UIFontDescriptor(fontAttributes: [UIFontDescriptorFamilyAttribute: codeFont.familyName, UIFontDescriptorFaceAttribute:"Italic"])
        let obliqueDescriptor = UIFontDescriptor(fontAttributes: [UIFontDescriptorFamilyAttribute: codeFont.familyName, UIFontDescriptorFaceAttribute: "Oblique"])
        #else
        let boldDescriptor = NSFontDescriptor(fontAttributes: [NSFontFamilyAttribute: codeFont.familyName!, NSFontFaceAttribute: "Bold"])
        let italicDescriptor = NSFontDescriptor(fontAttributes: [NSFontFamilyAttribute: codeFont.familyName!, NSFontFaceAttribute: "Italic"])
        let obliqueDescriptor = NSFontDescriptor(fontAttributes: [NSFontFamilyAttribute: codeFont.familyName!, NSFontFaceAttribute: "Oblique"])
        #endif

        self.boldCodeFont = boldCodeFont ?? RPFont(descriptor: boldDescriptor, size: codeFont.pointSize)
        self.italicCodeFont = italicCodeFont ?? RPFont(descriptor: italicDescriptor, size: codeFont.pointSize)

        if italicCodeFont == nil || self.italicCodeFont.familyName != codeFont.familyName {
            self.italicCodeFont = RPFont(descriptor: obliqueDescriptor, size: codeFont.pointSize)
        } else if self.italicCodeFont == nil {
            self.italicCodeFont = codeFont
        }

        if self.boldCodeFont == nil {
            self.boldCodeFont = codeFont
        }

        if themeDict != nil {
            themeDict = strippedThemeToTheme(strippedTheme)
        }
    }
    
    func applyStyleToString(_ string: String, styleList: [String]) -> NSAttributedString {
        let returnString: NSAttributedString

        if styleList.count > 0 {
            var attrs: [String: AnyObject] = [:]
            attrs[NSFontAttributeName] = codeFont
            styleList.forEach { style in
                if let themeStyle = themeDict[style] {
                    for (attrName, attrValue) in themeStyle {
                        attrs.updateValue(attrValue, forKey: attrName)
                    }
                }
            }

            attrs[NSParagraphStyleAttributeName] = paragraphStyle

            returnString = NSAttributedString(string: string, attributes:attrs )
        } else {
            returnString = NSAttributedString(string: string, attributes:[NSFontAttributeName:codeFont] )
        }

        return returnString
    }
    
    private func stripTheme(_ themeString: String) -> [String: [String: String]] {
        let objcString = (themeString as NSString)

        guard let cssRegex = try? NSRegularExpression(pattern: "(?:(\\.[a-zA-Z0-9\\-_]*(?:[, ]\\.[a-zA-Z0-9\\-_]*)*)\\{([^\\}]*?)\\})", options:[.caseInsensitive]) else {
            return [:]
        }

        let results = cssRegex.matches(in: themeString, options: [.reportCompletion], range: NSMakeRange(0, objcString.length))

        var resultDict: [String: [String: String]] = [:]

        results.forEach { result in
            if result.numberOfRanges == 3 {
                var attributes: [String: String] = [:]
                let cssPairs = objcString.substring(with: result.rangeAt(2)).components(separatedBy: ";")
                cssPairs.forEach { pair in
                    let cssPropComp = pair.components(separatedBy: ":")
                    if cssPropComp.count == 2 {
                        attributes[cssPropComp[0]] = cssPropComp[1]
                    }
                }

                if attributes.count > 0 {
                    resultDict[objcString.substring(with: result.rangeAt(1))] = attributes
                }
            }
        }

        var returnDict: [String: [String: String]] = [:]

        for (keys, result) in resultDict {
            let keyArray = keys.replacingOccurrences(of: " ", with: ",").components(separatedBy: ",")
            keyArray.forEach { key in
                var props = returnDict[key]
                if props == nil {
                    props = [:]
                }

                for (pName, pValue) in result {
                    _ = props?.updateValue(pValue, forKey: pName)
                }

                returnDict[key] = props
            }
        }

        return returnDict
    }

    private func strippedThemeToString(_ theme: RPThemeStringDict) -> String {
        var resultString = ""
        for (key, props) in theme {
            resultString += key + "{"
            for (cssProp, val) in props {
                if key != ".hljs" || (cssProp.lowercased() != "background-color" && cssProp.lowercased() != "background") {
                    resultString += "\(cssProp):\(val);"
                }
            }
            resultString += "}"
        }
        return resultString
    }

    private func strippedThemeToTheme(_ theme: RPThemeStringDict) -> RPThemeDict {
        var returnTheme = RPThemeDict()
        for (className, props) in theme {
            var keyProps: [String:AnyObject] = [:]
            for (key, prop) in props {
                switch key {
                case "color":
                    keyProps[attributeForCSSKey(key)] = colorWithHexString(prop)
                case "font-style":
                    keyProps[attributeForCSSKey(key)] = fontForCSSStyle(prop)
                case "font-weight":
                    keyProps[attributeForCSSKey(key)] = fontForCSSStyle(prop)
                case "background-color":
                    keyProps[attributeForCSSKey(key)] = colorWithHexString(prop)
                default:
                    break
                }
            }

            if keyProps.count > 0 {
                let key = className.replacingOccurrences(of: ".", with: "")
                returnTheme[key] = keyProps
            }
        }
        return returnTheme
    }

    private func fontForCSSStyle(_ fontStyle:String) -> RPFont {
        switch fontStyle {
        case "bold", "bolder", "600", "700", "800", "900":
            return boldCodeFont
        case "italic", "oblique":
            return italicCodeFont
        default:
            return codeFont
        }
    }

    private func attributeForCSSKey(_ key: String) -> String {
        switch key {
        case "color":
            return NSForegroundColorAttributeName
        case "font-weight":
            return NSFontAttributeName
        case "font-style":
            return NSFontAttributeName
        case "background-color":
            return NSBackgroundColorAttributeName
        default:
            return NSFontAttributeName
        }
    }

    private func colorWithHexString(_ hex: String) -> RPColor {
        var cString = hex.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString = (cString as NSString).substring(from: 1)
        } else {
            switch cString {
            case "white":
                return RPColor(white: 1, alpha: 1)
            case "black":
                return RPColor(white: 0, alpha: 1)
            case "red":
                return RPColor(red: 1, green: 0, blue: 0, alpha: 1)
            case "green":
                return RPColor(red: 0, green: 1, blue: 0, alpha: 1)
            case "blue":
                return RPColor(red: 0, green: 0, blue: 1, alpha: 1)
            default:
                return RPColor.gray
            }
        }

        if cString.characters.count != 6 && cString.characters.count != 3 {
            return RPColor.gray
        }

        var r: CUnsignedInt = 0, g: CUnsignedInt = 0, b: CUnsignedInt = 0
        var divisor: CGFloat

        if cString.characters.count == 6 {
            let rString = (cString as NSString).substring(to: 2)
            let gString = ((cString as NSString).substring(from: 2) as NSString).substring(to: 2)
            let bString = ((cString as NSString).substring(from: 4) as NSString).substring(to: 2)

            Scanner(string: rString).scanHexInt32(&r)
            Scanner(string: gString).scanHexInt32(&g)
            Scanner(string: bString).scanHexInt32(&b)

            divisor = 255.0
        } else {
            let rString = (cString as NSString).substring(to: 1)
            let gString = ((cString as NSString).substring(from: 1) as NSString).substring(to: 1)
            let bString = ((cString as NSString).substring(from: 2) as NSString).substring(to: 1)
            
            Scanner(string: rString).scanHexInt32(&r)
            Scanner(string: gString).scanHexInt32(&g)
            Scanner(string: bString).scanHexInt32(&b)
            
            divisor = 15.0
        }

        return RPColor(red: CGFloat(r) / divisor, green: CGFloat(g) / divisor, blue: CGFloat(b) / divisor, alpha: CGFloat(1))
    }
}
