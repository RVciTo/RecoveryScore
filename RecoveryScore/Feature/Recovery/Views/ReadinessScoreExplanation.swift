//
//  Views/ReadinessScoreExplanation.swift
//  RecoveryScore
//
//  Created by Frova Hervé on 26/07/2025.
//

//  NOTE
//  ────
//  • This view now relies on a single @ObservedObject -— `RecoveryBiometricsViewModel` —
//    instead of a long list of @Binding values.
//  • Open it from anywhere like this:
//
//        NavigationLink(
//            destination: ReadinessScoreExplanation(viewModel: myViewModel)
//        ) { … }
//
//  • All metrics, baselines, and the readiness score itself are read directly
//    from the shared view-model.
//

import SwiftUI

struct ReadinessScoreExplanation: View {
    // Single source of truth for all biometrics and baselines
    @ObservedObject var viewModel: RecoveryBiometricsViewModel
    
    // Allows the “Close” button to dismiss a sheet / push
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Title
                Text("🔍 Readiness Score Breakdown")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(
                    "Baselines are computed as 7-day averages. " +
                    "This score reflects how well your body is recovering and managing strain, "
                  + "using both your personal baselines and accepted health standards:"
                )
                
                // Individual metric sections
                hrvSection
                rhrSection
                hrrSection
                respiratorySection
                wristTempSection
                oxygenSaturationSection
                energySection
                mindfulSection
                sleepSection
                
                // Close
            }
            .padding()
        }
        .navigationTitle("Readiness Explained")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Metric Sections
private extension ReadinessScoreExplanation {
    
    // HRV
    @ViewBuilder
    var hrvSection: some View {
        if let hrv = viewModel.hrv {
            if let base = viewModel.hrvBaseline {
                let delta = hrv.0 - base
                Text("• HRV: \(String(format: "%.1f", hrv.0)) ms  (Baseline: \(String(format: "%.1f", base)) ms) • measured at \(shortTime(hrv.1))")
                if      delta <= -10 { Text("   → Much lower than usual. Prioritise rest today. 😴") }
                else if delta <  -3  { Text("   → Slight dip — monitor fatigue. 😓") }
                else if delta <   3  { Text("   → Within normal range. ✅") }
                else if delta <  10  { Text("   → Above baseline — recovering well! 💪") }
                else                 { Text("   → Way above baseline — highly recovered! 💪") }
            } else {
                Text("• HRV: \(String(format: "%.1f", hrv.0)) ms • measured at \(shortTime(hrv.1))")
                Text("   → Baseline is still building (needs 7 days).")
            }
        }
    }
    
    // Resting HR
    @ViewBuilder
    var rhrSection: some View {
        if let rhr = viewModel.rhr {
            if let base = viewModel.rhrBaseline {
                let delta = rhr.0 - base
                Text("• Resting HR: \(Int(rhr.0)) bpm  (Baseline: \(Int(base)) bpm) • measured at \(shortTime(rhr.1))")
                if      delta >=  8 { Text("   → Much higher than normal — possible fatigue or illness. 🚩") }
                else if delta >   3 { Text("   → Slightly elevated — watch recovery. ⚠️") }
                else if delta >  -3 { Text("   → Within normal range. ✅") }
                else if delta >  -8 { Text("   → Lower than usual — good recovery. 🙂") }
                else               { Text("   → Well below baseline — excellent fitness. 🙂") }
            } else {
                Text("• Resting HR: \(Int(rhr.0)) bpm • measured at \(shortTime(rhr.1))")
                Text("   → Baseline is still building (needs 7 days).")
            }
        }
    }
    
    // Heart-rate recovery
    @ViewBuilder
    var hrrSection: some View {
        if let hrr = viewModel.hrr {
            if let base = viewModel.hrrBaseline {
                let delta = hrr.0 - base
                Text("• HR Recovery: \(Int(hrr.0)) bpm  (Baseline: \(Int(base)) bpm) • measured at \(shortTime(hrr.1))")
                if      delta <= -8 { Text("   → Slower than usual — likely fatigue. 🙂") }
                else if delta <  -3 { Text("   → Slightly slower — consider easy day. 🐌") }
                else if delta <   3 { Text("   → Within normal range. ✅") }
                else if delta <   8 { Text("   → Faster than baseline — good fitness! 💪") }
                else               { Text("   → Much faster — excellent recovery! 🏆") }
            } else {
                Text("• HR Recovery: \(Int(hrr.0)) bpm • measured at \(shortTime(hrr.1))")
                Text("   → Baseline is still building (needs 7 days).")
            }
        }
    }
    
    // Respiratory rate
    @ViewBuilder
    var respiratorySection: some View {
        if let rr = viewModel.respiratoryRate {
            if let base = viewModel.respiratoryBaseline {
                let delta = rr.0 - base
                Text("• Respiratory Rate: \(String(format: "%.1f", rr.0)) br/min  (Baseline: \(String(format: "%.1f", base)) br/min) • measured at \(shortTime(rr.1))")
                if      delta >=  3 { Text("   → Much higher — illness or stress possible. 🚩") }
                else if delta >   1 { Text("   → Slightly elevated — monitor strain. ⚠️") }
                else if delta >  -1 { Text("   → Within normal range. ✅") }
                else if delta >  -3 { Text("   → Slightly lower than baseline. 🙂") }
                else               { Text("   → Well below baseline — ensure accuracy. 🙂") }
            } else {
                Text("• Respiratory Rate: \(String(format: "%.1f", rr.0)) br/min • measured at \(shortTime(rr.1))")
                Text("   → Baseline is still building (needs 7 days).")
            }
        }
    }
    
    // Wrist temperature
    @ViewBuilder
    var wristTempSection: some View {
        if let wt = viewModel.wristTemp {
            if let base = viewModel.wristTempBaseline {
                let delta = wt.0 - base
                Text("• Wrist Temp: \(String(format: "%.2f", wt.0)) °C  (Baseline: \(String(format: "%.2f", base)) °C) • measured at \(shortTime(wt.1))")
                if abs(delta) >= 1.0 { Text("   → Large change — possible fever / heavy training. 🚩") }
                else if abs(delta) >= 0.3 { Text("   → Noticeable change — monitor recovery. 🌡️") }
                else { Text("   → Stable and within normal range. ✅") }
            } else {
                Text("• Wrist Temp: \(String(format: "%.2f", wt.0)) °C • measured at \(shortTime(wt.1))")
                Text("   → Baseline is still building (needs 7 days).")
            }
        }
    }
    
    // Oxygen saturation
    @ViewBuilder
    var oxygenSaturationSection: some View {
        if let o2 = viewModel.oxygenSaturation {
            let percent = (o2.0 <= 1.0) ? o2.0 * 100.0 : o2.0
            Text("• O₂ Saturation: \(String(format: "%.1f", percent)) % • measured at \(shortTime(o2.1))  (95–100 % optimal)")
            if      percent < 93 { Text("   → Quite low — consult a healthcare provider if persistent. 🩺") }
            else if percent < 95 { Text("   → Slightly below optimal — monitor fatigue. ⚠️") }
            else                 { Text("   → Within optimal range. 🙂") }
        }
    }
    
    // Active energy
    @ViewBuilder
    var energySection: some View {
        if let energy = viewModel.activeEnergyBurned {
            Text("• Active Energy: \(Int(energy.0)) kcal (last 24 h) • as of \(shortTime(energy.1))")
            switch energy.0 {
            case ..<400   : Text("   → Low activity (<400 kcal) — consider some gentle movement. 🦶")
            case ..<800   : Text("   → Moderate activity — maintaining routine. 🏃")
            case ..<1200  : Text("   → High activity — balance with recovery. 🏋️‍♂️")
            default       : Text("   → Very high! Fuel and rest adequately. 🏋️‍♂️")
            }
        }
    }
    
    // Mindful minutes
    @ViewBuilder
    var mindfulSection: some View {
        if let mm = viewModel.mindfulMinutes {
            Text("• Mindful Minutes: \(Int(mm.0)) min (last 24 h) • as of \(shortTime(mm.1))")
            switch mm.0 {
            case ..<5   : Text("   → Try a short mindfulness break today. 🧘‍♀️")
            case ..<10  : Text("   → A few minutes logged — nice start. 👍")
            case ..<30  : Text("   → Solid practice — supports recovery. 🌱")
            default     : Text("   → Excellent mindfulness routine! 🧘")
            }
        }
    }
    
    // Sleep
    @ViewBuilder
    var sleepSection: some View {
        if let sl = viewModel.sleepInfo {
            let total = sl.0
            let inBed = sl.1
            let start = sl.2
            let end = sl.3
            let stages = sl.4
            let core = stages["Core"] ?? 0
            let rem  = stages["REM"]  ?? 0
            let deep = stages["Deep"] ?? 0

            Text("• Sleep: \(String(format: "%.1f", total)) h  (In-bed: \(String(format: "%.1f", inBed)) h) • ended at \(shortTime(end))")
            Text("   • Core: \(String(format: "%.1f", core)) h • REM: \(String(format: "%.1f", rem)) h • Deep: \(String(format: "%.1f", deep)) h")

            switch total {
            case ..<5.5 : Text("   → Very little sleep — prioritise rest. 💤")
            case ..<7   : Text("   → Less than ideal — you may feel tired. 😴")
            case ..<8.5 : Text("   → Good duration — supportive of recovery. 🛌")
            default     : Text("   → Excellent sleep — body well-rested! 🌙")
            }

            if deep < 1 { Text("   → Deep sleep <1 h — improve sleep quality. 🙂") }
        }
    }

    
    private func shortTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: date)
    }
    
}
