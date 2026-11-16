//
//  Contrast.swift
//  MaynardUI
//

import UIKit

/// WCAG 2 contrast ratios (DS-CL-02, DS-DM-04), so the readable pairings are checked from the token
/// values themselves rather than trusted.
public enum Contrast {
    /// Relative luminance of an sRGB color, 0 (black) … 1 (white).
    public static func luminance(red: Double, green: Double, blue: Double) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// The contrast ratio between two colors, 1 … 21. Translucent colors are composited over `backdrop`
    /// first (the surface they sit on).
    public static func ratio(_ a: UIColor, _ b: UIColor, over backdrop: UIColor = .white) -> Double {
        let la = luminance(of: composite(a, over: backdrop))
        let lb = luminance(of: composite(b, over: backdrop))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// The color's sRGB components after laying it over `backdrop` (alpha blending).
    public static func composite(_ color: UIColor, over backdrop: UIColor) -> (red: Double, green: Double, blue: Double) {
        let top = components(color), bottom = components(backdrop)
        let a = top.alpha
        return (top.red * a + bottom.red * (1 - a), top.green * a + bottom.green * (1 - a), top.blue * a + bottom.blue * (1 - a))
    }

    static func luminance(of rgb: (red: Double, green: Double, blue: Double)) -> Double {
        luminance(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// sRGB components of a color (UIKit returns extended sRGB, which matches the sRGB color sets).
    public static func components(_ color: UIColor) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    /// "#RRGGBB" for a color, rounding each channel (for tests and the catalog).
    public static func hex(_ color: UIColor) -> String {
        let c = components(color)
        func byte(_ v: Double) -> Int { Int((v * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(c.red), byte(c.green), byte(c.blue))
    }
}
