//
//  RecoveryBiometricsView.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 26/07/2025.
//

import SwiftUI
import HealthKit

struct RecoveryBiometricsView: View {
    @ObservedObject var viewModel: RecoveryBiometricsViewModel
    @Binding var showReadinessExplanation: Bool
    
    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 16) {
                    ReadinessScoreCardView(
                        readinessScore: viewModel.readinessScore,
                        showExplanation: $showReadinessExplanation,
                        viewModel: viewModel
                    )

                    RecoveryBiometricsSectionView(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Readiness Overview")
        .navigationBarTitleDisplayMode(.inline)
        .accentColor(.blue)
    }
}
