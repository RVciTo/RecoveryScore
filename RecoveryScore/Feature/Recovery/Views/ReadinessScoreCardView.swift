//
//  ReadinessScoreCardView.swift
//  RecoveryScore
//

import SwiftUI

struct ReadinessScoreCardView: View {
    let readinessScore: Int?
    @Binding var showExplanation: Bool
    @ObservedObject var viewModel: RecoveryBiometricsViewModel
    

    var body: some View {

        if let score = readinessScore {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Readiness")
                            .font(.headline)
                        // Pill label
                        Text(qualitativeLabel(for: score))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                    Spacer()
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(score >= 80 ? .green : (score >= 60 ? .orange : .red))
                        .accessibilityLabel("Readiness score \(score)")
                }

                // Subtitle
                Text("Based on your last 7 days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Sparkline trend
                if !viewModel.readinessTrend.isEmpty {
                    SparklineView(values: viewModel.readinessTrend)
                        .frame(height: 28)
                        .padding(.top, 2)
                }

                // Delta chip
                if viewModel.readinessTrend.count >= 2 {
                    let last = viewModel.readinessTrend.last ?? 0
                    let prev = viewModel.readinessTrend.dropLast().last ?? 0
                    let d = last - prev
                    Text(String(format: "Δ %@%.0f vs yesterday", (d >= 0 ? "+" : "−"), abs(d)))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(d >= 0 ? .green : .red)
                }
                if let msg = viewModel.trendEmptyMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            // Loading state
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Readiness").font(.headline)
                    Spacer()
                }
                ProgressView().progressViewStyle(.circular)
                    .frame(height: 24)
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }

}

    private func qualitativeLabel(for score: Int) -> String {
        switch score {
        case ..<40: return "Bad"
        case 40..<55: return "Medium Low"
        case 55..<70: return "Normal"
        case 70..<85: return "Medium High"
        default: return "High"
        }
    }
    
}
