//
//  ContentView.swift
//  FX-Live-Mac
//
//  Main window layout with sidebar navigation
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: SidebarTab = .shows
    @State private var showLoaded = false
    
    enum SidebarTab: String, CaseIterable, Identifiable {
        case shows = "Shows"
        case design = "Design"
        case perform = "Perform"
        case music = "Music"
        case files = "Files"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .shows: return "folder.fill"
            case .design: return "paintbrush.fill"
            case .perform: return "play.circle.fill"
            case .music: return "music.note.list"
            case .files: return "doc.fill"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationTitle("FX Live")
            .frame(minWidth: 160)
        } detail: {
            Group {
                switch selectedTab {
                case .shows:
                    MacShowsView(showLoaded: $showLoaded)
                case .design:
                    if showLoaded {
                        MacDesignView()
                    } else {
                        noShowLoadedView
                    }
                case .perform:
                    if showLoaded {
                        MacPerformView()
                    } else {
                        noShowLoadedView
                    }
                case .music:
                    if showLoaded {
                        MacMusicView()
                    } else {
                        noShowLoadedView
                    }
                case .files:
                    MacFilesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if settings.load() {
                fx.selectShow(settings.currentShow)
                showLoaded = true
            }
        }
    }
    
    private var noShowLoadedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No Show Loaded")
                .font(.title)
                .foregroundColor(.secondary)
            Text("Select a show from the Shows tab to get started")
                .foregroundColor(.secondary.opacity(0.7))
            Button("Go to Shows") {
                selectedTab = .shows
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
