import SwiftUI

struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?

    @State private var enabled: Bool = false
    @State private var internalDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: Binding(
                get: { enabled },
                set: { newValue in
                    enabled = newValue
                    if newValue {
                        if date == nil { date = internalDate }
                    } else {
                        date = nil
                    }
                }
            ))

            if enabled {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date ?? internalDate },
                        set: { newValue in
                            internalDate = newValue
                            date = newValue
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }
        }
        .onAppear {
            enabled = (date != nil)
            if let d = date { internalDate = d }
        }
    }
}
