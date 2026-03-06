import SwiftUI

struct NumberRow: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 110, alignment: .leading)

            TextField("", text: $text)
                .padding(8)
                .frame(width: 100)
                .background(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.4))
                )
        }
    }
}

struct DisplayRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .padding(8)
                .frame(width: 100)
                .background(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.4))
                )
        }
    }
}
