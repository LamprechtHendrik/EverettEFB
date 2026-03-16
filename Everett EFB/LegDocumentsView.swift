import SwiftUI
import SwiftData

struct LegDocumentsView: View {
    @Bindable var leg: FlightLeg
    var flight: Flight

    @Query(sort: [SortDescriptor(\LegDocument.createdAt, order: .reverse)])
    private var allDocuments: [LegDocument]

    private var requirements: [LegDocumentRequirement] {
        flight.documentRequirements(for: leg)
    }

    private var uploadedTypes: Set<LegDocumentType> {
        Set(uploadedDocs.map { $0.type })
    }

    private var missingRequired: [LegDocumentRequirement] {
        requirements.filter { $0.isRequired && !uploadedTypes.contains($0.type) }
    }

    private var uploadedDocs: [LegDocument] {
        allDocuments
            .filter { $0.leg?.persistentModelID == leg.persistentModelID }
            .sorted { lhs, rhs in
                if lhs.type.rawValue == rhs.type.rawValue {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.type.rawValue < rhs.type.rawValue
            }
    }

    private var scanRequirements: [LegDocumentRequirement] {
        requirements.filter { $0.acquisitionMethod == .scan }
    }

    private var fileRequirements: [LegDocumentRequirement] {
        requirements.filter { $0.acquisitionMethod == .files }
    }

    private var foreFlightRequirements: [LegDocumentRequirement] {
        requirements.filter { $0.acquisitionMethod == .foreFlight }
    }

    private var apgRequirements: [LegDocumentRequirement] {
        requirements.filter { $0.acquisitionMethod == .apg }
    }

    private func firstRequirement(for method: DocumentAcquisitionMethod) -> LegDocumentRequirement? {
        missingRequired.first(where: { $0.acquisitionMethod == method }) ?? requirements.first(where: { $0.acquisitionMethod == method })
    }

    var body: some View {
        List {
            Section("Quick Actions") {
                if let requirement = firstRequirement(for: .scan) {
                    NavigationLink {
                        AddLegDocumentView(
                            leg: leg,
                            initialType: requirement.type,
                            initialMethod: .scan,
                            initialIsRequired: requirement.isRequired,
                            initialNote: requirement.note
                        )
                    } label: {
                        quickActionRow(
                            title: "Scan Document",
                            subtitle: scanRequirements.isEmpty ? "Scan a document with the iPad camera." : "Best for: \(scanRequirements.map(\.type.rawValue).joined(separator: ", "))",
                            systemImage: "camera.viewfinder"
                        )
                    }
                }

                if let requirement = firstRequirement(for: .files) {
                    NavigationLink {
                        AddLegDocumentView(
                            leg: leg,
                            initialType: requirement.type,
                            initialMethod: .files,
                            initialIsRequired: requirement.isRequired,
                            initialNote: requirement.note
                        )
                    } label: {
                        quickActionRow(
                            title: "Import From Files",
                            subtitle: fileRequirements.isEmpty ? "Import a PDF or file from the iPad." : "Best for: \(fileRequirements.map(\.type.rawValue).joined(separator: ", "))",
                            systemImage: "folder"
                        )
                    }
                }

                if let requirement = firstRequirement(for: .foreFlight) {
                    NavigationLink {
                        AddLegDocumentView(
                            leg: leg,
                            initialType: requirement.type,
                            initialMethod: .foreFlight,
                            initialIsRequired: requirement.isRequired,
                            initialNote: requirement.note
                        )
                    } label: {
                        quickActionRow(
                            title: "Import ForeFlight",
                            subtitle: foreFlightRequirements.isEmpty ? "Import a ForeFlight export for this leg." : "Best for: \(foreFlightRequirements.map(\.type.rawValue).joined(separator: ", "))",
                            systemImage: "airplane"
                        )
                    }
                }

                if let requirement = firstRequirement(for: .apg) {
                    NavigationLink {
                        AddLegDocumentView(
                            leg: leg,
                            initialType: requirement.type,
                            initialMethod: .apg,
                            initialIsRequired: requirement.isRequired,
                            initialNote: requirement.note
                        )
                    } label: {
                        quickActionRow(
                            title: "Import APG Performance",
                            subtitle: apgRequirements.isEmpty ? "Import APG performance paperwork." : "Best for: \(apgRequirements.map(\.type.rawValue).joined(separator: ", "))",
                            systemImage: "chart.xyaxis.line"
                        )
                    }
                }

                NavigationLink {
                    AddLegDocumentView(leg: leg)
                } label: {
                    quickActionRow(
                        title: "Add Other Document",
                        subtitle: "Attach any additional supporting document for this leg.",
                        systemImage: "plus.circle"
                    )
                }
            }

            // MARK: Required documents still missing
            if !missingRequired.isEmpty {
                Section("Required Documents Missing") {
                    ForEach(missingRequired) { req in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(req.type.rawValue)
                                .font(.headline)

                            Text(req.note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("Source: \(req.acquisitionMethod.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // MARK: Uploaded documents
            if uploadedDocs.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Documents Uploaded",
                        systemImage: "doc",
                        description: Text("Add the required leg documents.")
                    )
                }
            } else {
                Section("Uploaded Documents") {
                    ForEach(uploadedDocs) { doc in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(doc.type.rawValue)
                                    .font(.headline)

                                if doc.isRequired {
                                    Text("Required")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }

                            Text(doc.fileName.isEmpty ? "No file attached yet" : doc.fileName)
                                .foregroundStyle(.secondary)

                            Text("Source: \(doc.acquisitionMethod.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(doc.hasStoredFile ? "Attachment stored" : "No stored attachment")
                                .font(.caption)
                                .foregroundStyle(doc.hasStoredFile ? .green : .orange)

                            if let pageCount = doc.pageCount {
                                Text("Pages: \(pageCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if !doc.note.isEmpty {
                                Text(doc.note)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Leg Documents")
    }

    private func quickActionRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
