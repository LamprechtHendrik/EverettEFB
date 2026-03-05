import SwiftUI

struct DocumentListView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Document Database")
                .font(.title)
            Text("Tracked documents and uploads will live here.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle("Documents")
    }
}//
//  DataModules.swift
//  Everett EFB
//
//  Created by Hendrik Adriaan Lamprecht on 4/3/26.
//

