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
    var flightTypeRaw: String
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
        flightTypeRaw: String = FlightType.nonScheduled.rawValue,
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
        self.flightTypeRaw = flightTypeRaw
        self.isClosed = isClosed
        self.legs = legs
        self.daySigns = daySigns
    }

    var flightType: FlightType {
        get { FlightType(rawValue: flightTypeRaw) ?? .nonScheduled }
        set { flightTypeRaw = newValue.rawValue }
    }

    func documentRequirements(for leg: FlightLeg) -> [LegDocumentRequirement] {
        var requirements: [LegDocumentRequirement] = [
            .init(
                type: .briefingPack,
                acquisitionMethod: .files,
                isRequired: true,
                note: "Operational flight briefing for the sector."
            ),
            .init(
                type: .navLog,
                acquisitionMethod: .foreFlight,
                isRequired: true,
                note: "Imported from ForeFlight when used for navigation planning."
            ),
            .init(
                type: .apgPerformance,
                acquisitionMethod: .apg,
                isRequired: true,
                note: "APG performance output for the sector."
            ),
            .init(
                type: .fuelSlip,
                acquisitionMethod: .scan,
                isRequired: false,
                note: "Scan when fuel was uplifted for the sector."
            ),
            .init(
                type: .other,
                acquisitionMethod: .files,
                isRequired: false,
                note: "Any additional sector support document the crew wants to attach."
            )
        ]

        switch flightType {
        case .maintenance, .ferry:
            requirements.append(
                .init(
                    type: .technicalRelease,
                    acquisitionMethod: .scan,
                    isRequired: false,
                    note: "Use when maintenance or technical paperwork applies to the sector."
                )
            )

        case .training:
            requirements.append(
                .init(
                    type: .trainingForm,
                    acquisitionMethod: .files,
                    isRequired: false,
                    note: "Use for training-specific paperwork or instructor forms."
                )
            )

        case .mediVac:
            requirements.append(
                .init(
                    type: .patientManifest,
                    acquisitionMethod: .scan,
                    isRequired: false,
                    note: "Use when medical passenger paperwork or patient manifest applies."
                )
            )
            requirements.append(
                .init(
                    type: .genDec,
                    acquisitionMethod: .files,
                    isRequired: false,
                    note: "Use when required by station or authority."
                )
            )

        case .scheduled, .nonScheduled:
            requirements.append(
                .init(
                    type: .paxManifest,
                    acquisitionMethod: .files,
                    isRequired: true,
                    note: "Passenger manifest for the sector."
                )
            )
            requirements.append(
                .init(
                    type: .loadSheet,
                    acquisitionMethod: .files,
                    isRequired: true,
                    note: "Load sheet for the sector."
                )
            )
            requirements.append(
                .init(
                    type: .genDec,
                    acquisitionMethod: .files,
                    isRequired: false,
                    note: "Use when required by station or authority."
                )
            )
        }

        if !cabinCrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requirements.append(
                .init(
                    type: .cabinChecklist,
                    acquisitionMethod: .files,
                    isRequired: false,
                    note: "Cabin-related checklist or support document."
                )
            )
        }

        return requirements
    }

    func missingRequiredDocumentTypes(for leg: FlightLeg) -> [LegDocumentType] {
        let requiredTypes = Set(
            documentRequirements(for: leg)
                .filter { $0.isRequired }
                .map { $0.type }
        )
        let uploadedTypes = Set(leg.documents.map { $0.type })
        return requiredTypes.filter { !uploadedTypes.contains($0) }.sorted { $0.rawValue < $1.rawValue }
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
        !daySigns.isEmpty && daySigns.allSatisfy { day in
            let requiresCabin = !cabinCrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            let signedOn = !day.signOnTime.isEmpty &&
                day.picSignOnDrawing != nil &&
                day.sicSignOnDrawing != nil &&
                (!requiresCabin || day.cabinSignOnDrawing != nil)

            let signedOff = !day.signOffTime.isEmpty &&
                day.picSignOffDrawing != nil &&
                day.sicSignOffDrawing != nil &&
                (!requiresCabin || day.cabinSignOffDrawing != nil)

            return signedOn && signedOff
        }
    }

    var canFinalizeReport: Bool {
        !isClosed &&
        !legs.isEmpty &&
        allLegsFinalized &&
        allDaysSigned
    }
}

enum FlightType: String, CaseIterable, Identifiable, Codable {
    case training = "Training"
    case maintenance = "Maintenance"
    case ferry = "Ferry"
    case mediVac = "MediVac"
    case scheduled = "Scheduled"
    case nonScheduled = "Non Scheduled"

    var id: String { rawValue }
}

enum DocumentAcquisitionMethod: String, CaseIterable, Identifiable, Codable {
    case scan = "Scan"
    case files = "Files"
    case foreFlight = "ForeFlight"
    case apg = "APG"
    case manual = "Manual"

    var id: String { rawValue }
}

struct LegDocumentRequirement: Identifiable, Hashable, Codable {
    var id: String { "\(type.rawValue)-\(acquisitionMethod.rawValue)-\(isRequired ? "req" : "opt")" }

    let type: LegDocumentType
    let acquisitionMethod: DocumentAcquisitionMethod
    let isRequired: Bool
    let note: String
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

    @Relationship(deleteRule: .cascade, inverse: \LegDocument.leg)
    var documents: [LegDocument]

    var crewNote: String

    @Relationship(deleteRule: .cascade, inverse: \LegDelayEntry.leg)
    var delays: [LegDelayEntry]

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
        documents: [LegDocument] = [],
        crewNote: String = "",
        delays: [LegDelayEntry] = []
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
        self.crewNote = crewNote
        self.delays = delays
    }

    func addDelay(from definition: IATADelayCodeDefinition, comment: String) {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = LegDelayEntry(
            leg: self,
            delayNumber: definition.delayNumber,
            code: definition.code,
            descriptionText: definition.descriptionText,
            noteGuidance: definition.noteGuidance,
            crewComment: trimmed
        )
        delays.append(entry)
    }

    func removeDelay(_ entry: LegDelayEntry) {
        delays.removeAll { $0.id == entry.id }
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

@Model
final class LegDelayEntry {
    var id: UUID
    var delayNumber: Int
    var code: String
    var descriptionText: String
    var noteGuidance: String
    var crewComment: String
    var createdAt: Date

    var leg: FlightLeg?

    init(
        id: UUID = UUID(),
        leg: FlightLeg? = nil,
        delayNumber: Int,
        code: String,
        descriptionText: String,
        noteGuidance: String = "",
        crewComment: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.leg = leg
        self.delayNumber = delayNumber
        self.code = code
        self.descriptionText = descriptionText
        self.noteGuidance = noteGuidance
        self.crewComment = crewComment
        self.createdAt = createdAt
    }
}

enum SplitDutyStatus: String, CaseIterable, Identifiable, Codable {
    case notAsked = "Not Asked"
    case yes = "Yes"
    case no = "No"
    case notApplicable = "N/A"

    var id: String { rawValue }
}

@Model
final class FlightDaySign {
    var date: Date

    var signOnTime: String
    var signOffTime: String

    var splitDutyStatusRaw: String
    var intermediateSignOffTime: String
    var intermediateSignOnTime: String

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
        splitDutyStatusRaw: String = SplitDutyStatus.notAsked.rawValue,
        intermediateSignOffTime: String = "",
        intermediateSignOnTime: String = "",
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
        self.splitDutyStatusRaw = splitDutyStatusRaw
        self.intermediateSignOffTime = intermediateSignOffTime
        self.intermediateSignOnTime = intermediateSignOnTime
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

    var splitDutyStatus: SplitDutyStatus {
        get { SplitDutyStatus(rawValue: splitDutyStatusRaw) ?? .notAsked }
        set { splitDutyStatusRaw = newValue.rawValue }
    }

    var requiresCabinCrew: Bool {
        let signOnName = cabinSignOnName.trimmingCharacters(in: .whitespacesAndNewlines)
        let signOffName = cabinSignOffName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = !signOnName.isEmpty ? signOnName : signOffName

        guard !combined.isEmpty else { return false }

        let normalized = combined.lowercased()
        return normalized != "n/a" && normalized != "na" && normalized != "-"
    }

    var allSignedOn: Bool {
        !signOnTime.isEmpty &&
        picSignOnDrawing != nil &&
        sicSignOnDrawing != nil &&
        (!requiresCabinCrew || cabinSignOnDrawing != nil)
    }

    var allSignedOff: Bool {
        !signOffTime.isEmpty &&
        picSignOffDrawing != nil &&
        sicSignOffDrawing != nil &&
        (!requiresCabinCrew || cabinSignOffDrawing != nil)
    }

    var totalSplitDutyMinutes: Int? {
        switch splitDutyStatus {
        case .yes:
            let off = intermediateSignOffTime.trimmingCharacters(in: .whitespacesAndNewlines)
            let on = intermediateSignOnTime.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !off.isEmpty, !on.isEmpty else { return nil }
            return TimeEntryHelper.durationMinutes(from: off, to: on)
        case .no, .notApplicable, .notAsked:
            return nil
        }
    }

    var intermediateSignOffDisplay: String {
        switch splitDutyStatus {
        case .yes:
            let value = intermediateSignOffTime.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? "-" : value
        case .no, .notApplicable:
            return "N/A"
        case .notAsked:
            return "-"
        }
    }

    var intermediateSignOnDisplay: String {
        switch splitDutyStatus {
        case .yes:
            let value = intermediateSignOnTime.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? "-" : value
        case .no, .notApplicable:
            return "N/A"
        case .notAsked:
            return "-"
        }
    }

    var totalSplitDutyDisplay: String {
        switch splitDutyStatus {
        case .yes:
            guard let minutes = totalSplitDutyMinutes else { return "-" }
            return TimeEntryHelper.formattedDuration(minutes)
        case .no, .notApplicable:
            return "N/A"
        case .notAsked:
            return "-"
        }
    }
}

struct IATADelayCodeDefinition: Identifiable, Hashable {
    var id: String { "\(delayNumber)-\(code)" }

    let category: String
    let delayNumber: Int
    let code: String
    let descriptionText: String
    let noteGuidance: String
}

enum IATADelayCodeDatabase {
    static let all: [IATADelayCodeDefinition] = [
        .init(category: "OTHERS", delayNumber: 0, code: "05", descriptionText: "AIRLINE INTERNAL CODES.", noteGuidance: ""),
        .init(category: "OTHERS", delayNumber: 6, code: "OA", descriptionText: "NO GATE/STAND AVAILABILITY DUE TO OWN AIRLINE ACTIVITY.", noteGuidance: ""),
        .init(category: "OTHERS", delayNumber: 9, code: "SG", descriptionText: "SCHEDULED GROUND TIME LESS THAN DECLARED MINIMUM GROUND TIME.", noteGuidance: ""),
        .init(category: "PASSENGER AND BAGGAGE", delayNumber: 11, code: "PD", descriptionText: "LATE CHECK-IN.", noteGuidance: "Acceptance after deadline."),
        .init(category: "PASSENGER AND BAGGAGE", delayNumber: 12, code: "PL", descriptionText: "LATE CHECK-IN.", noteGuidance: "Congestions in check-in area."),
        .init(category: "PASSENGER AND BAGGAGE", delayNumber: 13, code: "PE", descriptionText: "CHECK-IN ERROR.", noteGuidance: "Passenger and baggage."),
        .init(category: "PASSENGER AND BAGGAGE", delayNumber: 14, code: "PO", descriptionText: "OVERSALES.", noteGuidance: "Booking errors."),
        .init(category: "PASSENGER AND BAGGAGE", delayNumber: 15, code: "PH", descriptionText: "BOARDING.", noteGuidance: "Discrepancies and paging, missing checked-in passenger."),
        .init(category: "PASSENGER AND BAGGAGE", delayNumber: 16, code: "PS", descriptionText: "COMMERCIAL PUBLICITY/PASSENGER CONVENIENCE.", noteGuidance: "VIP, press, ground meals and missing personal items."),
        .init(category: "PASSENGER AND BAGGAGE", delayNumber: 17, code: "PC", descriptionText: "CATERING ORDER.", noteGuidance: "Late or incorrect order given to supplier."),
        .init(category: "PASSENGER AND BAGGAGE", delayNumber: 18, code: "PB", descriptionText: "BAGGAGE PROCESSING.", noteGuidance: "Sorting etc."),
        .init(category: "PASSENGER AND BAGGAGE", delayNumber: 19, code: "PW", descriptionText: "REDUCED MOBILITY.", noteGuidance: "Boarding / deboarding of passengers with reduced mobility."),
        .init(category: "CARGO AND MAIL", delayNumber: 21, code: "CD", descriptionText: "DOCUMENTATION.", noteGuidance: "Errors, etc."),
        .init(category: "CARGO AND MAIL", delayNumber: 22, code: "CP", descriptionText: "LATE POSITIONING.", noteGuidance: ""),
        .init(category: "CARGO AND MAIL", delayNumber: 23, code: "CC", descriptionText: "LATE ACCEPTANCE.", noteGuidance: ""),
        .init(category: "CARGO AND MAIL", delayNumber: 24, code: "CI", descriptionText: "INADEQUATE PACKING.", noteGuidance: ""),
        .init(category: "CARGO AND MAIL", delayNumber: 25, code: "CO", descriptionText: "OVERSALES.", noteGuidance: "Booking errors."),
        .init(category: "CARGO AND MAIL", delayNumber: 26, code: "CU", descriptionText: "LATE PREPARATION IN WAREHOUSE.", noteGuidance: ""),
        .init(category: "CARGO AND MAIL", delayNumber: 27, code: "CE", descriptionText: "DOCUMENTATION, PACKING.", noteGuidance: "Etc. (mail only)."),
        .init(category: "CARGO AND MAIL", delayNumber: 28, code: "CL", descriptionText: "LATE POSITIONING.", noteGuidance: "(mail only)."),
        .init(category: "CARGO AND MAIL", delayNumber: 29, code: "CA", descriptionText: "LATE ACCEPTANCE.", noteGuidance: "(mail only)."),
        .init(category: "AIRCRAFT RAMP HANDLING", delayNumber: 31, code: "GD", descriptionText: "AIRCRAFT DOCUMENTATION LATE/INACCURATE.", noteGuidance: "Weight and balance, general declaration, pax manifest, etc."),
        .init(category: "AIRCRAFT RAMP HANDLING", delayNumber: 32, code: "GL", descriptionText: "LOADING / UNLOADING.", noteGuidance: "Bulky, special load, cabin load, lack of loading staff."),
        .init(category: "AIRCRAFT RAMP HANDLING", delayNumber: 33, code: "GE", descriptionText: "LOADING EQUIPMENT.", noteGuidance: "Lack of or breakdown, e.g. container pallet loader, lack of staff."),
        .init(category: "AIRCRAFT RAMP HANDLING", delayNumber: 34, code: "GS", descriptionText: "SERVICING EQUIPMENT.", noteGuidance: "Lack of or breakdown, lack of staff, e.g. steps."),
        .init(category: "AIRCRAFT RAMP HANDLING", delayNumber: 35, code: "GC", descriptionText: "AIRCRAFT CLEANING.", noteGuidance: ""),
        .init(category: "AIRCRAFT RAMP HANDLING", delayNumber: 36, code: "GF", descriptionText: "FUELLING / DEFUELLING.", noteGuidance: "Fuel supplier."),
        .init(category: "AIRCRAFT RAMP HANDLING", delayNumber: 37, code: "GB", descriptionText: "CATERING.", noteGuidance: "Late delivery or loading."),
        .init(category: "AIRCRAFT RAMP HANDLING", delayNumber: 38, code: "GU", descriptionText: "ULD.", noteGuidance: "Lack of or serviceability."),
        .init(category: "AIRCRAFT RAMP HANDLING", delayNumber: 39, code: "GT", descriptionText: "TECHNICAL EQUIPMENT.", noteGuidance: "Lack of or breakdown, lack of staff, e.g. pushback."),
        .init(category: "TECHNICAL AND AIRCRAFT EQUIPMENT", delayNumber: 41, code: "TD", descriptionText: "AIRCRAFT DEFECTS.", noteGuidance: ""),
        .init(category: "TECHNICAL AND AIRCRAFT EQUIPMENT", delayNumber: 42, code: "TM", descriptionText: "SCHEDULED MAINTENANCE.", noteGuidance: "Late release."),
        .init(category: "TECHNICAL AND AIRCRAFT EQUIPMENT", delayNumber: 43, code: "TN", descriptionText: "NON-SCHEDULED MAINTENANCE.", noteGuidance: "Special checks and/or additional works beyond normal maintenance schedule."),
        .init(category: "TECHNICAL AND AIRCRAFT EQUIPMENT", delayNumber: 44, code: "TS", descriptionText: "SPARES AND MAINTENANCE EQUIPMENT.", noteGuidance: "Lack of or breakdown."),
        .init(category: "TECHNICAL AND AIRCRAFT EQUIPMENT", delayNumber: 45, code: "TA", descriptionText: "AOG SPARES.", noteGuidance: "To be carried to another station."),
        .init(category: "TECHNICAL AND AIRCRAFT EQUIPMENT", delayNumber: 46, code: "TC", descriptionText: "AIRCRAFT CHANGE.", noteGuidance: "For technical reasons."),
        .init(category: "TECHNICAL AND AIRCRAFT EQUIPMENT", delayNumber: 47, code: "TL", descriptionText: "STAND-BY AIRCRAFT.", noteGuidance: "Lack of planned stand-by aircraft for technical reasons."),
        .init(category: "TECHNICAL AND AIRCRAFT EQUIPMENT", delayNumber: 48, code: "TV", descriptionText: "SCHEDULED CABIN CONFIGURATION / VERSION ADJUSTMENTS.", noteGuidance: ""),
        .init(category: "DAMAGE TO AIRCRAFT & EDP / AUTOMATED EQUIPMENT FAILURE", delayNumber: 51, code: "DF", descriptionText: "DAMAGE DURING FLIGHT OPERATIONS.", noteGuidance: "Bird or lightning strike, turbulence, heavy or overweight landing, collision during taxiing."),
        .init(category: "DAMAGE TO AIRCRAFT & EDP / AUTOMATED EQUIPMENT FAILURE", delayNumber: 52, code: "DG", descriptionText: "DAMAGE DURING GROUND OPERATIONS.", noteGuidance: "Collisions (other than during taxiing), loading / off-loading damage, contamination, towing, extreme weather conditions."),
        .init(category: "DAMAGE TO AIRCRAFT & EDP / AUTOMATED EQUIPMENT FAILURE", delayNumber: 55, code: "ED", descriptionText: "DEPARTURE CONTROL.", noteGuidance: ""),
        .init(category: "DAMAGE TO AIRCRAFT & EDP / AUTOMATED EQUIPMENT FAILURE", delayNumber: 56, code: "EC", descriptionText: "CARGO PREPARATION / DOCUMENTATION.", noteGuidance: ""),
        .init(category: "DAMAGE TO AIRCRAFT & EDP / AUTOMATED EQUIPMENT FAILURE", delayNumber: 57, code: "EF", descriptionText: "FLIGHT PLANT.", noteGuidance: ""),
        .init(category: "DAMAGE TO AIRCRAFT & EDP / AUTOMATED EQUIPMENT FAILURE", delayNumber: 58, code: "EO", descriptionText: "OTHER AUTOMATED SYSTEM.", noteGuidance: ""),
        .init(category: "FLIGHT OPERATIONS AND CREWING", delayNumber: 61, code: "FP", descriptionText: "FLIGHT PLAN.", noteGuidance: "Late completion or change of flight documentation."),
        .init(category: "FLIGHT OPERATIONS AND CREWING", delayNumber: 62, code: "FF", descriptionText: "OPERATIONAL REQUIREMENTS.", noteGuidance: "Fuel load alteration."),
        .init(category: "FLIGHT OPERATIONS AND CREWING", delayNumber: 63, code: "FT", descriptionText: "LATE CREW BOARDING OR DEPARTURE PROCEDURES.", noteGuidance: "Other than connection and standby (flight deck or entire crew)."),
        .init(category: "FLIGHT OPERATIONS AND CREWING", delayNumber: 64, code: "FS", descriptionText: "FLIGHT DECK CREW SHORTAGE.", noteGuidance: "Sickness, awaiting standby, flight time limitations, crew meals, valid visa, health documents, etc."),
        .init(category: "FLIGHT OPERATIONS AND CREWING", delayNumber: 65, code: "FR", descriptionText: "FLIGHT DECK CREW SPECIAL REQUEST.", noteGuidance: "Not within operational requirements."),
        .init(category: "FLIGHT OPERATIONS AND CREWING", delayNumber: 66, code: "FL", descriptionText: "LATE CABIN CREW BOARDING OR DEPARTURE PROCEDURES.", noteGuidance: "Other than connection and standby."),
        .init(category: "FLIGHT OPERATIONS AND CREWING", delayNumber: 67, code: "FC", descriptionText: "CABIN CREW SHORTAGE.", noteGuidance: "Sickness, awaiting standby, flight time limitations, crew meals, valid visa, health documents, etc."),
        .init(category: "FLIGHT OPERATIONS AND CREWING", delayNumber: 68, code: "FA", descriptionText: "CABIN CREW ERROR OR SPECIAL REQUEST.", noteGuidance: "Not within operational requirements."),
        .init(category: "FLIGHT OPERATIONS AND CREWING", delayNumber: 69, code: "FB", descriptionText: "CAPTAIN REQUEST FOR SECURITY CHECK.", noteGuidance: "Extraordinary."),
        .init(category: "WEATHER", delayNumber: 71, code: "WO", descriptionText: "DEPARTURE STATION.", noteGuidance: ""),
        .init(category: "WEATHER", delayNumber: 72, code: "WT", descriptionText: "DESTINATION STATION.", noteGuidance: ""),
        .init(category: "WEATHER", delayNumber: 73, code: "WR", descriptionText: "EN ROUTE OR ALTERNATE.", noteGuidance: ""),
        .init(category: "WEATHER", delayNumber: 75, code: "WI", descriptionText: "DE-ICING OF AIRCRAFT.", noteGuidance: "Removal of ice and / or snow, frost prevention excluding unserviceability of equipment."),
        .init(category: "WEATHER", delayNumber: 76, code: "WS", descriptionText: "REMOVAL OF SNOW, ICE, WATER AND SAND FROM AIRPORT.", noteGuidance: ""),
        .init(category: "WEATHER", delayNumber: 77, code: "WG", descriptionText: "GROUND HANDLING IMPAIRED BY ADVERSE WEATHER CONDITIONS.", noteGuidance: ""),
        .init(category: "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES", delayNumber: 81, code: "AT", descriptionText: "ATFM due to ATC EN-ROUTE DEMAND / CAPACITY.", noteGuidance: "Standard demand / capacity problems."),
        .init(category: "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES", delayNumber: 82, code: "AX", descriptionText: "ATFM due to ATC STAFF / EQUIPMENT EN-ROUTE.", noteGuidance: "Reduced capacity caused by industrial action or staff shortage, equipment failure, military exercise or extraordinary demand due to capacity reduction in neighbouring area."),
        .init(category: "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES", delayNumber: 83, code: "AE", descriptionText: "ATFM due to RESTRICTION AT DESTINATION AIRPORT.", noteGuidance: "Airport and/or runway closed due to obstruction, industrial action, staff shortage, political unrest, noise abatement, night curfew, special flights."),
        .init(category: "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES", delayNumber: 84, code: "AW", descriptionText: "ATFM due to WEATHER AT DESTINATION.", noteGuidance: ""),
        .init(category: "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES", delayNumber: 85, code: "AS", descriptionText: "MANDATORY SECURITY.", noteGuidance: ""),
        .init(category: "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES", delayNumber: 86, code: "AG", descriptionText: "IMMIGRATION, CUSTOMS, HEALTH.", noteGuidance: ""),
        .init(category: "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES", delayNumber: 87, code: "AF", descriptionText: "AIRPORT FACILITIES.", noteGuidance: "Parking stands, ramp congestion lighting, buildings, gate limitations, etc."),
        .init(category: "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES", delayNumber: 88, code: "AD", descriptionText: "RESTRICTIONS AT AIRPORT OF DESTINATION.", noteGuidance: "Airport and / or runway closed due to obstruction, industrial action, staff shortage, political unrest, noise abatement, night curfew, special flights."),
        .init(category: "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES", delayNumber: 89, code: "AM", descriptionText: "RESTRICTIONS AT AIRPORT OF DEPARTURE WITH OR WITHOUT ATFM RESTRICTIONS.", noteGuidance: "Including air traffic services, start-up and pushback, airport and/or runway closed due to obstruction or weather, industrial action, staff shorts, political unrest, noise abatement, night curfew, special flights."),
        .init(category: "REACTIONARY", delayNumber: 91, code: "RL", descriptionText: "LOAD CONNECTION.", noteGuidance: "Awaiting load from another flight."),
        .init(category: "REACTIONARY", delayNumber: 92, code: "RT", descriptionText: "THROUGH CHECK-IN ERROR.", noteGuidance: "Passenger and baggage."),
        .init(category: "REACTIONARY", delayNumber: 93, code: "RA", descriptionText: "AIRCRAFT ROTATION.", noteGuidance: "Late arrival of aircraft from another flight or previous sector."),
        .init(category: "REACTIONARY", delayNumber: 94, code: "RS", descriptionText: "CABIN CREW ROTATION.", noteGuidance: "Awaiting cabin crew from another flight."),
        .init(category: "REACTIONARY", delayNumber: 95, code: "RC", descriptionText: "CREW ROTATION.", noteGuidance: "Awaiting crew from another flight (flight deck or entire crew)."),
        .init(category: "REACTIONARY", delayNumber: 96, code: "RO", descriptionText: "OPERATIONS CONTROL.", noteGuidance: "Re-routing, diversion, consolidation, aircraft change for reasons other than technical."),
        .init(category: "REACTIONARY", delayNumber: 97, code: "MI", descriptionText: "INDUSTRIAL ACTION WITH OWN AIRLINE.", noteGuidance: ""),
        .init(category: "REACTIONARY", delayNumber: 98, code: "MO", descriptionText: "INDUSTRIAL ACTION OUTSIDE OWN AIRLINE.", noteGuidance: "Excluding ATS."),
        .init(category: "REACTIONARY", delayNumber: 99, code: "MX", descriptionText: "OTHER REASON.", noteGuidance: "Not matching any code above.")
    ]

    static var grouped: [(category: String, rows: [IATADelayCodeDefinition])] {
        let categoryOrder: [String] = [
            "OTHERS",
            "PASSENGER AND BAGGAGE",
            "CARGO AND MAIL",
            "AIRCRAFT RAMP HANDLING",
            "TECHNICAL AND AIRCRAFT EQUIPMENT",
            "DAMAGE TO AIRCRAFT & EDP / AUTOMATED EQUIPMENT FAILURE",
            "FLIGHT OPERATIONS AND CREWING",
            "WEATHER",
            "ATFM & AIRPORT & GOVERNMENTAL AUTHORITIES",
            "REACTIONARY"
        ]

        let grouped = Dictionary(grouping: all, by: { $0.category })
        return categoryOrder.compactMap { category in
            guard let rows = grouped[category] else { return nil }
            return (category, rows.sorted { $0.delayNumber < $1.delayNumber })
        }
    }
}

enum LegDocumentType: String, CaseIterable, Identifiable, Codable {
    case paxManifest = "PAX Manifest"
    case patientManifest = "Patient Manifest"
    case genDec = "GENDEC"
    case loadSheet = "Load Sheet"
    case fuelSlip = "Fuel Slip"
    case landingPermit = "Landing Permit"
    case handlingInvoice = "Handling Invoice"
    case customsForm = "Customs Form"
    case briefingPack = "Briefing Pack"
    case navLog = "Nav Log"
    case apgPerformance = "APG Performance"
    case foreFlightPack = "ForeFlight Pack"
    case technicalRelease = "Technical Release"
    case cabinChecklist = "Cabin Checklist"
    case trainingForm = "Training Form"
    case other = "Other"

    var id: String { rawValue }

    var preferredAcquisitionMethod: DocumentAcquisitionMethod {
        switch self {
        case .fuelSlip, .landingPermit, .handlingInvoice, .customsForm, .technicalRelease:
            return .scan
        case .navLog, .foreFlightPack:
            return .foreFlight
        case .apgPerformance:
            return .apg
        case .paxManifest, .patientManifest, .genDec, .loadSheet, .briefingPack, .cabinChecklist, .trainingForm, .other:
            return .files
        }
    }
}
