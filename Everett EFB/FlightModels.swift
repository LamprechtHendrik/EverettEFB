import Foundation
import SwiftData

@Model
final class Flight {
    var createdAt: Date
    var reportNumber: String
    var aircraftReg: String
    var pic: String
    var sic: String
    var cabinCrew: String
    var client: String
    var isClosed: Bool

    @Relationship(deleteRule: .cascade)
    var legs: [FlightLeg]

    @Relationship(deleteRule: .cascade)
    var daySigns: [FlightDaySign]

    init(
        createdAt: Date = Date(),
        reportNumber: String = "",
        aircraftReg: String = "",
        pic: String = "",
        sic: String = "",
        cabinCrew: String = "",
        client: String = "",
        isClosed: Bool = false,
        legs: [FlightLeg] = [],
        daySigns: [FlightDaySign] = []
    ) {
        self.createdAt = createdAt
        self.reportNumber = reportNumber
        self.aircraftReg = aircraftReg
        self.pic = pic
        self.sic = sic
        self.cabinCrew = cabinCrew
        self.client = client
        self.isClosed = isClosed
        self.legs = legs
        self.daySigns = daySigns
    }

    var displayDate: Date {
        legs.sorted(by: { $0.sequence < $1.sequence }).first?.date ?? createdAt
    }

    func daySign(for date: Date) -> FlightDaySign? {
        let day = Calendar.current.startOfDay(for: date)
        return daySigns.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    @discardableResult
    func ensureDaySign(for date: Date) -> FlightDaySign {
        if let existing = daySign(for: date) {
            return existing
        }

        let newDay = FlightDaySign(date: Calendar.current.startOfDay(for: date))
        daySigns.append(newDay)
        return newDay
    }

    func legs(on day: Date) -> [FlightLeg] {
        let start = Calendar.current.startOfDay(for: day)
        return legs
            .filter { Calendar.current.isDate($0.date, inSameDayAs: start) }
            .sorted { $0.sequence < $1.sequence }
    }

    func firstLeg(on day: Date) -> FlightLeg? {
        legs(on: day).first
    }

    func lastLeg(on day: Date) -> FlightLeg? {
        legs(on: day).last
    }

    func isFirstLegOfDay(_ leg: FlightLeg) -> Bool {
        guard let first = firstLeg(on: leg.date) else { return false }
        return first.persistentModelID == leg.persistentModelID
    }

    func isLastLegOfDay(_ leg: FlightLeg) -> Bool {
        guard let last = lastLeg(on: leg.date) else { return false }
        return last.persistentModelID == leg.persistentModelID
    }

    var allLegsFinalized: Bool {
        !legs.isEmpty && legs.allSatisfy { $0.isFinalized }
    }

    var allDaysSigned: Bool {
        !daySigns.isEmpty && daySigns.allSatisfy { $0.allSignedOn && $0.allSignedOff }
    }

    var canFinalizeReport: Bool {
        !isClosed &&
        !legs.isEmpty &&
        allLegsFinalized &&
        allDaysSigned
    }
}

@Model
final class FlightLeg {
    var sequence: Int
    var date: Date
    var departureTime: Date
    var callSign: String
    var departure: String
    var destination: String

    var blockOff: Date?
    var blockOn: Date?
    var takeOff: Date?
    var landing: Date?

    var depFuel: Int?
    var ldgFuel: Int?
    var uplift: Int?
    var fuelInvoice: String

    var pax: Int?
    var cargo: Int?
    var loc: String

    var isFinalized: Bool

    @Relationship(deleteRule: .cascade)
    var documents: [LegDocument]

    init(
        sequence: Int = 1,
        date: Date = Date(),
        departureTime: Date = Date(),
        callSign: String = "",
        departure: String = "",
        destination: String = "",
        blockOff: Date? = nil,
        blockOn: Date? = nil,
        takeOff: Date? = nil,
        landing: Date? = nil,
        depFuel: Int? = nil,
        ldgFuel: Int? = nil,
        uplift: Int? = nil,
        fuelInvoice: String = "",
        pax: Int? = nil,
        cargo: Int? = nil,
        loc: String = "",
        isFinalized: Bool = false,
        documents: [LegDocument] = []
    ) {
        self.sequence = sequence
        self.date = date
        self.departureTime = departureTime
        self.callSign = callSign
        self.departure = departure
        self.destination = destination
        self.blockOff = blockOff
        self.blockOn = blockOn
        self.takeOff = takeOff
        self.landing = landing
        self.depFuel = depFuel
        self.ldgFuel = ldgFuel
        self.uplift = uplift
        self.fuelInvoice = fuelInvoice
        self.pax = pax
        self.cargo = cargo
        self.loc = loc
        self.isFinalized = isFinalized
        self.documents = documents
    }

    var blockTimeMinutes: Int? {
        TimeEntryHelper.durationMinutes(from: blockOff, to: blockOn)
    }

    var flightTimeMinutes: Int? {
        TimeEntryHelper.durationMinutes(from: takeOff, to: landing)
    }

    var fuelUsed: Int? {
        guard let depFuel, let ldgFuel else { return nil }
        let used = depFuel - ldgFuel
        return used >= 0 ? used : nil
    }

    var isCompleted: Bool {
        blockOff != nil &&
        blockOn != nil &&
        takeOff != nil &&
        landing != nil
    }
}

enum LegDocumentType: String, CaseIterable, Identifiable, Codable {
    case paxManifest = "PAX Manifest"
    case genDec = "GENDEC"
    case loadSheet = "Load Sheet"
    case fuelSlip = "Fuel Slip"
    case landingPermit = "Landing Permit"
    case handlingInvoice = "Handling Invoice"
    case customsForm = "Customs Form"
    case other = "Other"

    var id: String { rawValue }
}

@Model
final class LegDocument {
    var typeRaw: String
    var fileName: String
    var createdAt: Date

    init(type: LegDocumentType, fileName: String = "", createdAt: Date = Date()) {
        self.typeRaw = type.rawValue
        self.fileName = fileName
        self.createdAt = createdAt
    }

    var type: LegDocumentType {
        LegDocumentType(rawValue: typeRaw) ?? .other
    }
}

@Model
final class FlightDaySign {
    var date: Date

    var signOnTime: String
    var signOffTime: String

    var picSignOnName: String
    var sicSignOnName: String
    var cabinSignOnName: String

    var picSignOnDrawing: Data?
    var sicSignOnDrawing: Data?
    var cabinSignOnDrawing: Data?

    var picSignOffName: String
    var sicSignOffName: String
    var cabinSignOffName: String

    var picSignOffDrawing: Data?
    var sicSignOffDrawing: Data?
    var cabinSignOffDrawing: Data?

    init(
        date: Date = Date(),
        signOnTime: String = "",
        signOffTime: String = "",
        picSignOnName: String = "",
        sicSignOnName: String = "",
        cabinSignOnName: String = "",
        picSignOnDrawing: Data? = nil,
        sicSignOnDrawing: Data? = nil,
        cabinSignOnDrawing: Data? = nil,
        picSignOffName: String = "",
        sicSignOffName: String = "",
        cabinSignOffName: String = "",
        picSignOffDrawing: Data? = nil,
        sicSignOffDrawing: Data? = nil,
        cabinSignOffDrawing: Data? = nil
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.signOnTime = signOnTime
        self.signOffTime = signOffTime
        self.picSignOnName = picSignOnName
        self.sicSignOnName = sicSignOnName
        self.cabinSignOnName = cabinSignOnName
        self.picSignOnDrawing = picSignOnDrawing
        self.sicSignOnDrawing = sicSignOnDrawing
        self.cabinSignOnDrawing = cabinSignOnDrawing
        self.picSignOffName = picSignOffName
        self.sicSignOffName = sicSignOffName
        self.cabinSignOffName = cabinSignOffName
        self.picSignOffDrawing = picSignOffDrawing
        self.sicSignOffDrawing = sicSignOffDrawing
        self.cabinSignOffDrawing = cabinSignOffDrawing
    }

    var allSignedOn: Bool {
        !signOnTime.isEmpty &&
        picSignOnDrawing != nil &&
        sicSignOnDrawing != nil &&
        cabinSignOnDrawing != nil
    }

    var allSignedOff: Bool {
        !signOffTime.isEmpty &&
        picSignOffDrawing != nil &&
        sicSignOffDrawing != nil &&
        cabinSignOffDrawing != nil
    }
}
