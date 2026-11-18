//
//  AboutInfoPreview.swift
//  MaynardGolf
//

#if DEBUG
import Foundation

extension AboutInfo {
    /// A fixed version and device for previews (TS-VS-05).
    static let preview = AboutInfo(info: ["CFBundleShortVersionString": "1.2", "CFBundleVersion": "211"],
                                   device: "iPhone18,1", system: "iOS 27.1")
}
#endif
