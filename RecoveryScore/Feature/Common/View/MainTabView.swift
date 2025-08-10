//
//  MainTabView.swift
//  RecoveryScore
//

import SwiftUI

@MainActor
struct MainTabView: View {
    @StateObject private var viewModel = MainTabViewModel()

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {

            // Tab 1: Dashboard (default)
            NavigationStack {
                DashboardView(viewModel: viewModel.recoveryBiometricsViewModel)
            }
            .tabItem {
                Label("Dashboard", systemImage: "gauge")
            }
            .tag(MainTabViewModel.Tab.dashboard)

            // Tab 2: Settings / Permissions
            NavigationStack {
                PermissionsView()
            }
            .tabItem {
                Label("Help", systemImage: "questionmark.circle")
            }
            .tag(MainTabViewModel.Tab.settings)
        }
    }
}
