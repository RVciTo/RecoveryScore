//
//  PermissionsView.swift (Help)
//  RecoveryScore
//
//  A compact “Help” screen: manage Health access, see baselines, and learn how the score works.
//

import SwiftUI
import HealthKit
import UIKit

struct PermissionsView: View {
    @State private var statusText: String = "Not determined"
    @State private var canRequest: Bool = true
    @State private var showGuide: Bool = false
    @State private var baselines: BaselineData? = nil
    @State private var isLoadingBaselines: Bool = false

    private let healthStore = HealthDataStore.shared
    private let hk = HKHealthStore()

    var body: some View {
        List {
            // Section: Health Access
            Section(header: Text("Health Access")) {
                HStack {
                    Image(systemName: canRequest ? "exclamationmark.triangle" : "checkmark.seal.fill")
                        .foregroundStyle(canRequest ? .orange : .green)
                    Text(statusText)
                    Spacer()
                }

                Button {
                    showGuide = true
                } label: {
                    Label("Manage Health Permissions", systemImage: "heart.text.square")
                }

                Button {
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Health App", systemImage: "square.and.arrow.up")
                }
                .foregroundColor(.primary)

                if !canRequest {
                    Text("Need to adjust access? Tap **Manage Health Permissions** for a short guide, then make changes in the Health app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Section: Baselines (computed by app, not stored in Health)
            Section(header: Text("Baselines")) {
                if isLoadingBaselines {
                    ProgressView("Computing baselines…")
                } else if let b = baselines {
                    BaselineRow(name: "HRV", value: b.averageHRV, unit: "ms", ready: b.averageHRV > 0)
                    BaselineRow(name: "Resting HR", value: b.averageRHR, unit: "bpm", ready: b.averageRHR > 0)
                    BaselineRow(name: "HR Recovery", value: b.averageHRR, unit: "bpm", ready: b.averageHRR > 0)
                    BaselineRow(name: "Resp. Rate", value: b.averageRespiratoryRate, unit: "br/min", ready: b.averageRespiratoryRate > 0)
                    BaselineRow(name: "Wrist Temp", value: b.averageWristTemp, unit: "°C", ready: b.averageWristTemp > 0)
                    Text("Baselines are computed by RecoveryScore as 7‑day averages from your Health data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No baselines yet. Wear your Apple Watch for a few days and come back.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Section: How your score works
            Section(header: Text("How your score works")) {
                Label("Personal baselines: HRV ↑, Resting HR ↓, HR Recovery ↑", systemImage: "person.fill.checkmark")
                Label("Sleep targets: 7 h total • Deep ≥ 1 h", systemImage: "bed.double.fill")
                Label("Resp. rate close to your baseline", systemImage: "lungs.fill")
                Label("O₂ saturation 95–100%", systemImage: "waveform.path.ecg.rectangle")
                Label("Mindfulness helps; very high activity can reduce recovery", systemImage: "brain.head.profile")
            }
        }
        .navigationTitle("Help")
        .onAppear {
            Task { await refreshStatus(); await computeBaselines() }
        }
        .sheet(isPresented: $showGuide) {
            HealthGuideSheet()
        }
    }

    private func requestedTypes() -> [HKObjectType] {
        var types: [HKObjectType] = []
        let qtyIds: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .heartRate,
            .respiratoryRate,
            .oxygenSaturation,
            .activeEnergyBurned
        ]
        for id in qtyIds {
            if let t = HKObjectType.quantityType(forIdentifier: id) { types.append(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.append(sleep) }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { types.append(mindful) }
        types.append(HKObjectType.workoutType())
        return types
    }

    @MainActor
    private func refreshStatus() async {
        let types = Set(requestedTypes())
        hk.getRequestStatusForAuthorization(toShare: [], read: types) { status, error in
            Task { @MainActor in
                if let _ = error {
                    self.statusText = "Unknown"
                    self.canRequest = true
                    return
                }
                switch status {
                case .unnecessary:
                    // Reading these types has already been authorized (or doesn’t require auth)
                    self.statusText = "Authorized"
                    self.canRequest = false
                case .shouldRequest:
                    // One or more types still need to be requested
                    self.statusText = "Not granted"
                    self.canRequest = true
                case .unknown:
                    fallthrough
                @unknown default:
                    self.statusText = "Unknown"
                    self.canRequest = true
                }
            }
        }
    }

    private func computeBaselines() async {
        await MainActor.run { isLoadingBaselines = true }
        let calc = BaselineCalculator()
        let data = await calc.calculateBaseline()
        await MainActor.run {
            self.baselines = data
            self.isLoadingBaselines = false
        }
    }
}

// MARK: - BaselineRow

private struct BaselineRow: View {
    let name: String
    let value: Double
    let unit: String
    let ready: Bool

    var body: some View {
        HStack {
            Image(systemName: ready ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                .foregroundStyle(ready ? .green : .orange)
            Text(name)
            Spacer()
            if value > 0 {
                Text(value == floor(value) ? String(format: "%.0f %@", value, unit) : String(format: "%.1f %@", value, unit))
                    .foregroundStyle(.secondary)
            } else {
                Text("Collecting…").foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - HealthGuideSheet

private struct HealthGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Enable in Health")) {
                    Label("Open the Health app", systemImage: "app.fill")
                    Label("Profile → Privacy → Apps", systemImage: "person.crop.circle.badge.checkmark")
                    Label("Select **RecoveryScore**", systemImage: "heart.text.square")
                    Label("Allow: HRV, Heart Rate, Resting HR, Resp. Rate, O₂, Sleep, Active Energy, Mindful Minutes, Wrist Temp, Workouts", systemImage: "checkmark.seal")
                }
                Section(header: Text("Tip")) {
                    Text("You can also tap **Manage Health Permissions** here to re-open the system sheet and grant access without hunting through the Health app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Health access guide")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
