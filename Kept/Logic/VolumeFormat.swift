import Foundation

/// Drink volumes are stored in millilitres and shown in the user's own units.
enum VolumeFormat {
    static let millilitersPerFluidOunce = 29.5735

    static func usesFluidOunces(_ locale: Locale = .current) -> Bool {
        locale.measurementSystem == .us
    }

    static func string(milliliters: Int, locale: Locale = .current) -> String {
        if usesFluidOunces(locale) {
            let ounces = (Double(milliliters) / millilitersPerFluidOunce).rounded()
            return "\(Int(ounces)) fl oz"
        }
        if milliliters >= 1000 {
            let liters = Double(milliliters) / 1000
            return liters.formatted(.number.precision(.fractionLength(0...2)).locale(locale)) + " L"
        }
        return "\(milliliters) ml"
    }

    /// Glass sizes offered in Settings.
    static func glassOptions(_ locale: Locale = .current) -> [Int] {
        usesFluidOunces(locale) ? [237, 296, 355, 473, 591] : [200, 250, 300, 330, 400, 500]
    }

    /// One-tap volumes in the drink editor.
    static func drinkOptions(_ locale: Locale = .current) -> [Int] {
        usesFluidOunces(locale) ? [118, 237, 355, 473, 591, 710] : [150, 250, 330, 500, 750, 1000]
    }

    static func step(_ locale: Locale = .current) -> Int {
        usesFluidOunces(locale) ? 30 : 50
    }
}
