import Foundation
import HealthKit

/// Reads Apple Health for the days a prompt covers. Read-only: Fuelprint never writes to
/// Health, stores what it reads, or sends it anywhere. The data only leaves the phone inside
/// a prompt the user chooses to send.
@MainActor
final class HealthReader: ObservableObject {
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        let quantities: [HKQuantityTypeIdentifier] = [.stepCount, .appleExerciseTime, .activeEnergyBurned, .bodyMass, .restingHeartRate]
        for identifier in quantities {
            types.insert(HKQuantityType(identifier))
        }
        types.insert(HKCategoryType(.sleepAnalysis))
        return types
    }

    /// Shows Apple's permission sheet the first time. Health never says what the user declined,
    /// so a declined type simply reads as no data.
    func requestAccess() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    func days(_ days: [DayKey], calendar: Calendar = .current) async -> [DayKey: HealthDay] {
        guard Self.isAvailable, let first = days.min(), let last = days.max() else { return [:] }
        let start = first.date(calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: last.date(calendar: calendar)) ?? Date()
        var result: [DayKey: HealthDay] = [:]

        func update(_ day: DayKey, _ change: (inout HealthDay) -> Void) {
            var value = result[day] ?? HealthDay()
            change(&value)
            result[day] = value
        }

        for (identifier, unit) in [(HKQuantityTypeIdentifier.stepCount, HKUnit.count()),
                                   (.appleExerciseTime, .minute()),
                                   (.activeEnergyBurned, .kilocalorie())] {
            for (day, value) in await dailySums(identifier, unit: unit, from: start, to: end, calendar: calendar) where value > 0 {
                update(day) { health in
                    switch identifier {
                    case .stepCount: health.steps = Int(value.rounded())
                    case .appleExerciseTime: health.exerciseMinutes = Int(value.rounded())
                    default: health.activeCalories = Int(value.rounded())
                    }
                }
            }
        }

        for sample in await samples(HKQuantityType(.bodyMass), from: start, to: end) {
            guard let quantity = sample as? HKQuantitySample else { continue }
            update(DayKey(quantity.endDate, calendar: calendar)) { $0.weightKilograms = quantity.quantity.doubleValue(for: .gramUnit(with: .kilo)) }
        }

        var heartRates: [DayKey: [Double]] = [:]
        for sample in await samples(HKQuantityType(.restingHeartRate), from: start, to: end) {
            guard let quantity = sample as? HKQuantitySample else { continue }
            heartRates[DayKey(quantity.endDate, calendar: calendar), default: []]
                .append(quantity.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        }
        for (day, values) in heartRates where !values.isEmpty {
            update(day) { $0.restingHeartRate = Int((values.reduce(0, +) / Double(values.count)).rounded()) }
        }

        // Sleep from the evening before the first day, credited to the morning it ended.
        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: start) ?? start
        var asleep: [DayKey: TimeInterval] = [:]
        for sample in await samples(HKCategoryType(.sleepAnalysis), from: sleepStart, to: end) {
            guard let category = sample as? HKCategorySample,
                  HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue).contains(category.value) else { continue }
            asleep[DayKey(category.endDate, calendar: calendar), default: 0] += category.endDate.timeIntervalSince(category.startDate)
        }
        for (day, seconds) in asleep where seconds > 0 && days.contains(day) {
            update(day) { $0.sleepHours = (seconds / 360).rounded() / 10 }
        }

        for sample in await samples(HKObjectType.workoutType(), from: start, to: end) {
            guard let workout = sample as? HKWorkout else { continue }
            let minutes = Int((workout.duration / 60).rounded())
            update(DayKey(workout.startDate, calendar: calendar)) { $0.workouts.append("\(Self.name(workout.workoutActivityType)) \(minutes) min") }
        }

        return result.filter { days.contains($0.key) && !$0.value.isEmpty }
    }

    private func dailySums(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date, calendar: Calendar) async -> [DayKey: Double] {
        let type = HKQuantityType(identifier)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum,
            anchorDate: calendar.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1)
        )
        guard let collection = try? await descriptor.result(for: store) else { return [:] }
        var result: [DayKey: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            if let sum = statistics.sumQuantity() {
                result[DayKey(statistics.startDate, calendar: calendar)] = sum.doubleValue(for: unit)
            }
        }
        return result
    }

    private func samples(_ type: HKSampleType, from start: Date, to end: Date) async -> [HKSample] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: HKQuery.predicateForSamples(withStart: start, end: end),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            store.execute(query)
        }
    }

    private static func name(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .pilates: return "Pilates"
        case .dance, .cardioDance, .socialDance: return "Dance"
        case .tennis: return "Tennis"
        case .pickleball: return "Pickleball"
        case .golf: return "Golf"
        case .coreTraining: return "Core training"
        case .stairClimbing, .stairs: return "Stairs"
        case .mindAndBody: return "Mind and body"
        default: return "Workout"
        }
    }
}
