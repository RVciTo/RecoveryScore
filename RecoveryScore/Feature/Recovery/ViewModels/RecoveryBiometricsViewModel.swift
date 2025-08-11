///
///  RecoveryBiometricsViewModel.swift
///  RecoveryScore
///
///  ViewModel responsible for managing and exposing recovery-related biometric data
///  used in the Readiness feature. It coordinates fetching HealthKit metrics,
///  calculating baselines, and computing readiness score.
///

import Foundation
import HealthKit

@MainActor
class RecoveryBiometricsViewModel: ObservableObject {

    private let service: RecoveryDataServicing

    // MARK: - Published Properties (Biometric Metrics)

    // Status/messages for missing data
    @Published var missingMandatory: [String] = []
    @Published var missingSecondary: [String] = []
    @Published var errorMessage: String? = nil
    @Published var warningMessage: String? = nil


    /// Indicates whether HealthKit authorization was granted.
    @Published var isAuthorized: Bool = false
    @Published var showReadinessExplanation: Bool = false

    /// Latest heart rate variability value and timestamp.
    @Published var hrv: (Double, Date)?
    /// Latest resting heart rate value and timestamp.
    @Published var rhr: (Double, Date)?
    /// Latest heart rate recovery value and timestamp.
    @Published var hrr: (Double, Date)?
    /// Latest respiratory rate value and timestamp.
    @Published var respiratoryRate: (Double, Date)?
    /// Latest wrist temperature value and timestamp.
    @Published var wristTemp: (Double, Date)?
    /// Latest oxygen saturation value and timestamp.
    @Published var oxygenSaturation: (Double, Date)?
    /// Latest active energy burned value and timestamp.
    @Published var activeEnergyBurned: (Double, Date)?
    /// Latest mindful minutes value and timestamp.
    @Published var mindfulMinutes: (Double, Date)?
    /// Baseline heart rate variability over past 7 days.
    @Published var hrvBaseline: Double?
    /// Baseline resting heart rate over past 7 days.
    @Published var rhrBaseline: Double?
    /// Baseline heart rate recovery over past 7 days.
    @Published var hrrBaseline: Double?
    /// Baseline respiratory rate over past 7 days.
    @Published var respiratoryBaseline: Double?
    /// Baseline wrist temperature over past 7 days.
    @Published var wristTempBaseline: Double?
    /// Latest sleep session data: (duration, quality, start, end, stages)
    @Published var sleepInfo: (Double, Double, Date, Date, [String: Double])?
    /// Final calculated readiness score (0–100).
    @Published var readinessScore: Int?
    @Published var readinessTrend: [Double] = []
    private let readinessDailyKey = "readinessTrendDaily"
    private let readinessTrendKey = "readinessTrend"

    // MARK: - Init

    /// Initializes the ViewModel. Call `loadAllMetrics()` from the view to fetch data.
    init(service: RecoveryDataServicing = RecoveryDataService()) {
        self.service = service
        // No automatic fetch; call loadAllMetrics() from the view with .task
    }

    // MARK: - Data Fetching

    /// Loads all recovery metrics from HealthKit and computes the readiness score.
    /// 
    /// This method fetches the latest biometric data, calculates personal baselines,
    /// and generates a readiness score based on deviations from those baselines.
    /// Updates all published properties for UI consumption.
    ///
    /// - Note: Requires HealthKit permissions. Sets error states when mandatory data is missing.
    /// - Complexity: O(1) - Concurrent data fetching with baseline calculations
    public func loadAllMetrics() async {
        let bundle = await service.fetchRecoveryData()

        // Update published properties on the main actor
        hrv = bundle.hrv
        rhr = bundle.rhr
        hrr = bundle.hrr
        respiratoryRate = bundle.respiratoryRate
        wristTemp = bundle.wristTemp
        oxygenSaturation = bundle.oxygenSaturation
        activeEnergyBurned = bundle.activeEnergyBurned
        mindfulMinutes = bundle.mindfulMinutes
        sleepInfo = bundle.sleepInfo

        // Populate baseline values
        hrvBaseline = bundle.baseline.averageHRV
        rhrBaseline = bundle.baseline.averageRHR
        hrrBaseline = bundle.baseline.averageHRR
        respiratoryBaseline = bundle.baseline.averageRespiratoryRate
        wristTempBaseline = bundle.baseline.averageWristTemp

        // Compute readiness when mandatory metrics are present
        let mHRV = bundle.hrv?.0
        let mRHR = bundle.rhr?.0
        let mHRR = bundle.hrr?.0

        missingMandatory = []
        missingSecondary = []

        if mHRV == nil { missingMandatory.append("HRV") }
        if mRHR == nil { missingMandatory.append("Resting HR") }
        if mHRR == nil { missingMandatory.append("HR Recovery") }

        if bundle.respiratoryRate == nil { missingSecondary.append("Respiratory Rate") }
        if bundle.wristTemp == nil { missingSecondary.append("Wrist Temperature") }
        if bundle.oxygenSaturation == nil { missingSecondary.append("Oxygen Saturation") }
        if bundle.activeEnergyBurned == nil { missingSecondary.append("Active Energy") }
        if bundle.mindfulMinutes == nil { missingSecondary.append("Mindful Minutes") }
        if bundle.sleepInfo == nil { missingSecondary.append("Sleep") }

        if !missingMandatory.isEmpty {
            readinessScore = 0
            errorMessage = "Missing required data: " + missingMandatory.joined(separator: ", ") + ". Grant Health permissions and wear your Apple Watch to enable these metrics."
            warningMessage = nil
            // Ensure the trend still renders (will pad to a flat line if empty)
            loadReadinessTrend()
            return
        } else {
            errorMessage = nil
        }

        if !missingSecondary.isEmpty {
            warningMessage = "Score may be less accurate. Missing: " + missingSecondary.joined(separator: ", ") + "."
        } else {
            warningMessage = nil
        }

        // Build inputs with safe defaults for secondary metrics
        let hrvPair: (Double, Date) = (mHRV!, Date())
        let rhrPair: (Double, Date) = (mRHR!, Date())
        let hrrPair: (Double, Date) = (mHRR!, Date())

        let respPair: (Double, Date) = bundle.respiratoryRate ?? (bundle.baseline.averageRespiratoryRate, Date())
        let wristPair: (Double, Date) = bundle.wristTemp ?? (bundle.baseline.averageWristTemp, Date())
        let o2Pair: (Double, Date) = bundle.oxygenSaturation ?? (98.0, Date())
        let energyPair: (Double, Date) = bundle.activeEnergyBurned ?? (0.0, Date())
        let mindfulPair: (Double, Date) = bundle.mindfulMinutes ?? (0.0, Date())

        // Sleep default: 7h total, 1h deep, last night
        let end = Date()
        let start = Calendar.current.date(byAdding: .hour, value: -7, to: end) ?? end
        let sleepTuple: (Double, Double, Date, Date, [String : Double]) = bundle.sleepInfo ?? (7.0, 1.0, start, end, [:])

        let input = ReadinessInputBuilder.build(
            hrv: hrvPair,
            rhr: rhrPair,
            hrr: hrrPair,
            sleepInfo: sleepTuple,
            respiratoryRate: respPair,
            wristTemp: wristPair,
            oxygenSaturation: o2Pair,
            activeEnergyBurned: energyPair,
            mindfulMinutes: mindfulPair
        )

        let score = ReadinessCalculator().calculateScore(from: input, baseline: bundle.baseline)
        readinessScore = score
        appendToTrend(score)
    }

    /// Refreshes HealthKit authorization status and updates the published `isAuthorized` property.
    ///
    /// This method checks the current authorization status with HealthKit and updates
    /// the UI state accordingly. Should be called when the user returns from Settings
    /// or when checking initial permissions.
    ///
    /// - Note: Updates `isAuthorized` on the main actor for UI consumption
    func refreshAuthorization() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            HealthDataStore.shared.getAuthorizationRequestStatus { status in
                Task { @MainActor in
                    self.isAuthorized = (status == .unnecessary)
                    continuation.resume()
                }
            }
        }
    }

}

extension RecoveryBiometricsViewModel {
    // Baseline readiness counters
    var baselineReadyCount: Int {
        var n = 0
        if hrvBaseline != nil && (hrvBaseline ?? 0) > 0 { n += 1 }
        if rhrBaseline != nil && (rhrBaseline ?? 0) > 0 { n += 1 }
        if hrrBaseline != nil && (hrrBaseline ?? 0) > 0 { n += 1 }
        if respiratoryBaseline != nil && (respiratoryBaseline ?? 0) > 0 { n += 1 }
        if wristTempBaseline != nil && (wristTempBaseline ?? 0) > 0 { n += 1 }
        return n
    }

    var baselineTotalCount: Int { 5 }

    var missingBaselineNames: [String] {
        var names: [String] = []
        if hrvBaseline == nil || (hrvBaseline ?? 0) == 0 { names.append("HRV") }
        if rhrBaseline == nil || (rhrBaseline ?? 0) == 0 { names.append("Resting HR") }
        if hrrBaseline == nil || (hrrBaseline ?? 0) == 0 { names.append("HR Recovery") }
        if respiratoryBaseline == nil || (respiratoryBaseline ?? 0) == 0 { names.append("Resp. Rate") }
        if wristTempBaseline == nil || (wristTempBaseline ?? 0) == 0 { names.append("Wrist Temp") }
        return names
    }
}


// MARK: - Drivers (Top factors that helped or hurt today)
struct DriverItem: Identifiable {
    let id = UUID()
    let name: String
    let change: String
    let icon: String
    let impactScore: Double // for sorting
    let isHelp: Bool
}

extension RecoveryBiometricsViewModel {
    var helpedDrivers: [DriverItem] {
        var items: [DriverItem] = []

        // HRV vs baseline (higher helps)
        if let h = hrv?.0, let base = hrvBaseline, base > 0 {
            let pct = (h - base) / base
            if pct > 0.03 {
                items.append(DriverItem(name: "HRV", change: String(format: "+%.0f%%", pct*100), icon: "arrow.up.right", impactScore: abs(pct), isHelp: true))
            } else if pct < -0.03 {
                // hurt; handled below
            }
        }

        // Resting HR vs baseline (lower helps)
        if let r = rhr?.0, let base = rhrBaseline, base > 0 {
            let pct = (base - r) / base
            if pct > 0.03 {
                items.append(DriverItem(name: "Resting HR", change: String(format: "−%.0f%%", ((base - r)/base) * 100), icon: "arrow.down.right", impactScore: abs((r - base) / base), isHelp: true))
            }
        }

        // HRR vs baseline (higher helps)
        if let v = hrr?.0, let base = hrrBaseline, base > 0 {
            let diff = v - base
            if diff > 3 {
                items.append(DriverItem(name: "HR Recovery", change: String(format: "+%.0f bpm", diff), icon: "arrow.up.right", impactScore: abs(diff)/50.0, isHelp: true))
            }
        }

        // Respiratory rate vs baseline (lower helps a bit)
        if let rr = respiratoryRate?.0, let base = respiratoryBaseline, base > 0 {
            let diff = base - rr
            if diff > 1 {
                items.append(DriverItem(name: "Resp. Rate", change: String(format: "−%.1f", diff), icon: "arrow.down.right", impactScore: diff/10.0, isHelp: true))
            }
        }

        // Mindful minutes (>=10 helps)
        if let mm = mindfulMinutes?.0, mm >= 10 {
            items.append(DriverItem(name: "Mindfulness", change: String(format: "+%d min", Int(mm)), icon: "brain.head.profile", impactScore: min(mm/30.0, 1.0), isHelp: true))
        }

        // Sleep deep >= 1h helps
        if let sl = sleepInfo {
            let deep = sl.4["Deep"] ?? 0
            if deep >= 1.0 {
                items.append(DriverItem(name: "Deep Sleep", change: String(format: "+%.1f h", deep), icon: "bed.double.fill", impactScore: min(deep/2.0, 1.0), isHelp: true))
            }
        }

        return items.sorted { $0.impactScore > $1.impactScore }.prefix(3).map { $0 }
    }
}
extension RecoveryBiometricsViewModel {
    var hurtDrivers: [DriverItem] {
        var items: [DriverItem] = []

        // HRV vs baseline (lower hurts)
        if let h = hrv?.0, let base = hrvBaseline, base > 0 {
            let pct = (h - base) / base
            if pct < -0.03 {
                items.append(DriverItem(name: "HRV", change: String(format: "−%.0f%%", abs(pct*100)), icon: "arrow.down.right", impactScore: abs(pct), isHelp: false))
            }
        }

        // Resting HR vs baseline (higher hurts)
        if let r = rhr?.0, let base = rhrBaseline, base > 0 {
            let pct = (r - base) / base
            if pct > 0.03 {
                items.append(DriverItem(name: "Resting HR", change: String(format: "+%.0f%%", pct*100), icon: "arrow.up.right", impactScore: abs(pct), isHelp: false))
            }
        }

        // HRR vs baseline (lower hurts)
        if let v = hrr?.0, let base = hrrBaseline, base > 0 {
            let diff = v - base
            if diff < -3 {
                items.append(DriverItem(name: "HR Recovery", change: String(format: "−%.0f bpm", abs(diff)), icon: "arrow.down.right", impactScore: abs(diff)/50.0, isHelp: false))
            }
        }

        // Respiratory rate vs baseline (higher hurts)
        if let rr = respiratoryRate?.0, let base = respiratoryBaseline, base > 0 {
            let diff = rr - base
            if diff > 1 {
                items.append(DriverItem(name: "Resp. Rate", change: String(format: "+%.1f", diff), icon: "arrow.up.right", impactScore: diff/10.0, isHelp: false))
            }
        }

        // Wrist temperature deviation from baseline (either direction) hurts
        if let wt = wristTemp?.0, let base = wristTempBaseline {
            let dev = abs(wt - base)
            if dev >= 0.3 {
                items.append(DriverItem(name: "Wrist Temp", change: String(format: "+%.1f °C", dev), icon: "thermometer", impactScore: dev, isHelp: false))
            }
        }

        // Low O2 hurts
        if let o2 = oxygenSaturation?.0 {
            let percent = (o2 <= 1.0) ? o2*100.0 : o2
            if percent < 95.0 {
                items.append(DriverItem(name: "O₂", change: String(format: "−%.1f%%", 95.0 - percent), icon: "lungs.fill", impactScore: (95.0 - percent)/100.0, isHelp: false))
            }
        }

        // Very high recent strain hurts
        if let energy = activeEnergyBurned?.0, energy > 1000 {
            items.append(DriverItem(name: "Strain", change: String(format: "+%d kcal", Int(energy - 1000)), icon: "flame.fill", impactScore: min((energy-1000)/1000.0, 1.0), isHelp: false))
        }

        // Deep sleep < 1h hurts
        if let sl = sleepInfo {
            let deep = sl.4["Deep"] ?? 0
            if deep < 1.0 {
                items.append(DriverItem(name: "Deep Sleep", change: String(format: "−%.1f h", 1.0 - deep), icon: "bed.double.fill", impactScore: min((1.0 - deep), 1.0), isHelp: false))
            }
            // Total sleep < 6h also hurts
            let total = sl.0
            if total < 6.0 {
                items.append(DriverItem(name: "Sleep", change: String(format: "−%.1f h", 6.0 - total), icon: "moon.zzz.fill", impactScore: min((6.0 - total)/6.0, 1.0), isHelp: false))
            }
        }

        return items.sorted { $0.impactScore > $1.impactScore }.prefix(3).map { $0 }
    }
}
extension RecoveryBiometricsViewModel {
    // MARK: - Readiness trend persistence
    func loadReadinessTrend() { loadDailyTrend() }
    func appendToTrend(_ score: Int) { recordDailyReadiness(score) }

    /// Load last 7 daily readiness scores (one per calendar day)
    func loadDailyTrend() {
        if let dict = UserDefaults.standard.dictionary(forKey: readinessDailyKey) as? [String: Int] {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"

            let entries: [(Date, Int)] = dict.compactMap { (k, v) in
                guard let d = df.date(from: k) else { return nil }
                return (d, v)
            }.sorted { $0.0 < $1.0 }

            let last7 = entries.suffix(7)
            self.readinessTrend = last7.map { Double($0.1) }
        } else if let arr = UserDefaults.standard.array(forKey: readinessTrendKey) as? [Double] {
            // Fallback to older storage if present
            self.readinessTrend = arr
        } else {
            self.readinessTrend = []
        }
        // Normalize: ensure ≥2 points so sparkline always renders; pad flat if needed
        if self.readinessTrend.count == 1 {
            self.readinessTrend.append(self.readinessTrend[0])
        } else if self.readinessTrend.isEmpty {
            let fallback = (self.readinessScore != nil) ? Double(self.readinessScore!) : 0
            self.readinessTrend = [fallback, fallback]
        }
    }

    /// Record/replace today's readiness value and keep only the last 7 days
    func recordDailyReadiness(_ score: Int) {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"

        let todayKey = df.string(from: Date())
        var dict = (UserDefaults.standard.dictionary(forKey: readinessDailyKey) as? [String: Int]) ?? [:]
        dict[todayKey] = score

        // Trim to last 7 by date
        let entries: [(String, Date, Int)] = dict.compactMap { (k, v) in
            guard let d = df.date(from: k) else { return nil }
            return (k, d, v)
        }.sorted { $0.1 < $1.1 }

        let trimmed = entries.suffix(7)
        var newDict: [String: Int] = [:]
        for e in trimmed { newDict[e.0] = e.2 }
        UserDefaults.standard.set(newDict, forKey: readinessDailyKey)

        // Update published array for UI
        self.readinessTrend = trimmed.map { Double($0.2) }
    }

    /// Optional helper message for empty/flat trends
    var trendEmptyMessage: String? {
        // If we had to pad to show a line (empty or single point), explain why
        if readinessTrend.count < 2 {
            if !missingMandatory.isEmpty {
                return "Trend is flat while required data is missing. Once we can compute daily scores, you’ll see changes here."
            }
            return "The Sparkline is flat as we are still collecting your daily trends. Come back soon."
        }
        guard let minV = readinessTrend.min(), let maxV = readinessTrend.max() else { return nil }
        if Int(minV) == Int(maxV) {
            return "Your readiness has been steady for the last \(readinessTrend.count) days."
        }
        return nil
    }
}
