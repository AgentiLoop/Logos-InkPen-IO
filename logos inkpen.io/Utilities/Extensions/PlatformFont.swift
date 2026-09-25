import Foundation

#if os(macOS)
import AppKit

public typealias PlatformFont = NSFont
#elseif os(iOS)
import UIKit

public typealias PlatformFont = UIFont
#endif
