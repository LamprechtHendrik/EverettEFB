import SwiftUI
import SwiftData

struct ContentView: View {
    
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                LogoView()

                Text("Everett EFB")
                    .font(.largeTitle)
                    .bold()

                Text("Choose a module")
                    .foregroundStyle(.secondary)

                VStack(spacing: 14) {
                    NavigationLink {
                        FlightsHomeView()
                    } label: {
                        HomeButton(title: "Flights", subtitle: "Create and manage flights", systemImage: "airplane")
                    }

                    NavigationLink {
                        ReportsHomeView()
                    } label: {
                        HomeButton(title: "Reports", subtitle: "Generate and review reports", systemImage: "doc.text")
                    }

                    NavigationLink {
                        DataHomeView()
                    } label: {
                        HomeButton(title: "Data", subtitle: "Crew, aircraft, airports, docs", systemImage: "tray.full")
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 24)
            }
            .padding()
            .navigationTitle("Home")
        }
        .onAppear {
            AirportSeeder.seedIfNeeded(modelContext: modelContext)
        }
    }
}

private struct HomeButton: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

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
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FlightsHomeView: View {
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

struct ReportsHomeView: View {
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
    ContentView()
}
