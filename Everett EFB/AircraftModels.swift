import Foundation
import SwiftData

enum AircraftDocumentType: String, CaseIterable, Identifiable, Codable {

    // Aircraft Documents
    case paxBriefingCard = "PAX Briefing Card"
    case certificateReleaseService = "Certificate of Release to Service"
    case certificateAirworthiness = "Certificate of Airworthiness"
    case radioStationLicense = "Radio Station License"
    case certificateInsurance = "Certificate of Insurance"
    case survivalEquipmentList = "Aircraft Survival Equipment List"
    case aircraftLeaseAgreement = "Aircraft Lease Agreement"
    case aircraftMaintenanceAgreement = "Aircraft Maintenance Agreement"
    case weightBalanceCertificate = "Weight & Balance Certificate"
    case certificateRegistration = "Certificate of Registration"
    case opspec = "OPSPEC"
    case noiseCertificate = "Noise Certificate"
    case eltRegistration = "ELT Registration Document"
    case transponderCode = "Transponder Code"
    case pohAfmApproval = "POH/AFM Approval Pages"
    case lopa = "LOPA"

    // LOPA Equipment
    case firstAidKit = "First Aid Kit"
    case universalSpillKit = "Universal Spill Kit"

    // Contract Equipment
    case survivalKit = "Survival Kit"
    case barsEquipment = "BARS Equipment Fit"
    case unEquipment = "UN Equipment Fit"
    case iosaEquipment = "IOSA Equipment Fit"
    case ogpEquipment = "OGP Equipment Fit"

    var id: String { rawValue }
}

@Model
final class Aircraft {

    var registration: String
    var type: String
    var modelSerialNumber: String

    @Relationship(deleteRule: .cascade)
    var documents: [AircraftDocument]

    init(
        registration: String = "",
        type: String = "",
        modelSerialNumber: String = "",
        documents: [AircraftDocument] = []
    ) {
        self.registration = registration
        self.type = type
        self.modelSerialNumber = modelSerialNumber
        self.documents = documents
    }
}

@Model
final class AircraftDocument {

    var typeRaw: String
    var lastCompleted: Date?
    var expiry: Date?

    init(type: AircraftDocumentType,
         lastCompleted: Date? = nil,
         expiry: Date? = nil) {

        self.typeRaw = type.rawValue
        self.lastCompleted = lastCompleted
        self.expiry = expiry
    }

    var type: AircraftDocumentType {
        AircraftDocumentType(rawValue: typeRaw) ?? .paxBriefingCard
    }
}
import Foundation

enum AircraftDocGroup: String, CaseIterable, Identifiable {
    case aircraftDocuments = "Aircraft Documents"
    case lopaEquipment = "LOPA Equipment"
    case contractEquipment = "Contract Equipment"

    var id: String { rawValue }
}

extension AircraftDocumentType {
    var group: AircraftDocGroup {
        switch self {
        // Aircraft Documents
        case .paxBriefingCard,
             .certificateReleaseService,
             .certificateAirworthiness,
             .radioStationLicense,
             .certificateInsurance,
             .survivalEquipmentList,
             .aircraftLeaseAgreement,
             .aircraftMaintenanceAgreement,
             .weightBalanceCertificate,
             .certificateRegistration,
             .opspec,
             .noiseCertificate,
             .eltRegistration,
             .transponderCode,
             .pohAfmApproval,
             .lopa:
            return .aircraftDocuments

        // LOPA Equipment
        case .firstAidKit,
             .universalSpillKit:
            return .lopaEquipment

        // Contract Equipment
        case .survivalKit,
             .barsEquipment,
             .unEquipment,
             .iosaEquipment,
             .ogpEquipment:
            return .contractEquipment
        }
    }
}
import Foundation

extension AircraftDocument {
    func status(asOf: Date = Date(), cautionDays: Int = 30) -> ComplianceStatus {
        Compliance.status(forExpiry: expiry, asOf: asOf, cautionDays: cautionDays)
    }
}

extension Aircraft {
    func overallStatus(asOf: Date = Date(), cautionDays: Int = 30) -> ComplianceStatus {
        let statuses = documents.map { $0.status(asOf: asOf, cautionDays: cautionDays) }
        return Compliance.worst(statuses)
    }
}
