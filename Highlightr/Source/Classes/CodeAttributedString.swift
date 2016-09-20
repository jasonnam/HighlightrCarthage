//
//  CodeAttributedString.swift
//  Pods
//
//  Created by Illanes, J.P. on 4/19/16.
//
//

import Foundation

@objc public protocol HighlightDelegate {
    /// If this method returns *false*, the highlighting process will be skipped for this range.
    ///
    /// - parameter range: NSRange
    ///
    /// - returns: Bool
    @objc optional func shouldHighlight(in range: NSRange) -> Bool

    /// Called after a range of the string was highlighted, if there was an error **success** will be *false*.
    ///
    /// - parameter range: NSRange
    /// - parameter success: Bool
    @objc optional func didHighlight(in range:NSRange, success: Bool)
}

open class CodeAttributedString : NSTextStorage {
    private var rawString = ""
    private let stringStorage = NSMutableAttributedString(string: "")

    /// Highlightr instace used internally for highlighting. Use this for configuring the theme.
    open var highlightr = Highlightr()!

    /// This object will be notified before and after the highlighting.
    open var highlightDelegate: HighlightDelegate?

    ///Language syntax to use for highlighting.
    open var language: String? {
        didSet {
            highlight(in: NSMakeRange(0, stringStorage.length))
        }
    }

    private var operationID = 0

    /// Returns a standard String based on the current one.
    open override var string: String {
        get {
            return rawString
        }
    }

    /// Returns the attributes for the character at a given index.
    ///
    /// - parameter location: Int
    /// - parameter range: NSRangePointer
    ///
    /// - returns: Attributes
    open override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [String : Any] {
        return stringStorage.attributes(at: location, effectiveRange: range)
    }

    /// Replaces the characters at the given range with the provided string.
    ///
    /// - parameter range: NSRange
    /// - parameter string: String
    open override func replaceCharacters(in range: NSRange, with string: String) {
        stringStorage.replaceCharacters(in: range, with: string)
        rawString = stringStorage.string
        edited(NSTextStorageEditActions.editedCharacters, range: range, changeInLength: string.characters.count - range.length)
    }

    /// Sets the attributes for the characters in the specified range to the specified attributes.
    ///
    /// - parameter attributes: [String : AnyObject]
    /// - parameter range: NSRange
    open override func setAttributes(_ attrs: [String : Any]?, range: NSRange) {
        stringStorage.setAttributes(attrs, range: range)
        edited(NSTextStorageEditActions.editedAttributes, range: range, changeInLength: 0)
    }

    /// Called internally everytime the string was modified.
    open override func processEditing() {
        super.processEditing()
        guard language != nil, editedMask.contains(.editedCharacters) else {
            return
        }

        let string = self.string as NSString
        let range = string.paragraphRange(for: editedRange)
        if string.substring(with: range) != "" {
            highlight(in: NSMakeRange(range.location, string.length - range.location))
        }
    }

    func highlight(in range: NSRange) {
        guard let language = language else {
            return
        }

        if let shouldHighlight = highlightDelegate?.shouldHighlight?(in: range), !shouldHighlight {
            return
        }

        let ID = operationID + 1
        self.operationID = ID

        let string = (self.string as NSString)
        let line = string.substring(with: range)
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            guard self.operationID == ID else {
                return
            }

            guard let tempString = self.highlightr.highlight(with: language, code: line, fastRender: true) else {
                return
            }

            DispatchQueue.main.async {
                guard self.operationID == ID else {
                    return
                }

                //Checks to see if this highlighting is still valid.
                if (range.location + range.length) > self.stringStorage.length {
                    self.highlightDelegate?.didHighlight?(in: range, success: false)
                    return
                }

                if tempString.string != self.stringStorage.attributedSubstring(from: range).string {
                    self.highlightDelegate?.didHighlight?(in: range, success: false)
                    return
                }

                self.beginEditing()
                tempString.enumerateAttributes(in: NSMakeRange(0, tempString.length), options: []) { attrs, locRange, _ in
                    var fixedRange = NSMakeRange(range.location + locRange.location, locRange.length)
                    fixedRange.length = (fixedRange.location + fixedRange.length < string.length) ? fixedRange.length : string.length - fixedRange.location
                    fixedRange.length = (fixedRange.length >= 0) ? fixedRange.length : 0
                    self.stringStorage.setAttributes(attrs, range: fixedRange)
                }
                self.endEditing()
                self.edited(NSTextStorageEditActions.editedAttributes, range: range, changeInLength: 0)
                self.highlightDelegate?.didHighlight?(in: range, success: true)
            }
        }
    }
}
