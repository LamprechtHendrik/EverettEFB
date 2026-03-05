import SwiftUI

struct DataHomeView: View {
    var body: some View {
        List {
            Section("Databases") {
                NavigationLink {
                    CrewListView()
                } label: {
                    Label("Crew", systemImage: "person.3")
                }

                NavigationLink {
                    AircraftListView()
                } label: {
                    Label("Aircraft", systemImage: "airplane")
                }

                NavigationLink {
                    AirportListView()
                } label: {
                    Label("Airports", systemImage: "building.2")
                }

                NavigationLink {
                    DocumentListView()
                } label: {
                    Label("Documents", systemImage: "doc.text")
                }
            }
        }
        .navigationTitle("Data")
    }
}

#Preview {
    NavigationStack { DataHomeView() }
}//
//  DataHomeView.swift
//  Everett EFB
//
//  Created by Hendrik Adriaan Lamprecht on 4/3/26.
//

