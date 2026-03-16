import SwiftUI
import SwiftData

@main
struct Everett_EFBApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(
            for: [
                CrewMember.self,
                TrainingRecord.self,
                Aircraft.self,
                AircraftDocument.self,
                Airport.self,
                Flight.self,
                FlightLeg.self,
                LegDocument.self,
                FlightDaySign.self,
                LegDelayEntry.self
                
            ]
        )
    }
}
