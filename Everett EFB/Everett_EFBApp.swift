//
//  Everett_EFBApp.swift
//  Everett EFB
//
//  Created by Hendrik Adriaan Lamprecht on 4/3/26.
//

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
                Airport.self
            ]
        )
    }
}
