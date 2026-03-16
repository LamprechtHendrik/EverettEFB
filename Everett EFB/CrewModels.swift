import Foundation
import SwiftData

enum CrewRole: String, CaseIterable, Identifiable, Codable {
    case pilot = "Pilot"
    case cabinCrew = "Cabin Crew"
    var id: String { rawValue }
}

enum TrainingType: String, CaseIterable, Identifiable, Codable {
    case flightOperationsManual = "Flight Operations Manual"
    case safetyManagementSystem = "Safety Management System"
    case qualityManagementSystem = "Quality Management System"
    case mozambiqueValidation = "Mozambique Validation"
    case crewResourceManagement = "Crew Resource Management"
    case dangerousGoods = "Dangerous Goods"
    case sept = "SEPT"
    case avsec = "AVSEC"
    case wetDitching = "Wet Ditching"
    case fireFighting = "Fire Fighting"
    case avmed = "AVMED"

    var id: String { rawValue }
}

@Model
final class CrewMember {

    var name: String
    var surname: String
    var licenseNumber: String
    var roleRaw: String

    // Recency / required company documents
    var lineTrainingRecord: Bool
    var lineTrainingReport: Bool
    var inductionChecklist: Bool
    var cv: Bool
    var personalDataSheet: Bool
    var drugAndAlcoholPolicy: Bool
    var internetUsagePolicy: Bool

    @Relationship(deleteRule: .cascade)
    var trainings: [TrainingRecord]

    init(
        name: String = "",
        surname: String = "",
        licenseNumber: String = "",
        role: CrewRole = .pilot,
        lineTrainingRecord: Bool = false,
        lineTrainingReport: Bool = false,
        inductionChecklist: Bool = false,
        cv: Bool = false,
        personalDataSheet: Bool = false,
        drugAndAlcoholPolicy: Bool = false,
        internetUsagePolicy: Bool = false,
        trainings: [TrainingRecord] = []
    ) {
        self.name = name
        self.surname = surname
        self.licenseNumber = licenseNumber
        self.roleRaw = role.rawValue

        self.lineTrainingRecord = lineTrainingRecord
        self.lineTrainingReport = lineTrainingReport
        self.inductionChecklist = inductionChecklist
        self.cv = cv
        self.personalDataSheet = personalDataSheet
        self.drugAndAlcoholPolicy = drugAndAlcoholPolicy
        self.internetUsagePolicy = internetUsagePolicy

        self.trainings = trainings
    }

    var role: CrewRole {
        get { CrewRole(rawValue: roleRaw) ?? .pilot }
        set { roleRaw = newValue.rawValue }
    }
}

@Model
final class TrainingRecord {

    var typeRaw: String
    var lastConducted: Date?
    var expiry: Date?

    // Allows training to be marked N/A
    var isNotApplicable: Bool

    init(
        type: TrainingType,
        lastConducted: Date? = nil,
        expiry: Date? = nil,
        isNotApplicable: Bool = false
    ) {
        self.typeRaw = type.rawValue
        self.lastConducted = lastConducted
        self.expiry = expiry
        self.isNotApplicable = isNotApplicable
    }

    var type: TrainingType {
        TrainingType(rawValue: typeRaw) ?? .flightOperationsManual
    }
}

extension TrainingRecord {

    func status(asOf: Date = Date(), cautionDays: Int = 30) -> ComplianceStatus {

        // N/A overrides everything
        if isNotApplicable {
            return .ok
        }

        return Compliance.status(
            forExpiry: expiry,
            asOf: asOf,
            cautionDays: cautionDays
        )
    }
}

extension CrewMember {

    func trainingStatus(asOf: Date = Date(), cautionDays: Int = 30) -> ComplianceStatus {

        // Ignore N/A trainings
        let applicableTrainings = trainings.filter { !$0.isNotApplicable }

        if applicableTrainings.isEmpty {
            return .caution
        }

        let statuses = applicableTrainings.map {
            $0.status(asOf: asOf, cautionDays: cautionDays)
        }

        return Compliance.worst(statuses)
    }

    func recencyBoolStatus() -> ComplianceStatus {

        // If ANY required recency item is missing -> red
        return Compliance.status(forBools: [
            lineTrainingRecord,
            lineTrainingReport,
            inductionChecklist,
            cv,
            personalDataSheet,
            drugAndAlcoholPolicy,
            internetUsagePolicy
        ])
    }

    func overallStatus(asOf: Date = Date(), cautionDays: Int = 30) -> ComplianceStatus {

        let training = trainingStatus(asOf: asOf, cautionDays: cautionDays)
        let recency = recencyBoolStatus()

        // Worst status wins
        return Compliance.worst([training, recency])
    }
}
