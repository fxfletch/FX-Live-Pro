//
//  MacShowsView.swift
//  FX-Live-Mac
//
//  Shows management view for macOS
//

import SwiftUI

struct MacShowsView: View {
    @Binding var showLoaded: Bool
    @State private var shows: [String] = []
    @State private var selectedShow: String?
    @State private var showingNewShowAlert = false
    @State private var newShowName = ""
    
    var body: some View {
        HSplitView {
            // Show list
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text("SHOWS")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { showingNewShowAlert = true }) {
                        Image(systemName: "plus")
                    }
                    Button(action: deleteSelectedShow) {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedShow == nil)
                }
                .padding()
                
                Divider()
                
                List(shows, id: \.self, selection: $selectedShow) { show in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(show)
                                .font(.body)
                        }
                    }
                    .tag(show)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            .frame(minWidth: 250, maxWidth: 350)
            
            // Show detail / actions
            VStack(spacing: 20) {
                if let selected = selectedShow {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text(selected)
                        .font(.title)
                    
                    HStack(spacing: 16) {
                        Button("Load Show") {
                            loadShow(selected)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button("Export Archive") {
                            // TODO: Export functionality
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    
                    if showLoaded && settings.currentShow == selected {
                        Label("Currently Loaded", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                    }
                } else {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Select a show")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("New Show", isPresented: $showingNewShowAlert) {
            TextField("Show Name", text: $newShowName)
            Button("Create") {
                if !newShowName.isEmpty {
                    fx.createShow(newShowName)
                    newShowName = ""
                    refreshShowList()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a name for the new show")
        }
        .onAppear {
            refreshShowList()
        }
    }
    
    private func refreshShowList() {
        fx.getLocalShows("")
        shows = fx.showList
    }
    
    private func loadShow(_ name: String) {
        fx.selectShow(name)
        settings.currentShow = name
        settings.save()
        showLoaded = true
    }
    
    private func deleteSelectedShow() {
        guard let show = selectedShow else { return }
        fx.deleteShow(show)
        selectedShow = nil
        refreshShowList()
    }
}
