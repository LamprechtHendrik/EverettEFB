import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import VisionKit
import PDFKit

struct AddLegDocumentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var leg: FlightLeg

    private let initialType: LegDocumentType?
    private let initialMethod: DocumentAcquisitionMethod?
    private let initialIsRequired: Bool
    private let initialNote: String

    @State private var selectedType: LegDocumentType = .briefingPack
    @State private var selectedMethod: DocumentAcquisitionMethod = .files
    @State private var fileName: String = ""
    @State private var note: String = ""
    @State private var isRequired: Bool = false

    @State private var attachedData: Data?
    @State private var attachedContentType: String = ""
    @State private var attachedPageCount: Int?

    @State private var showFileImporter = false
    @State private var showScanner = false
    @State private var importErrorMessage: String?

    init(
        leg: FlightLeg,
        initialType: LegDocumentType? = nil,
        initialMethod: DocumentAcquisitionMethod? = nil,
        initialIsRequired: Bool = false,
        initialNote: String = ""
    ) {
        self.leg = leg
        self.initialType = initialType
        self.initialMethod = initialMethod
        self.initialIsRequired = initialIsRequired
        self.initialNote = initialNote
    }

    var body: some View {
        Form {
            Section("1. Select Document") {
                Picker("Document Type", selection: $selectedType) {
                    ForEach(LegDocumentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                Toggle("Required document", isOn: $isRequired)

                Text(selectedTypeHelpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("2. Attach Document") {
                Button {
                    showFileImporter = true
                } label: {
                    actionRow(
                        title: "Upload",
                        subtitle: "Choose a document from Files on the iPad.",
                        systemImage: "square.and.arrow.up"
                    )
                }

                if scannerAvailable {
                    Button {
                        showScanner = true
                    } label: {
                        actionRow(
                            title: "Scan",
                            subtitle: "Open the document scanner for paper documents.",
                            systemImage: "doc.viewfinder"
                        )
                    }
                }

                if let attachedData, !attachedData.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Attached")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(selectedMethod.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(fileName)
                            .foregroundStyle(.secondary)

                        if let attachedPageCount {
                            Text("Pages: \(attachedPageCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("Stored in document record")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("No document attached yet.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("3. Notes") {
                TextField("Reference / note", text: $note, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section {
                Button("Save Document") {
                    saveDocument()
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("Add Document")
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerSheet { scanResult in
                attachedData = scanResult.pdfData
                attachedContentType = UTType.pdf.identifier
                attachedPageCount = scanResult.pageCount
                selectedMethod = .scan
                fileName = "\(selectedType.rawValue) Scan \(Date().efbDate).pdf"
            }
        }
        .alert("Document Error", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "")
        }
        .onAppear {
            if let initialType {
                selectedType = initialType
            }
            selectedMethod = initialMethod ?? selectedType.preferredAcquisitionMethod
            isRequired = initialIsRequired
            note = initialNote
        }
        .onChange(of: selectedType) { _, newType in
            if attachedData == nil {
                selectedMethod = initialMethod ?? newType.preferredAcquisitionMethod
            }
        }
    }

    private var canSave: Bool {
        !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        attachedData != nil &&
        !(attachedData?.isEmpty ?? true)
    }

    private var scannerAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    private var allowedContentTypes: [UTType] {
        [.pdf, .image, .jpeg, .png]
    }

    private var selectedTypeHelpText: String {
        switch selectedType {
        case .fuelSlip, .landingPermit, .handlingInvoice, .customsForm, .technicalRelease:
            return "Normally scanned from a paper document in the aircraft or at the station."
        case .navLog, .foreFlightPack:
            return "Normally uploaded from ForeFlight export files."
        case .apgPerformance:
            return "Normally uploaded from APG performance output."
        case .paxManifest, .patientManifest, .genDec, .loadSheet, .briefingPack, .cabinChecklist, .trainingForm, .other:
            return "Choose the document first, then Upload or Scan it."
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let started = url.startAccessingSecurityScopedResource()
            defer {
                if started { url.stopAccessingSecurityScopedResource() }
            }

            do {
                let data = try Data(contentsOf: url)
                attachedData = data
                fileName = url.lastPathComponent
                attachedContentType = UTType(filenameExtension: url.pathExtension)?.identifier ?? "application/octet-stream"
                attachedPageCount = pdfPageCount(from: data)

                if selectedType == .navLog || selectedType == .foreFlightPack {
                    selectedMethod = .foreFlight
                } else if selectedType == .apgPerformance {
                    selectedMethod = .apg
                } else {
                    selectedMethod = .files
                }
            } catch {
                importErrorMessage = error.localizedDescription
            }

        case .failure(let error):
            importErrorMessage = error.localizedDescription
        }
    }

    private func pdfPageCount(from data: Data) -> Int? {
        PDFDocument(data: data)?.pageCount
    }

    private func saveDocument() {
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let currentLeg: FlightLeg = leg

        let doc = LegDocument(
            type: selectedType,
            fileName: trimmedFileName,
            acquisitionMethod: selectedMethod,
            isRequired: isRequired,
            note: trimmedNote,
            fileData: attachedData,
            contentType: attachedContentType,
            pageCount: attachedPageCount,
            leg: currentLeg
        )

        modelContext.insert(doc)
        doc.leg = currentLeg

        if !currentLeg.documents.contains(where: { $0.persistentModelID == doc.persistentModelID }) {
            currentLeg.documents.append(doc)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            importErrorMessage = error.localizedDescription
            print("❌ Save leg document failed:", error)
        }
    }

    private func actionRow(title: String, subtitle: String, systemImage: String) -> some View {
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

private struct ScannedDocumentResult {
    let pdfData: Data
    let pageCount: Int
}

private struct DocumentScannerSheet: UIViewControllerRepresentable {
    let onComplete: (ScannedDocumentResult) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) { }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: (ScannedDocumentResult) -> Void
        let dismiss: DismissAction

        init(onComplete: @escaping (ScannedDocumentResult) -> Void, dismiss: DismissAction) {
            self.onComplete = onComplete
            self.dismiss = dismiss
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("❌ Document scan failed:", error)
            dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)

            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                let bounds = CGRect(origin: .zero, size: image.size)
                UIGraphicsBeginPDFPageWithInfo(bounds, nil)
                image.draw(in: bounds)
            }

            UIGraphicsEndPDFContext()
            onComplete(.init(pdfData: pdfData as Data, pageCount: scan.pageCount))
            dismiss()
        }
    }
}
