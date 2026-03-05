import Foundation
import SwiftUI

// MARK: - Pure logic status (no UI types inside)
enum ComplianceStatus: Int, Comparable, Sendable {
    case na = -1
    case ok = 0
    case caution = 1
    case expired = 2

    static func < (lhs: ComplianceStatus, rhs: ComplianceStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .ok: return "OK"
        case .caution: return "CAUTION"
        case .expired: return "EXPIRED"
        case .na: return "N/A"
        }
    }
}

struct Compliance {
    static func status(forExpiry expiry: Date?, asOf: Date = Date(), cautionDays: Int = 30) -> ComplianceStatus {
        guard let expiry else { return .na }
        if expiry < asOf.startOfDay { return .expired }

        let cautionDate = Calendar.current.date(byAdding: .day, value: cautionDays, to: asOf.startOfDay) ?? asOf
        if expiry <= cautionDate { return .caution }

        return .ok
    }

    static func worst(_ statuses: [ComplianceStatus]) -> ComplianceStatus {
        let nonNA = statuses.filter { $0 != .na }
        guard !nonNA.isEmpty else { return .na }
        return nonNA.max() ?? .na
    }

    static func status(forBools bools: [Bool]) -> ComplianceStatus {
        bools.contains(false) ? .caution : .ok
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

// MARK: - UI-only mapping (main-actor)
@MainActor
extension ComplianceStatus {
    var symbol: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .expired: return "xmark.octagon.fill"
        case .na: return "minus.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ok: return .green
        case .caution: return .orange
        case .expired: return .red
        case .na: return .gray
        }
    }
}

// MARK: - Badge view
struct StatusBadge: View {
    let status: ComplianceStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.symbol)
            Text(status.label)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .foregroundStyle(status.tint)
        .background(status.tint.opacity(0.15))
        .clipShape(Capsule())
    }
}
