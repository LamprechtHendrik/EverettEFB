import SwiftUI

struct ReportsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Reports")
                .font(.title)
                .bold()
            Text("PDF generation, sign-off, and read-only archiving will be built here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle("Reports")
    }
}

#Preview {
    NavigationStack { ReportsView() }
}
