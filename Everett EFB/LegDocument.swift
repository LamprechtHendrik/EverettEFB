//
//  LegDocument.swift
//  Everett EFB
//
//  Created by Hendrik Adriaan Lamprecht on 6/3/26.
//

import Foundation
import SwiftData

@Model final class LegDocument {
    var typeRaw: String
    var fileName: String
    var acquisitionMethodRaw: String
    var isRequired: Bool
    var note: String
    var fileData: Data?
    var contentType: String
    var pageCount: Int?
    var leg: FlightLeg?
    var createdAt: Date

    init(
        type: LegDocumentType,
        fileName: String = "",
        acquisitionMethod: DocumentAcquisitionMethod? = nil,
        isRequired: Bool = false,
        note: String = "",
        fileData: Data? = nil,
        contentType: String = "",
        pageCount: Int? = nil,
        leg: FlightLeg? = nil,
        createdAt: Date = Date()
    ) {
        self.typeRaw = type.rawValue
        self.fileName = fileName
        self.acquisitionMethodRaw = (acquisitionMethod ?? type.preferredAcquisitionMethod).rawValue
        self.isRequired = isRequired
        self.note = note
        self.fileData = fileData
        self.contentType = contentType
        self.pageCount = pageCount
        self.leg = leg
        self.createdAt = createdAt
    }

    var acquisitionMethod: DocumentAcquisitionMethod {
        DocumentAcquisitionMethod(rawValue: acquisitionMethodRaw) ?? type.preferredAcquisitionMethod
    }

    var type: LegDocumentType {
        LegDocumentType(rawValue: typeRaw) ?? .other
    }

    var hasStoredFile: Bool {
        fileData != nil && !(fileData?.isEmpty ?? true)
    }
}
