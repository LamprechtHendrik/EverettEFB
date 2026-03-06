import Foundation

enum TimeEntryHelper {
    static func digitsOnly(_ text: String) -> String {
        text.filter(\.isNumber)
    }

    static func clampedInput(_ text: String) -> String {
        String(digitsOnly(text).prefix(4))
    }

    /// Accepts hmm or hhmm, e.g. 700 -> 07:00, 2300 -> 23:00
    static func parseMinutes(_ input: String) -> Int? {
        let digits = digitsOnly(input)

        guard digits.count == 3 || digits.count == 4 else { return nil }

        let hour: Int
        let minute: Int

        if digits.count == 3 {
            hour = Int(digits.prefix(1)) ?? -1
            minute = Int(digits.suffix(2)) ?? -1
        } else {
            hour = Int(digits.prefix(2)) ?? -1
            minute = Int(digits.suffix(2)) ?? -1
        }

        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour * 60) + minute
    }

    static func normalizedDisplay(_ input: String) -> String? {
        guard let mins = parseMinutes(input) else { return nil }
        return String(format: "%02d:%02d", mins / 60, mins % 60)
    }

    static func display(from date: Date?) -> String {
        guard let date else { return "" }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    static func date(from input: String, on baseDate: Date) -> Date? {
        guard let mins = parseMinutes(input) else { return nil }
        let cal = Calendar.current
        let hour = mins / 60
        let minute = mins % 60
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
    }

    /// Handles overnight rollover.
    /// Example: 23:00 -> 02:00 = 03:00
    static func durationMinutes(from start: String, to end: String) -> Int? {
        guard let startMins = parseMinutes(start), let endMins = parseMinutes(end) else { return nil }

        if endMins >= startMins {
            return endMins - startMins
        } else {
            return (endMins + 24 * 60) - startMins
        }
    }

    static func durationMinutes(from start: Date?, to end: Date?) -> Int? {
        guard let start, let end else { return nil }

        let cal = Calendar.current
        let startMins = cal.component(.hour, from: start) * 60 + cal.component(.minute, from: start)
        let endMins = cal.component(.hour, from: end) * 60 + cal.component(.minute, from: end)

        if endMins >= startMins {
            return endMins - startMins
        } else {
            return (endMins + 24 * 60) - startMins
        }
    }

    static func formattedDuration(_ mins: Int?) -> String {
        guard let mins else { return "-" }
        return String(format: "%02d:%02d", mins / 60, mins % 60)
    }
}
