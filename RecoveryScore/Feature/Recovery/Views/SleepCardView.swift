//
//  SleepCardView.swift
//  RecoveryScore
//

import SwiftUI

struct SleepCardView: View {
    @ObservedObject var viewModel: RecoveryBiometricsViewModel

    var body: some View {
        if let sl = viewModel.sleepInfo {
            let total = sl.0
            let inBed = sl.1
            let end   = sl.3
            let stages = sl.4
            let core = stages["Core"] ?? 0
            let rem  = stages["REM"]  ?? 0
            let deep = stages["Deep"] ?? 0
            let awake = max(0, inBed - total)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sleep").font(.headline)
                    Spacer()
                    Text(String(format: "%.1f h total", total))
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                // Segmented bar for Core / REM / Deep
                SegmentedBar(
                    segments: [
                        .init(value: core, color: .blue, label: "Core"),
                        .init(value: rem,  color: .purple, label: "REM"),
                        .init(value: deep, color: .indigo, label: "Deep")
                    ],
                    total: max(total, 0.1)
                )
                .frame(height: 12)

                // Legend & thresholds
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 16) {
                        LegendDot(color: .blue, text: String(format: "Core %.1f h", core))
                        LegendDot(color: .purple, text: String(format: "REM %.1f h", rem))
                        LegendDot(color: .indigo, text: String(format: "Deep %.1f h", deep))
                    }
                    HStack(spacing: 0) {
                        if inBed > 0 || awake > 0 {
                            Text(String(format: "In-bed: %.1f h • Awake: %.1f h • ", inBed, awake))
                        }
                        Text("Ended at \(shortTime(end))")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    Text("Goal: 7 h • Deep ≥ 1 h")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Threshold badges
                HStack(spacing: 8) {
                    if deep < 1.0 {
                        Badge(text: "Deep < 1 h — reduces readiness", color: .red)
                    }
                    if total < 7.0 {
                        Badge(text: "Total < 7 h — less recovery", color: .orange)
                    }
                }
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct LegendDot: View {
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.footnote)
        }
    }
}

private struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: color == .red ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .imageScale(.small)
            Text(text).font(.footnote)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05), in: Capsule())
    }
}

private struct SegmentedBar: View {
    struct Segment { let value: Double; let color: Color; let label: String }
    let segments: [Segment]
    let total: Double

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segments.indices, id: \.self) { i in
                    let width = max(0, segments[i].value / max(total, 0.001)) * geo.size.width
                    Rectangle()
                        .fill(segments[i].color.opacity(0.8))
                        .frame(width: width)
                }
            }
        }
    }
}
// Helper to format time as short string
private func shortTime(_ date: Date) -> String {
    let df = DateFormatter()
    df.timeStyle = .short
    df.dateStyle = .none
    return df.string(from: date)
}
