import Foundation

enum EFBDateFormatter {

    /// Aviation standard date format
    /// Example: 06-Apr-26
    static let aviationDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Full report folder date if ever needed
    /// Example: 06-Apr-2026
    static let aviationLong: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

extension Date {

    /// Returns 06-Apr-26
    var efbDate: String {
        EFBDateFormatter.aviationDate.string(from: self)
    }

    /// Returns 06-Apr-2026
    var efbLongDate: String {
        EFBDateFormatter.aviationLong.string(from: self)
    }
}
