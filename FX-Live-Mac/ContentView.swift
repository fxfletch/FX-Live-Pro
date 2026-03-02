//
//  ContentView.swift
//  FX-Live-Mac
//
//  Main window layout with sidebar navigation
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: SidebarTab = .perform
    
    enum SidebarTab: String, CaseIterable, Identifiable {
        case shows = "Shows"
        case design = "Design"
        case perform = "Perform"
        case music = "Music"
        case files = "Files"
        case settings = "Settings"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .shows: return "folder.fill"
            case .design: return "paintbrush.fill"
            case .perform: return "play.circle.fill"
            case .music: return "music.note.list"
            case .files: return "doc.fill"
            case .settings: return "gearshape.fill"
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
                    MacShowsView()
                case .design:
                    MacDesignView()
                case .perform:
                    MacPerformView()
                case .music:
                    MacMusicView()
                case .files:
                    MacFilesView()
                case .settings:
                    MacSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
