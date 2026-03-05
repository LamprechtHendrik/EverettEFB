import SwiftUI
import SwiftData

struct CrewFormView: View {
    enum Mode {
        case add
        case edit(CrewMember)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name: String = ""
    @State private var surname: String = ""
    @State private var licenseNumber: String = ""
    @State private var role: CrewRole = .pilot

    @State private var lineTrainingRecord: Bool = false
    @State private var lineTrainingReport: Bool = false
    @State private var inductionChecklist: Bool = false
    @State private var cv: Bool = false
    @State private var personalDataSheet: Bool = false
    @State private var drugAndAlcoholPolicy: Bool = false
    @State private var internetUsagePolicy: Bool = false

    @State private var lastConducted: [TrainingType: Date?] = [:]
    @State private var expiry: [TrainingType: Date?] = [:]

    private var title: String {
        switch mode {
        case .add: return "Add Crew"
        case .edit: return "Edit Crew"
        }
    }

    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $name)
                TextField("Surname", text: $surname)
                TextField("License number", text: $licenseNumber)

                Picker("Role", selection: $role) {
                    ForEach(CrewRole.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
            }

            Section("Recencies (Yes/No)") {
                Toggle("Line training record", isOn: $lineTrainingRecord)
                Toggle("Line training report", isOn: $lineTrainingReport)
                Toggle("Induction checklist", isOn: $inductionChecklist)
                Toggle("CV", isOn: $cv)
                Toggle("Personal data sheet", isOn: $personalDataSheet)
                Toggle("Drug and alcohol policy", isOn: $drugAndAlcoholPolicy)
                Toggle("Internet usage policy", isOn: $internetUsagePolicy)
            }

            Section("Training (Last conducted + Expiry)") {
                ForEach(TrainingType.allCases) { t in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t.rawValue).font(.headline)

                        OptionalDatePicker(
                            title: "Last conducted",
                            date: Binding(
                                get: { lastConducted[t] ?? nil },
                                set: { lastConducted[t] = $0 }
                            )
                        )

                        OptionalDatePicker(
                            title: "Expiry date",
                            date: Binding(
                                get: { expiry[t] ?? nil },
                                set: { expiry[t] = $0 }
                            )
                        )
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        surname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
            }
        }
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        for t in TrainingType.allCases {
            lastConducted[t] = nil
            expiry[t] = nil
        }

        guard case .edit(let member) = mode else { return }

        name = member.name
        surname = member.surname
        licenseNumber = member.licenseNumber
        role = member.role

        lineTrainingRecord = member.lineTrainingRecord
        lineTrainingReport = member.lineTrainingReport
        inductionChecklist = member.inductionChecklist
        cv = member.cv
        personalDataSheet = member.personalDataSheet
        drugAndAlcoholPolicy = member.drugAndAlcoholPolicy
        internetUsagePolicy = member.internetUsagePolicy

        for tr in member.trainings {
            if let t = TrainingType(rawValue: tr.typeRaw) {
                lastConducted[t] = tr.lastConducted
                expiry[t] = tr.expiry
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSurname = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLicense = licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        let member: CrewMember
        switch mode {
        case .add:
            member = CrewMember()
            modelContext.insert(member)
        case .edit(let existing):
            member = existing
        }

        member.name = trimmedName
        member.surname = trimmedSurname
        member.licenseNumber = trimmedLicense
        member.role = role

        member.lineTrainingRecord = lineTrainingRecord
        member.lineTrainingReport = lineTrainingReport
        member.inductionChecklist = inductionChecklist
        member.cv = cv
        member.personalDataSheet = personalDataSheet
        member.drugAndAlcoholPolicy = drugAndAlcoholPolicy
        member.internetUsagePolicy = internetUsagePolicy

        var existingByType: [String: TrainingRecord] = [:]
        for tr in member.trainings { existingByType[tr.typeRaw] = tr }

        for t in TrainingType.allCases {
            let lc = lastConducted[t] ?? nil
            let ex = expiry[t] ?? nil
            let shouldHaveRow = (lc != nil) || (ex != nil)
            let key = t.rawValue

            if shouldHaveRow {
                if let row = existingByType[key] {
                    row.lastConducted = lc
                    row.expiry = ex
                } else {
                    member.trainings.append(
                        TrainingRecord(type: t, lastConducted: lc, expiry: ex)
                    )
                }
            } else {
                if let row = existingByType[key],
                   let idx = member.trainings.firstIndex(where: { $0 === row }) {
                    member.trainings.remove(at: idx)
                    modelContext.delete(row)
                }
            }
        }

        do {
            let preSave = (try? modelContext.fetchCount(FetchDescriptor<CrewMember>())) ?? -1
            print("🔎 After insert, before save, crew count:", preSave)

            try modelContext.save()

            let postSave = (try? modelContext.fetchCount(FetchDescriptor<CrewMember>())) ?? -1
            print("✅ After save, crew count:", postSave)

            dismiss()
        } catch {
            print("❌ Crew save failed:", error)
        }
    }
}

#Preview {
    NavigationStack { CrewFormView(mode: .add) }
        .modelContainer(for: [CrewMember.self, TrainingRecord.self], inMemory: true)
}
