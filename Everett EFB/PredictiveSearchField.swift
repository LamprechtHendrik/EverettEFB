import SwiftUI

struct PredictiveSearchField<Item: Identifiable>: View {
    let title: String
    @Binding var text: String
    let suggestions: [Item]
    let displayText: (Item) -> String
    let secondaryText: ((Item) -> String?)?
    let onSelect: (Item) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(title, text: $text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onTapGesture {
                    isExpanded = true
                }
                .onChange(of: text) { _, newValue in
                    isExpanded = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }

            if isExpanded && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { item in
                        Button {
                            onSelect(item)
                            text = displayText(item)
                            isExpanded = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayText(item))
                                    .foregroundStyle(.primary)

                                if let secondary = secondaryText?(item), !secondary.isEmpty {
                                    Text(secondary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }
                }
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
