import SwiftUI

struct FlightsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Flights")
                .font(.title)
                .bold()
            Text("Flight creation and multi-leg sectors will be built here.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle("Flights")
    }
}

#Preview {
    NavigationStack { FlightsView() }
}
