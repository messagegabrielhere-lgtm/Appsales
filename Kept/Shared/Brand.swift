import Foundation

/// The product name people see.
///
/// Internal identifiers still say "Kept" and must stay that way: the bundle ID, the App Group,
/// the module name, the widget `kind`, and the Application Support folder that holds 1.0 data.
/// Renaming any of them would orphan existing users' data or remove widgets they already placed.
enum Brand {
    static let name = "Fuelprint"
    /// The company that publishes the app.
    static let company = "Pioneer I LLC"
}
