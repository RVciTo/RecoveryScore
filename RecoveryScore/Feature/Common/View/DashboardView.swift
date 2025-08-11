//
//  DashboardView.swift
//  RecoveryScore
//

import SwiftUI
import UIKit
import UIKit

struct DashboardView: View {
    @ObservedObject var viewModel: RecoveryBiometricsViewModel
    @State private var authStatusText: String = "Checking…"
    @State private var isAuthorized: Bool = false
    @State private var showReadinessExplanation: Bool = false
    private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isAuthorized {
                        if let error = viewModel.errorMessage {
                        BannerView(text: error, style: .red)
                    } else if let warn = viewModel.warningMessage {
                        BannerView(text: warn, style: .orange)
                    }
                    ReadinessScoreCardView(
                        readinessScore: viewModel.readinessScore,
                        showExplanation: $showReadinessExplanation,
                        viewModel: viewModel
                    )
                    DriversCardView(viewModel: viewModel)
                        

                        // Metric grid
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            // HRV (baseline metric, higher helps)
                            if let hrv = viewModel.hrv {
                                MetricChipView(
                                    title: "HRV",
                                    value: String(format: "%.0f ms", hrv.0),
                                    subvalue: viewModel.hrvBaseline != nil ? String(format: "Baseline: %.0f ms", viewModel.hrvBaseline!) : "Baseline building…",
                                    deltaText: (viewModel.hrvBaseline ?? 0) > 0 ? {
                                        let base = viewModel.hrvBaseline!
                                        let dp = ((hrv.0 - base) / base) * 100
                                        return String(format: "%@%.0f%%", (dp >= 0 ? "+" : "−"), abs(dp))
                                    }() : nil,
                                    systemImage: "waveform.path.ecg",
                                    tint: {
                                        let base = viewModel.hrvBaseline ?? 0
                                        let dp = base > 0 ? ((hrv.0 - base) / base) * 100 : 0
                                        return dp >= 3 ? .green : (dp <= -3 ? .red : .secondary)
                                    }(),
                                    timestamp: shortTime(hrv.1)
                                )
                            }
                            // Resting HR (baseline metric, lower helps)
                            if let rhr = viewModel.rhr {
                                MetricChipView(
                                    title: "Resting HR",
                                    value: String(format: "%.0f bpm", rhr.0),
                                    subvalue: viewModel.rhrBaseline != nil ? String(format: "Baseline: %.0f bpm", viewModel.rhrBaseline!) : "Baseline building…",
                                    deltaText: (viewModel.rhrBaseline ?? 0) > 0 ? {
                                        let base = viewModel.rhrBaseline!
                                        let pct = ((rhr.0 - base) / base) * 100
                                        return String(format: "%@%.0f%%", (pct >= 0 ? "+" : "−"), abs(pct))
                                    }() : nil,
                                    systemImage: "heart.fill",
                                    tint: {
                                        let base = viewModel.rhrBaseline ?? 0
                                        let pct = base > 0 ? ((rhr.0 - base) / base) * 100 : 0
                                        return pct <= -3 ? .green : (pct >= 3 ? .red : .secondary)
                                    }(),
                                    timestamp: shortTime(rhr.1)
                                )
                            }
                            // HR Recovery (baseline metric, higher helps)
                            if let hrr = viewModel.hrr {
                                MetricChipView(
                                    title: "HR Recovery",
                                    value: String(format: "%.0f bpm", hrr.0),
                                    subvalue: viewModel.hrrBaseline != nil ? String(format: "Baseline: %.0f bpm", viewModel.hrrBaseline!) : "Baseline building…",
                                    deltaText: viewModel.hrrBaseline != nil ? {
                                        let diff = hrr.0 - viewModel.hrrBaseline!
                                        return String(format: "%@%.0f bpm", (diff >= 0 ? "+" : "−"), abs(diff))
                                    }() : nil,
                                    systemImage: "arrow.triangle.2.circlepath.heart",
                                    tint: {
                                        let diff = (viewModel.hrrBaseline != nil) ? (hrr.0 - viewModel.hrrBaseline!) : 0
                                        return diff >= 3 ? .green : (diff <= -3 ? .red : .secondary)
                                    }(),
                                    timestamp: shortTime(hrr.1)
                                )
                            }
                            // Respiratory Rate (baseline metric, lower helps)
                            if let rr = viewModel.respiratoryRate {
                                MetricChipView(
                                    title: "Resp. Rate",
                                    value: String(format: "%.1f br/min", rr.0),
                                    subvalue: viewModel.respiratoryBaseline != nil ? String(format: "Baseline: %.1f br/min", viewModel.respiratoryBaseline!) : "Baseline building…",
                                    deltaText: viewModel.respiratoryBaseline != nil ? {
                                        let diff = rr.0 - viewModel.respiratoryBaseline!
                                        return String(format: "%@%.1f", (diff >= 0 ? "+" : "−"), abs(diff))
                                    }() : nil,
                                    systemImage: "lungs.fill",
                                    tint: {
                                        let diff = viewModel.respiratoryBaseline != nil ? rr.0 - viewModel.respiratoryBaseline! : 0
                                        return diff <= -1 ? .green : (diff >= 1 ? .red : .secondary)
                                    }(),
                                    timestamp: shortTime(rr.1)
                                )
                            }
                            // Wrist Temperature (baseline, deviation hurts)
                            if let wt = viewModel.wristTemp {
                                MetricChipView(
                                    title: "Wrist Temp",
                                    value: String(format: "%.2f °C", wt.0),
                                    subvalue: viewModel.wristTempBaseline != nil ? String(format: "Baseline: %.2f °C", viewModel.wristTempBaseline!) : "Baseline building…",
                                    deltaText: viewModel.wristTempBaseline != nil ? {
                                        let dev = abs(wt.0 - viewModel.wristTempBaseline!)
                                        return String(format: "+%.2f °C dev", dev)
                                    }() : nil,
                                    systemImage: "thermometer",
                                    tint: {
                                        let dev = viewModel.wristTempBaseline != nil ? abs(wt.0 - viewModel.wristTempBaseline!) : 0
                                        return dev >= 0.3 ? .red : .secondary
                                    }(),
                                    timestamp: shortTime(wt.1)
                                )
                            }
                            // O₂ Saturation (standard)
                            if let o2 = viewModel.oxygenSaturation {
                                MetricChipView(
                                    title: "O₂",
                                    value: String(format: "%.0f %%", (o2.0 <= 1.0) ? o2.0 * 100.0 : o2.0),
                                    subvalue: "Optimal: 95–100%",
                                    deltaText: nil,
                                    systemImage: "lungs.fill",
                                    tint: ((o2.0 <= 1.0) ? o2.0 * 100.0 : o2.0) < 95 ? .red : .secondary,
                                    timestamp: shortTime(o2.1)
                                )
                            }
                            // Active Energy (standard categories)
                            if let en = viewModel.activeEnergyBurned {
                                MetricChipView(
                                    title: "Active Energy",
                                    value: String(format: "%d kcal", Int(en.0)),
                                    subvalue: "Goal: ≥ 400 kcal",
                                    deltaText: (en.0 < 400 ? "Low activity" : (en.0 < 800 ? "Moderate" : (en.0 < 1200 ? "High" : "Very high"))),
                                    systemImage: "flame.fill",
                                    tint: (en.0 < 800 ? .secondary : .orange),
                                    timestamp: shortTime(en.1)
                                )
                            }
                            // Mindful Minutes (standard)
                            if let mm = viewModel.mindfulMinutes {
                                MetricChipView(
                                    title: "Mindfulness",
                                    value: String(format: "%d min", Int(mm.0)),
                                    subvalue: "Goal: ≥ 10 min",
                                    deltaText: mm.0 >= 10 ? "Supports recovery" : "Try a short session",
                                    systemImage: "brain.head.profile",
                                    tint: (mm.0 >= 10 ? .green : .secondary),
                                    timestamp: shortTime(mm.1)
                                )
                            }
                        }

                        // Sleep card
                        if viewModel.sleepInfo != nil {
                            SleepCardView(viewModel: viewModel)
                        }
                        // Messages
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.leading)
                        } else if let warn = viewModel.warningMessage {
                            Text(warn)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.leading)
                        }

                        // Explanation moved to Help screen

                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Please grant Health permission")
                                .font(.headline)
                            Text(authStatusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            NavigationLink(destination: PermissionsView()) {
                                Text("Open Settings")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding()
                .onChange(of: viewModel.readinessScore, initial: false) { oldValue, newValue in
                    guard oldValue != newValue, newValue != nil else { return }
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                }
            }
            .navigationTitle("Dashboard")
            .task {
                await refreshAuthorizationAndLoad()
            }
            .onAppear {
                Task { await refreshAuthorizationAndLoad() }
            }
        }
    }

    private func refreshAuthorizationAndLoad() async {
        // ✅ Call the instance method, NOT the property-wrapper.
        await viewModel.refreshAuthorization()

        await MainActor.run {
            self.isAuthorized = viewModel.isAuthorized
            self.authStatusText = viewModel.isAuthorized ? "Authorized" : "Not determined"
        }

        if viewModel.isAuthorized {
            await viewModel.loadAllMetrics()
        }
    }
}


struct BannerView: View {
    let text: String
    let style: Color
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: style == .red ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .imageScale(.medium)
            Text(text).font(.subheadline)
        }
        .foregroundStyle(style)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private func shortTime(_ date: Date) -> String {
    let df = DateFormatter()
    df.timeStyle = .short
    df.dateStyle = .none
    return df.string(from: date)
}


struct BaselineStatusView: View {
    @ObservedObject var viewModel: RecoveryBiometricsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Baselines status").font(.headline)
                Spacer()
                Text("\(viewModel.baselineReadyCount)/\(viewModel.baselineTotalCount)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if viewModel.baselineReadyCount < viewModel.baselineTotalCount {
                Text("Collecting 7 days of data while you wear Apple Watch.").font(.footnote).foregroundStyle(.secondary)
                if !viewModel.missingBaselineNames.isEmpty {
                    Text("Missing: " + viewModel.missingBaselineNames.joined(separator: ", ")).font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text("All baselines ready.").font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button {
                    if let url = URL(string: "x-apple-health://sources") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Health App", systemImage: "heart.text.square")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

