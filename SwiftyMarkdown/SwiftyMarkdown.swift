//
//  SwiftyMarkdown.swift
//  SwiftyMarkdown
//
//  Created by Simon Fairbairn on 05/03/2016.
//  Copyright © 2016 Voyage Travel Apps. All rights reserved.
//

import UIKit


public protocol FontProperties {
	var fontName : String? { get set }
    var fontSize: CGFloat? { get set }
    var fontWeight: CGFloat? { get set }
    var color : UIColor { get set }
}


/**
A struct defining the styles that can be applied to the parsed Markdown. The `fontName` property is optional, and if it's not set then the `fontName` property of the Body style will be applied.

If that is not set, then the system default will be used.
*/
public struct BasicStyles : FontProperties {
	public var fontName : String? = UIFont.preferredFont(forTextStyle: .body).fontName
    public var fontSize: CGFloat?
    public var fontWeight: CGFloat?
	public var color = UIColor.black
}

enum LineType : Int {
	case h1, h2, h3, h4, h5, h6, body
}

enum LineStyle : Int {
	case none
	case italic
	case bold
	case code
	case link
	
	static func styleFromString(_ string : String ) -> LineStyle {
		if string == "**" || string == "__" {
			return .bold
		} else if string == "*" || string == "_" {
			return .italic
//		} else if string == "`" {
//			return .code
		} else if string == "["  {
			return .link
		} else {
			return .none
		}
	}
}

/// A class that takes a [Markdown](https://daringfireball.net/projects/markdown/) string or file and returns an NSAttributedString with the applied styles. Supports Dynamic Type.
open class SwiftyMarkdown {
	
	/// The styles to apply to any H1 headers found in the Markdown
	open var h1 = BasicStyles()

	/// The styles to apply to any H2 headers found in the Markdown
	open var h2 = BasicStyles()
	
	/// The styles to apply to any H3 headers found in the Markdown
	open var h3 = BasicStyles()
	
	/// The styles to apply to any H4 headers found in the Markdown
	open var h4 = BasicStyles()
	
	/// The styles to apply to any H5 headers found in the Markdown
	open var h5 = BasicStyles()
	
	/// The styles to apply to any H6 headers found in the Markdown
	open var h6 = BasicStyles()
	
	/// The default body styles. These are the base styles and will be used for e.g. headers if no other styles override them.
	open var body = BasicStyles()
	
	/// The styles to apply to any links found in the Markdown
	open var link = BasicStyles()

	/// The styles to apply to any bold text found in the Markdown
	open var bold = BasicStyles()
	
	/// The styles to apply to any italic text found in the Markdown
	open var italic = BasicStyles()
	
	/// The styles to apply to any code blocks or inline code text found in the Markdown
	open var code = BasicStyles()

	
	var currentType : LineType = .body

	
	let string : String
	let instructionSet = CharacterSet(charactersIn: "[\\*_")
	
	/**
	
	- parameter string: A string containing [Markdown](https://daringfireball.net/projects/markdown/) syntax to be converted to an NSAttributedString
	
	- returns: An initialized SwiftyMarkdown object
	*/
	public init(string : String ) {
		self.string = string
	}
	
	/**
	A failable initializer that takes a URL and attempts to read it as a UTF-8 string
	
	- parameter url: The location of the file to read
	
	- returns: An initialized SwiftyMarkdown object, or nil if the string couldn't be read
	*/
	public init?(url : URL ) {
		
		do {
			self.string = try NSString(contentsOf: url, encoding: String.Encoding.utf8.rawValue) as String
			
		} catch {
			self.string = ""
			return nil
		}
	}
	
	/**
	Generates an NSAttributedString from the string or URL passed at initialisation. Custom fonts or styles are applied to the appropriate elements when this method is called.
	
	- returns: An NSAttributedString with the styles applied
	*/
	open func attributedString() -> NSAttributedString {
		let attributedString = NSMutableAttributedString(string: "")
		
		let lines = self.string.components(separatedBy: CharacterSet.newlines)
		
		var lineCount = 0
		
        let headings: [String] = [] //["# ", "## ", "### ", "#### ", "##### ", "###### "]
		
		var skipLine = false
		for theLine in lines {
			lineCount += 1
			if skipLine {
				skipLine = false
				continue
			}
			var line = theLine == "" ? " " : theLine
			for heading in headings {
				
				if let range =  line.range(of: heading) , range.lowerBound == line.startIndex {
					
					let startHeadingString = line.replacingCharacters(in: range, with: "")

					// Remove ending
					let endHeadingString = heading.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
					line = startHeadingString.replacingOccurrences(of: endHeadingString, with: "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
					
					currentType = LineType(rawValue: headings.index(of: heading)!)!

					// We found a heading so break out of the inner loop
					break
				}
			}
			
			// Look for underlined headings
			if lineCount  < lines.count {
				let nextLine = lines[lineCount]
				
				if let range = nextLine.range(of: "=") , range.lowerBound == nextLine.startIndex {
					// Make H1
					currentType = .h1
					// We need to skip the next line
					skipLine = true
				}
				
				if let range = nextLine.range(of: "-") , range.lowerBound == nextLine.startIndex {
					// Make H2
					currentType = .h2
					// We need to skip the next line
					skipLine = true
				}
			}
			
			// If this is not an empty line...
			if line.count > 0 {
				
				// ...start scanning
				let scanner = Scanner(string: line)
				
				// We want to be aware of spaces
				scanner.charactersToBeSkipped = nil
				
				while !scanner.isAtEnd {
					var string : NSString?

					// Get all the characters up to the ones we are interested in
					if scanner.scanUpToCharacters(from: instructionSet, into: &string) {
						
						if let hasString = string as String? {
							let bodyString = attributedStringFromString(hasString, withStyle: .none)
							attributedString.append(bodyString)
							
							let location = scanner.scanLocation
							
							let matchedCharacters = tagFromScanner(scanner).foundCharacters
							// If the next string after the characters is a space, then add it to the final string and continue
							
							let set = NSMutableCharacterSet.whitespace()
							set.formUnion(with: CharacterSet.punctuationCharacters)
							if scanner.scanUpToCharacters(from: set as CharacterSet, into: nil) {
								scanner.scanLocation = location
								attributedString.append(self.attributedStringFromScanner(scanner))

							} else if matchedCharacters == "[" {
								scanner.scanLocation = location
								attributedString.append(self.attributedStringFromScanner(scanner))								
							} else {
								
								let charAtts = attributedStringFromString(matchedCharacters, withStyle: .none)
								attributedString.append(charAtts)
								
							}
						}
					} else {
						attributedString.append(self.attributedStringFromScanner(scanner, atStartOfLine: true))
					}
				}
			}
			
			// Append a new line character to the end of the processed line
//			if lineCount < lines.count {
				attributedString.append(NSAttributedString(string: "\n"))
//			}
			currentType = .body
		}
		
		return attributedString
	}
	
	func attributedStringFromScanner( _ scanner : Scanner, atStartOfLine start : Bool = false) -> NSAttributedString {
		var followingString : NSString?

		let results = self.tagFromScanner(scanner)

		var style = LineStyle.styleFromString(results.foundCharacters)
		
		var attributes = [NSAttributedString.Key: Any]()
		if style == .link {
			
			var linkText : NSString?
			var linkURL : NSString?
            var closingCharacters : NSString?
            let linkTextCharacters = CharacterSet(charactersIn: "]")
			
			scanner.scanUpToCharacters(from: linkTextCharacters, into: &linkText)
			scanner.scanCharacters(from: linkTextCharacters, into: &closingCharacters)

            let currentIndexInt = scanner.scanLocation
            
            if currentIndexInt < string.count {
                let currentIndex = scanner.string.index(scanner.string.startIndex, offsetBy: currentIndexInt)
                let nextIndex = scanner.string.index(scanner.string.startIndex, offsetBy: currentIndexInt + 1)
                let singleCharacterRange = currentIndex..<nextIndex

                if scanner.string[singleCharacterRange] == "(" {
                    let linkURLCharacters = CharacterSet(charactersIn: "()")
                    scanner.scanCharacters(from: linkURLCharacters, into: nil)
                    scanner.scanUpToCharacters(from: linkURLCharacters, into: &linkURL)
                    scanner.scanCharacters(from: linkURLCharacters, into: nil)
                }
            }
			
			if let hasLink = linkText, let hasURL = linkURL {
				followingString = hasLink
				attributes[NSAttributedString.Key.link] = NSURL(string: hasURL as String)
			} else {
                // [text] or <text> with no following (http://...) will be shown with no link style
                var unescapedString: String = ""
                
                unescapedString = results.foundCharacters
                
                if let linkText = linkText {
                    unescapedString = unescapedString + (linkText as String)
                }
                if let closingCharacters = closingCharacters {
                    unescapedString = unescapedString + (closingCharacters as String)
                }
                
                followingString = unescapedString as NSString?
                
				style = .none
			}
		} else {
			scanner.scanUpToCharacters(from: instructionSet, into: &followingString)		
		}
		
		let attributedString = attributedStringFromString(results.escapedCharacters, withStyle: style).mutableCopy() as! NSMutableAttributedString
		if let hasString = followingString as String? {

			let prefix = ( style == .code && start ) ? "\t" : ""
			let attString = attributedStringFromString(prefix + hasString, withStyle: style, attributes: attributes)
			attributedString.append(attString)
		}
		let suffix = self.tagFromScanner(scanner)
		attributedString.append(attributedStringFromString(suffix.escapedCharacters, withStyle: style))
		
		return attributedString
	}
	
	func tagFromScanner( _ scanner : Scanner ) -> (foundCharacters : String, escapedCharacters : String) {
		var matchedCharacters : String = ""
		var tempCharacters : NSString?
		
		// Scan the ones we are interested in
		while scanner.scanCharacters(from: instructionSet, into: &tempCharacters) {
			if let chars = tempCharacters as String? {
				matchedCharacters = matchedCharacters + chars
			}
		}
		var foundCharacters : String = ""
		
		while matchedCharacters.contains("\\") {
			if let hasRange = matchedCharacters.range(of: "\\") {
				
				if matchedCharacters.count > 1 {
					let newRange = hasRange.lowerBound..<matchedCharacters.index(hasRange.upperBound, offsetBy: 1)
					foundCharacters = foundCharacters + matchedCharacters[newRange].replacingOccurrences(of: "\\", with: "")
					
					matchedCharacters.removeSubrange(newRange)
				} else {
					foundCharacters = matchedCharacters
					break
				}
			}
			
		}
		
		
		return (matchedCharacters, foundCharacters)
	}
	
	
	// Make H1
	
	func attributedStringFromString(_ string : String, withStyle style : LineStyle, attributes : [NSAttributedString.Key: Any] = [:] ) -> NSAttributedString {
		let textStyle : UIFont.TextStyle
		var fontName : String?
        var fontSize: CGFloat?
        var attributes = attributes

		// What type are we and is there a font name and/or size set?
		
		switch currentType {
		case .h1:
			fontName = h1.fontName
            fontSize = h1.fontSize
			if #available(iOS 9, *) {
				textStyle = UIFont.TextStyle.title1
			} else {
				textStyle = UIFont.TextStyle.headline
			}
			attributes[NSAttributedString.Key.foregroundColor] = h1.color
		case .h2:
			fontName = h2.fontName
            fontSize = h2.fontSize
			if #available(iOS 9, *) {
				textStyle = UIFont.TextStyle.title2
			} else {
				textStyle = UIFont.TextStyle.headline
			}
			attributes[NSAttributedString.Key.foregroundColor] = h2.color
		case .h3:
			fontName = h3.fontName
            fontSize = h3.fontSize
			if #available(iOS 9, *) {
				textStyle = UIFont.TextStyle.title2
			} else {
				textStyle = UIFont.TextStyle.subheadline
			}
			attributes[NSAttributedString.Key.foregroundColor] = h3.color
		case .h4:
			fontName = h4.fontName
            fontSize = h4.fontSize
			textStyle = UIFont.TextStyle.headline
			attributes[NSAttributedString.Key.foregroundColor] = h4.color
		case .h5:
			fontName = h5.fontName
            fontSize = h5.fontSize
			textStyle = UIFont.TextStyle.subheadline
			attributes[NSAttributedString.Key.foregroundColor] = h5.color
		case .h6:
			fontName = h6.fontName
            fontSize = h6.fontSize
			textStyle = UIFont.TextStyle.footnote
			attributes[NSAttributedString.Key.foregroundColor] = h6.color
		default:
			fontName = body.fontName
            fontSize = body.fontSize
			textStyle = UIFont.TextStyle.body
			attributes[NSAttributedString.Key.foregroundColor] = body.color
			break
		}
		
		// Check for code
		
		if style == .code {
			fontName = code.fontName
            fontSize = code.fontSize
			attributes[NSAttributedString.Key.foregroundColor] = code.color
		}
		
		if style == .link {
			fontName = link.fontName
            fontSize = link.fontSize
			attributes[NSAttributedString.Key.foregroundColor] = link.color
		}
		
		// Fallback to body name
        if let _ = fontName {
            
        } else {
            fontName = body.fontName
        }
        
        // Fallback to body size if available, although this too might be left to nil.
        if fontSize == nil {
            fontSize = body.fontSize
        }
		
		let font = UIFont.preferredFont(forTextStyle: textStyle)
		let styleDescriptor = font.fontDescriptor
        
        var finalFont : UIFont
        var finalSize: CGFloat

        // If the fontSize was set above, use it. Otherwise, use the size provied by the UIFontDescriptor.
        if let fontSize = fontSize {
            finalSize = fontSize
        }
        else {
            let styleSize = styleDescriptor.fontAttributes[UIFontDescriptor.AttributeName.size] as? CGFloat ?? CGFloat(14)
            finalSize = styleSize
        }
		
		if let finalFontName = fontName, let font = UIFont(name: finalFontName, size: finalSize) {
			finalFont = font
		} else {
			finalFont = UIFont.preferredFont(forTextStyle:  textStyle)
		}
		
		let finalFontDescriptor = finalFont.fontDescriptor
		if style == .italic {
			if let italicDescriptor = finalFontDescriptor.withSymbolicTraits(.traitItalic) {
				finalFont = UIFont(descriptor: italicDescriptor, size: finalSize)
			}
		}
		if style == .bold {
            if let boldDescriptor = finalFontDescriptor.withSymbolicTraits(.traitBold) {
                finalFont = UIFont(descriptor: boldDescriptor, size: finalSize)
            }
            if #available(iOS 8.2, *) {
                if let fontWeight = bold.fontWeight {
                    finalFont = UIFont.systemFont(ofSize: finalSize, weight: UIFont.Weight(rawValue: fontWeight))
                }
            }
        }
        
		attributes[NSAttributedString.Key.font] = finalFont
		
		return NSAttributedString(string: string, attributes: attributes)
	}
}
