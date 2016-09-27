//
//  Highlightr.swift
//  Pods
//
//  Created by Illanes, J.P. on 4/10/16.
//
//

import Foundation
import JavaScriptCore

/// Utility class for generating a highlighted NSAttributedString from a String.
open class Highlightr {
    /// Returns the current Theme.
    open var theme : Theme!

    private let jsContext : JSContext
    private let hljs = "window.hljs"
    private let bundle : Bundle
    private let htmlStart = "<"
    private let spanStart = "span class=\""
    private let spanStartClose = "\">"
    private let spanEnd = "/span>"
    private let htmlEscape = try! NSRegularExpression(pattern: "&#?[a-zA-Z0-9]+?;", options: .caseInsensitive)

    /// Default init method, generates a JSContext instance and the default Theme.
    public init?() {
        jsContext = JSContext()
        jsContext.evaluateScript("var window = {};")
        bundle = Bundle(for: Highlightr.self)

        guard let hgPath = bundle.path(forResource: "highlight.min", ofType: "js") else {
            return nil
        }

        do {
            let hgJs = try String.init(contentsOfFile: hgPath)
            if !jsContext.evaluateScript(hgJs).toBool() {
                return nil
            }

            if !setTheme("pojoaque") {
                return nil
            }
        } catch {
            return nil
        }
    }

    /// Set the theme to use for highlighting.
    ///
    /// - parameter name: String, theme name.
    ///
    /// - returns: true if it was posible to set the given theme, false otherwise.
    open func setTheme(_ name: String) -> Bool {
        guard let defTheme = bundle.path(forResource: name + ".min", ofType: "css") else {
            return false
        }

        do {
            let themeString = try String.init(contentsOfFile: defTheme)
            theme =  Theme(themeString: themeString)
            return true
        } catch {
            return false
        }
    }

    /// Takes a String and returns a NSAttributedString with the given language highlighted.
    ///
    /// - parameter languageName: Language name or alias
    /// - parameter code: Code to highlight
    /// - parameter fastRender: If *true* will use the custom made html parser rather than Apple's solution.
    ///
    /// - returns: NSAttributedString with the detected code highlighted.
    open func highlight(with languageName: String?, code: String, fastRender: Bool) -> NSAttributedString? {
        var fixedCode = code.replacingOccurrences(of: "\\",with: "\\\\")
        fixedCode = fixedCode.replacingOccurrences(of: "\'",with: "\\\'")
        fixedCode = fixedCode.replacingOccurrences(of: "\"", with:"\\\"")
        fixedCode = fixedCode.replacingOccurrences(of: "\n", with:"\\n")
        fixedCode = fixedCode.replacingOccurrences(of: "\r", with:"")

        var command: String! = nil

        if let languageName = languageName {
            command = "\(hljs).highlight(\"\(languageName)\",\"\(fixedCode)\").value;"
        } else {
            command = "\(hljs).highlightAuto(\"\(fixedCode)\").value;"
        }

        guard var string = jsContext.evaluateScript(command).toString() else {
            return nil
        }

        if fastRender {
            return process(HTMLString: string)
        } else {
            string = "<style>"+theme.lightTheme+"</style><pre><code class=\"hljs\">"+string+"</code></pre>"
            let options: [String : Any] = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: String.Encoding.utf8]
            
            guard let data = string.data(using: String.Encoding.utf8) else {
                return nil
            }

            return try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil)
        }
    }

    /// Returns a list of all the available themes.
    ///
    /// - returns: Array of Strings
    open func availableThemes() -> [String] {
        var result: [String] = []

        bundle.paths(forResourcesOfType: "css", inDirectory: nil).forEach { path in
            result.append((path as NSString).lastPathComponent.replacingOccurrences(of: ".min.css", with: ""))
        }

        return result
    }

    /// Returns a list of all supported languages.
    ///
    /// - returns: Array of Strings
    open func supportedLanguages() -> [String] {
        return (jsContext.evaluateScript("\(hljs).listLanguages();")?.toArray() as? [String]) ?? []
    }

    open func isSupportedLanguage(_ language: String) -> Bool {
        return jsContext.evaluateScript("\(hljs).getLanguage(\"\(language)\");").toObject() != nil
    }

    //Private & Internal
    fileprivate func process(HTMLString: String) -> NSAttributedString? {
        let scanner = Scanner(string: HTMLString)
        scanner.charactersToBeSkipped = nil
        var scannedString: NSString? = nil
        let resultString = NSMutableAttributedString(string: "")
        var propStack = ["hljs"]

        while !scanner.isAtEnd {
            var ended = false
            if scanner.scanUpTo(htmlStart, into: &scannedString) {
                if scanner.isAtEnd {
                    ended = true
                }
            }

            if let scannedString = scannedString, scannedString.length > 0 {
                let attrScannedString = theme.applyStyleToString(scannedString as String, styleList: propStack)
                resultString.append(attrScannedString)
                if ended {
                    continue
                }
            }

            scanner.scanLocation += 1

            let string = scanner.string as NSString
            let nextChar = string.substring(with: NSMakeRange(scanner.scanLocation, 1))

            if nextChar == "s" {
                scanner.scanLocation += (spanStart as NSString).length
                scanner.scanUpTo(spanStartClose, into: &scannedString)
                scanner.scanLocation += (spanStartClose as NSString).length
                if let scannedString = scannedString as? String {
                    propStack.append(scannedString)
                }
            } else if nextChar == "/" {
                scanner.scanLocation += (spanEnd as NSString).length
                _ = propStack.popLast()
            } else {
                let attrScannedString = theme.applyStyleToString("<", styleList: propStack)
                resultString.append(attrScannedString)
                scanner.scanLocation += 1
            }

            scannedString = nil
        }

        let results = htmlEscape.matches(in: resultString.string, options: [.reportCompletion], range: NSMakeRange(0, resultString.length))

        var locOffset = 0

        results.forEach { result in
            let fixedRange = NSMakeRange(result.range.location - locOffset, result.range.length)
            let entity = (resultString.string as NSString).substring(with: fixedRange)
            if let decodedEntity = HTMLUtils.decode(entity) {
                resultString.replaceCharacters(in: fixedRange, with: String(decodedEntity))
                locOffset += result.range.length - 1
            }
        }

        return resultString
    }
}
