//  RecoveryBiometricsSectionView.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 01/08/2025.
//

import SwiftUI

struct RecoveryBiometricsSectionView: View {
    let viewModel: RecoveryBiometricsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Heart Rate Variability
            MetricCard(
                icon: "💓",
                title: "Heart Rate Variability",
                value: viewModel.hrv.map { String(format: "%.1f ms", $0.0) } ?? "Loading…",
                subtitle: viewModel.hrv.map { _, date in date.formatted(date: .abbreviated, time: .shortened) }
            )
            
            // Resting Heart Rate
            MetricCard(
                icon: "🫀",
                title: "Resting Heart Rate",
                value: viewModel.rhr.map { String(format: "%.0f bpm", $0.0) } ?? "Loading…",
                subtitle: viewModel.rhr.map { _, date in date.formatted(date: .abbreviated, time: .shortened) }
            )
            
            // HR Recovery
            MetricCard(
                icon: "📉",
                title: "HR Recovery",
                value: viewModel.hrr.map { String(format: "%.0f bpm", $0.0) } ?? "Loading…",
                subtitle: viewModel.hrr.map { _, date in date.formatted(date: .abbreviated, time: .shortened) }
            )
            
            // Respiratory Rate
            MetricCard(
                icon: "🌬",
                title: "Respiratory Rate",
                value: viewModel.respiratoryRate.map { String(format: "%.1f br/min", $0.0) } ?? "Loading…",
                subtitle: viewModel.respiratoryRate.map { _, date in date.formatted(date: .abbreviated, time: .shortened) }
            )
            
            // Wrist Temperature
            MetricCard(
                icon: "🌡",
                title: "Wrist Temperature",
                value: viewModel.wristTemp.map { String(format: "%.2f °C", $0.0) } ?? "Loading…",
                subtitle: viewModel.wristTemp.map { _, date in date.formatted(date: .abbreviated, time: .shortened) }
            )
            
            // Oxygen Saturation
            MetricCard(
                icon: "🫁",
                title: "O₂ Saturation",
                value: viewModel.oxygenSaturation.map { String(format: "%.1f %%", $0.0 * 100) } ?? "Loading…",
                subtitle: viewModel.oxygenSaturation.map { _, date in date.formatted(date: .abbreviated, time: .shortened) }
            )
            
            // Active Energy
            MetricCard(
                icon: "🔥",
                title: "Active Energy",
                value: viewModel.activeEnergyBurned.map { String(format: "%.0f kcal", $0.0) } ?? "Loading…",
                subtitle: viewModel.activeEnergyBurned.map { value, date in
                    "in last 24h (as of \(date.formatted(date: .abbreviated, time: .shortened)))"
                }
            )
            
            // Mindful Minutes
            MetricCard(
                icon: "🧘",
                title: "Mindful Minutes",
                value: viewModel.mindfulMinutes.map { String(format: "%.0f min", $0.0) } ?? "Loading…",
                subtitle: viewModel.mindfulMinutes.map { count, date in
                    "in last 24h (as of \(date.formatted(date: .abbreviated, time: .shortened)))"
                }
            )
            
            // Time Asleep
            MetricCard(
                icon: "😴",
                title: "Time Asleep",
                value: viewModel.sleepInfo.map { sleep in
                    String(format: "%.1f hrs", sleep.0)
                } ?? "Loading…",
                subtitle: viewModel.sleepInfo.map { sleep in
                    "In Bed: \(String(format: "%.1f hrs", sleep.1))"
                }
            )

            // Sleep Stages
            if let sleep = viewModel.sleepInfo {
                ForEach(sleep.4.sorted(by: { $0.key < $1.key }), id: \.key) { phase, hours in
                    MetricCard(
                        icon: "🌙",
                        title: "Sleep Phase: \(phase)",
                        value: String(format: "%.1f hrs", hours),
                        subtitle: nil
                    )
                }
            }
        }
        .padding()
    }
    
    private struct MetricCard: View {
        let icon: String
        let title: String
        let value: String
        let subtitle: String?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    Text(icon)
                        .font(.title)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                        Text(value)
                            .font(.title3)
                            .fontWeight(.semibold)
                        if let subtitle = subtitle {
                            Text("↳ \(subtitle)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
        }
    }
}
