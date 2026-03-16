import SwiftUI
import SwiftData
import PDFKit
import PencilKit
import UIKit
import QuickLook

struct ReportsHomeView: View {
    @Query(sort: [SortDescriptor(\Flight.createdAt, order: .reverse)])
    private var allFlights: [Flight]

    var body: some View {
        List {
            if yearBuckets.isEmpty {
                ContentUnavailableView(
                    "No finalized flight reports",
                    systemImage: "doc.text",
                    description: Text("Finalize a flight report and it will appear here.")
                )
            } else {
                ForEach(yearBuckets) { bucket in
                    NavigationLink {
                        FlightReportsMonthView(yearBucket: bucket)
                    } label: {
                        folderRow(
                            title: "\(bucket.year)",
                            subtitle: "\(bucket.flights.count) report\(bucket.flights.count == 1 ? "" : "s")",
                            systemImage: "folder"
                        )
                    }
                }
            }
        }
        .navigationTitle("Reports")
    }

    private var finalizedFlights: [Flight] {
        allFlights.filter { $0.isClosed }
    }

    private var yearBuckets: [FlightReportYearBucket] {
        let grouped = Dictionary(grouping: finalizedFlights) { flight in
            Calendar.current.component(.year, from: flight.reportFolderDate)
        }

        return grouped.keys.sorted().reversed().map { year in
            FlightReportYearBucket(
                year: year,
                flights: grouped[year]?.sorted(by: { $0.reportFolderDate > $1.reportFolderDate }) ?? []
            )
        }
    }

    private func folderRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct FlightReportsMonthView: View {
    let yearBucket: FlightReportYearBucket

    var body: some View {
        List {
            ForEach(monthBuckets) { bucket in
                NavigationLink {
                    FlightReportsDayView(monthBucket: bucket)
                } label: {
                    folderRow(
                        title: bucket.monthName,
                        subtitle: "\(bucket.flights.count) report\(bucket.flights.count == 1 ? "" : "s")",
                        systemImage: "folder"
                    )
                }
            }
        }
        .navigationTitle("\(yearBucket.year)")
    }

    private var monthBuckets: [FlightReportMonthBucket] {
        let grouped = Dictionary(grouping: yearBucket.flights) { flight in
            Calendar.current.component(.month, from: flight.reportFolderDate)
        }

        return grouped.keys.sorted().map { month in
            FlightReportMonthBucket(
                year: yearBucket.year,
                month: month,
                flights: grouped[month]?.sorted(by: { $0.reportFolderDate > $1.reportFolderDate }) ?? []
            )
        }
    }

    private func folderRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct FlightReportsDayView: View {
    let monthBucket: FlightReportMonthBucket

    var body: some View {
        List {
            ForEach(dayBuckets) { bucket in
                NavigationLink {
                    FlightReportsForDayView(dayBucket: bucket)
                } label: {
                    folderRow(
                        title: bucket.dayName,
                        subtitle: "\(bucket.flights.count) report\(bucket.flights.count == 1 ? "" : "s")",
                        systemImage: "folder"
                    )
                }
            }
        }
        .navigationTitle(monthBucket.monthName)
    }

    private var dayBuckets: [FlightReportDayBucket] {
        let grouped = Dictionary(grouping: monthBucket.flights) { flight in
            Calendar.current.component(.day, from: flight.reportFolderDate)
        }

        return grouped.keys.sorted().map { day in
            FlightReportDayBucket(
                year: monthBucket.year,
                month: monthBucket.month,
                day: day,
                flights: grouped[day]?.sorted(by: { $0.reportFolderDate > $1.reportFolderDate }) ?? []
            )
        }
    }

    private func folderRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct FlightReportsForDayView: View {
    let dayBucket: FlightReportDayBucket

    var body: some View {
        List {
            ForEach(dayBucket.flights) { flight in
                NavigationLink {
                    FlightReportPackageView(flight: flight)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(flight.reportDisplayName)
                                .font(.headline)

                            Text("\(flight.aircraftReg) • PIC \(flight.pic)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(dayBucket.dayName)
    }
}

struct FlightReportPackageView: View {
    let flight: Flight

    @Query(sort: [SortDescriptor(\LegDocument.createdAt, order: .reverse)])
    private var allDocuments: [LegDocument]

    private var flightDocuments: [LegDocument] {
        let legIDs = Set(flight.legs.map(\.persistentModelID))
        return allDocuments.filter { doc in
            guard let leg = doc.leg else { return false }
            return legIDs.contains(leg.persistentModelID)
        }
    }

    var body: some View {
        List {
            NavigationLink {
                GeneratedFlightReportPDFView(flight: flight)
            } label: {
                reportFolderRow(
                    title: "Flight Report PDF",
                    subtitle: "Generated from the Everett template",
                    systemImage: "doc.text.viewfinder"
                )
            }

            NavigationLink {
                FlightReportSummaryView(flight: flight)
            } label: {
                reportFolderRow(
                    title: "Summary",
                    subtitle: "Populated flight report data",
                    systemImage: "doc.text"
                )
            }

            NavigationLink {
                FlightReportDocumentFolderView(
                    title: "Briefings",
                    subtitle: "Briefing and support documents",
                    documents: documents(in: .briefings)
                )
            } label: {
                reportFolderRow(
                    title: "Briefings",
                    subtitle: "\(documents(in: .briefings).count) file(s)",
                    systemImage: "folder"
                )
            }

            NavigationLink {
                FlightReportDocumentFolderView(
                    title: "Flight Folios",
                    subtitle: "GENDEC, load sheets and folio docs",
                    documents: documents(in: .flightFolios)
                )
            } label: {
                reportFolderRow(
                    title: "Flight Folios",
                    subtitle: "\(documents(in: .flightFolios).count) file(s)",
                    systemImage: "folder"
                )
            }

            NavigationLink {
                FlightReportDocumentFolderView(
                    title: "Fuel Slips",
                    subtitle: "Fuel-related documents",
                    documents: documents(in: .fuelSlips)
                )
            } label: {
                reportFolderRow(
                    title: "Fuel Slips",
                    subtitle: "\(documents(in: .fuelSlips).count) file(s)",
                    systemImage: "folder"
                )
            }

            NavigationLink {
                FlightReportDocumentFolderView(
                    title: "Manifests",
                    subtitle: "Passenger manifests",
                    documents: documents(in: .manifests)
                )
            } label: {
                reportFolderRow(
                    title: "Manifests",
                    subtitle: "\(documents(in: .manifests).count) file(s)",
                    systemImage: "folder"
                )
            }

            NavigationLink {
                FlightReportDocumentFolderView(
                    title: "Navlogs",
                    subtitle: "Navigation logs",
                    documents: documents(in: .navlogs)
                )
            } label: {
                reportFolderRow(
                    title: "Navlogs",
                    subtitle: "\(documents(in: .navlogs).count) file(s)",
                    systemImage: "folder"
                )
            }

            NavigationLink {
                FlightReportDocumentFolderView(
                    title: "Performances",
                    subtitle: "Performance documents",
                    documents: documents(in: .performances)
                )
            } label: {
                reportFolderRow(
                    title: "Performances",
                    subtitle: "\(documents(in: .performances).count) file(s)",
                    systemImage: "folder"
                )
            }
        }
        .navigationTitle(flight.reportDisplayName)
    }

    private func documents(in category: FlightReportFolderCategory) -> [FlightReportDocumentItem] {
        flightDocuments
            .filter { matches(doc: $0, category: category) }
            .map { doc in
                let leg = doc.leg
                return FlightReportDocumentItem(
                    displayName: doc.fileName.isEmpty ? doc.type.rawValue : doc.fileName,
                    documentType: doc.type.rawValue,
                    legSequence: leg?.sequence ?? 0,
                    route: {
                        guard let leg else { return "" }
                        return "\(leg.departure) → \(leg.destination)"
                    }(),
                    contentType: doc.contentType,
                    fileData: doc.fileData
                )
            }
    }

    private func matches(doc: LegDocument, category: FlightReportFolderCategory) -> Bool {
        let file = doc.fileName.lowercased()
        let type = doc.type

        switch category {
        case .briefings:
            return type == .landingPermit ||
                type == .handlingInvoice ||
                type == .customsForm ||
                type == .other ||
                type == .briefingPack

        case .flightFolios:
            return type == .genDec || type == .loadSheet

        case .fuelSlips:
            return type == .fuelSlip || file.contains("fuel")

        case .manifests:
            return type == .paxManifest || type == .patientManifest || file.contains("manifest")

        case .navlogs:
            return type == .navLog || type == .foreFlightPack || file.contains("navlog") || file.contains("nav")

        case .performances:
            return type == .apgPerformance || type == .trainingForm || file.contains("perf") || file.contains("performance")
        }
    }

    private func reportFolderRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct GeneratedFlightReportPDFView: View {
    let flight: Flight

    @State private var document: PDFDocument?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let document {
                PDFKitView(document: document)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Unable to generate PDF",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Generating flight report...")
            }
        }
        .navigationTitle("Flight Report PDF")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await generatePDF()
        }
    }

    @MainActor
    private func generatePDF() async {
        do {
            let generator = FlightReportPDFGenerator()
            document = try generator.generatePDF(for: flight)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FlightReportSummaryView: View {
    let flight: Flight

    var body: some View {
        List {
            Section("Flight") {
                LabeledContent("Report Number", value: flight.reportNumber)
                LabeledContent("Aircraft", value: flight.aircraftReg)
                LabeledContent("PIC", value: flight.pic)
                if !flight.sic.isEmpty { LabeledContent("SIC", value: flight.sic) }
                if !flight.cabinCrew.isEmpty { LabeledContent("Cabin Crew", value: flight.cabinCrew) }
                if !flight.client.isEmpty { LabeledContent("Client", value: flight.client) }
                LabeledContent("First Leg Date", value: flight.reportFolderDate.efbDate)
            }

            Section("Daily Sign On / Off") {
                if flight.daySigns.isEmpty {
                    Text("No day sign records")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(flight.daySigns.sorted(by: { $0.date < $1.date })) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(day.date.efbDate)
                                .font(.headline)

                            Text("Sign On: \(day.signOnTime.isEmpty ? "-" : day.signOnTime)")
                                .foregroundStyle(.secondary)

                            Text("Sign Off: \(day.signOffTime.isEmpty ? "-" : day.signOffTime)")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Legs") {
                ForEach(flight.legs.sorted(by: { $0.sequence < $1.sequence })) { leg in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Leg \(leg.sequence): \(leg.departure) → \(leg.destination)")
                            .font(.headline)

                        Text("Date: \(leg.date.efbDate)")
                            .foregroundStyle(.secondary)

                        Text("Call Sign: \(leg.callSign.isEmpty ? "-" : leg.callSign)")
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Block")
                            Spacer()
                            Text("\(TimeEntryHelper.display(from: leg.blockOff)) - \(TimeEntryHelper.display(from: leg.blockOn))")
                        }

                        HStack {
                            Text("Flight")
                            Spacer()
                            Text("\(TimeEntryHelper.display(from: leg.takeOff)) - \(TimeEntryHelper.display(from: leg.landing))")
                        }

                        HStack {
                            Text("Fuel")
                            Spacer()
                            Text("DEP \(leg.depFuel.map { String($0) } ?? "-") / LDG \(leg.ldgFuel.map { String($0) } ?? "-") / USED \(leg.fuelUsed.map { String($0) } ?? "-")")
                        }

                        HStack {
                            Text("PAX / Cargo")
                            Spacer()
                            Text("\(leg.pax.map { String($0) } ?? "-") / \(leg.cargo.map { String($0) } ?? "-")")
                        }

                        if !leg.loc.isEmpty {
                            HStack {
                                Text("LOC")
                                Spacer()
                                Text(leg.loc)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Summary")
    }
}

struct FlightReportDocumentFolderView: View {
    let title: String
    let subtitle: String
    let documents: [FlightReportDocumentItem]

    private var indexedDocuments: [(offset: Int, element: FlightReportDocumentItem)] {
        Array(documents.enumerated())
    }

    var body: some View {
        List {
            Section {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if documents.isEmpty {
                ContentUnavailableView(
                    "No documents",
                    systemImage: "doc",
                    description: Text("No linked documents in this folder yet.")
                )
            } else {
                ForEach(indexedDocuments, id: \.element.id) { entry in
                    let item = entry.element

                    NavigationLink {
                        FlightStoredDocumentView(item: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .font(.headline)

                            Text("Leg \(item.legSequence) • \(item.documentType)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if !item.route.isEmpty {
                                Text(item.route)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text(item.isViewable ? "Tap to view" : "Stored but not previewable")
                                .font(.caption)
                                .foregroundColor(item.isViewable ? .secondary : .orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

struct FlightReportYearBucket: Identifiable {
    let id = UUID()
    let year: Int
    let flights: [Flight]
}

struct FlightReportMonthBucket: Identifiable {
    let id = UUID()
    let year: Int
    let month: Int
    let flights: [Flight]

    var monthName: String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[month - 1]
    }
}

struct FlightReportDayBucket: Identifiable {
    let id = UUID()
    let year: Int
    let month: Int
    let day: Int
    let flights: [Flight]

    var dayName: String {
        String(format: "%02d", day)
    }
}

enum FlightReportFolderCategory {
    case briefings
    case flightFolios
    case fuelSlips
    case manifests
    case navlogs
    case performances
}

struct FlightReportDocumentItem: Identifiable {
    let id = UUID()
    let displayName: String
    let documentType: String
    let legSequence: Int
    let route: String
    let contentType: String
    let fileData: Data?

    var isViewable: Bool {
        guard let fileData, !fileData.isEmpty else { return false }
        if PDFDocument(data: fileData) != nil { return true }
        if UIImage(data: fileData) != nil { return true }
        return false
    }
}

struct FlightStoredDocumentView: View {
    let item: FlightReportDocumentItem

    var body: some View {
        Group {
            if let fileData = item.fileData, let pdf = PDFDocument(data: fileData) {
                PDFKitView(document: pdf)
            } else if let fileData = item.fileData, let image = UIImage(data: fileData) {
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
                .background(Color.black.opacity(0.02))
            } else {
                ContentUnavailableView(
                    "Unable to preview document",
                    systemImage: "doc.badge.questionmark",
                    description: Text(item.fileData == nil || item.fileData?.isEmpty == true
                        ? "No stored file data was found for this document."
                        : "This document format is not previewable yet.")
                )
            }
        }
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Flight {
    var reportFolderDate: Date {
        legs.sorted(by: { $0.sequence < $1.sequence }).first?.date ?? createdAt
    }

    var reportDisplayName: String {
        if !reportNumber.isEmpty {
            return reportNumber
        }
        return "Flight \(aircraftReg)"
    }

    var firstPICSignatureDrawing: Data? {
        daySigns.sorted(by: { $0.date < $1.date }).first?.picSignOnDrawing
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }

    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        ReportsHomeView()
    }
    .modelContainer(for: [Flight.self, FlightLeg.self, FlightDaySign.self, LegDocument.self, LegDelayEntry.self], inMemory: true)
}
