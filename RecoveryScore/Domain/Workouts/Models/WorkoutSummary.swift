/// WorkoutSummary.swift
/// Domain model representing a summary of a workout session fetched from HealthKit.

import Foundation
import HealthKit
// MARK: - WorkoutSummary
public struct WorkoutSummary: Identifiable {
    // MARK: - Properties
    public let id: UUID
    public let date: Date
    public let type: HKWorkoutActivityType
    public let duration: TimeInterval
    public let energy: Double
    public let rpe: Double?
    public let rpeSource: String?

    // MARK: - Initialization

    /// Initializes a new `WorkoutSummary`.
    /// - Parameters:
    ///   - id: Unique identifier for the workout.
    ///   - date: Date of the workout session.
    ///   - type: HealthKit workout activity type.
    ///   - duration: Duration of the workout in seconds.
    ///   - energy: Total energy burned.
    ///   - rpe: Rated perceived exertion, if available.
    ///   - rpeSource: Source of the RPE value, if available.
    public init(
        id: UUID,
        date: Date,
        type: HKWorkoutActivityType,
        duration: TimeInterval,
        energy: Double,
        rpe: Double?,
        rpeSource: String?
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.duration = duration
        self.energy = energy
        self.rpe = rpe
        self.rpeSource = rpeSource
    }
}
