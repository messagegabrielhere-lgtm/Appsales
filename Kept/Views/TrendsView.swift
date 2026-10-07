import Charts
import SwiftUI

/// Calories, protein and fiber from AI answers pasted back, alongside water, how you felt and
/// supplement consistency from the log. Trends without a food database.
struct TrendsView: View {
    @EnvironmentObject private var store: HabitStore
    @State private var span = 30
    @State private var savedMessage: String?

    private var days: [DayKey] {
        let today = DayKey.today()
        return (0..<span).reversed().map { today.adding(days: -$0) }
    }

    private struct Point: Identifiable {
        let day: DayKey
        let value: Double
        var id: DayKey { day }
        var date: Date { day.date() }
    }

    var body: some View {
        let window = Set(days)
        let estimates = store.estimates.filter { window.contains($0.day) }

        List {
            Section {
                Picker("Period", selection: $span) {
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("1 year").tag(365)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                SaveAnswerButton(message: $savedMessage)
                if let savedMessage {
                    Text(savedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Nutrition from your AI")
            } footer: {
                Text("Ask AI for a Nutrition estimate, Protein check or Weight goal check. Its answer ends with daily numbers; copy the whole answer and paste it here. These are AI estimates, not measurements.")
            }

            if estimates.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No AI estimates yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Paste an AI answer above to see calories, protein and fiber over time.")
                    )
                }
            } else {
                chart("Calories", unit: "kcal", color: .orange, bars: true,
                      points: estimates.compactMap { e in e.calories.map { Point(day: e.day, value: Double($0)) } })
                chart("Protein", unit: "g", color: .purple, bars: false,
                      points: estimates.compactMap { e in e.proteinGrams.map { Point(day: e.day, value: Double($0)) } })
                chart("Fiber", unit: "g", color: .green, bars: false,
                      points: estimates.compactMap { e in e.fiberGrams.map { Point(day: e.day, value: Double($0)) } })
            }

            chart("Water", unit: "ml", color: .blue, bars: true, points: days.compactMap { day in
                let ml = store.waterMilliliters(on: day)
                return ml > 0 ? Point(day: day, value: Double(ml)) : nil
            })

            chart("How you felt", unit: "of 5", color: .pink, bars: false, points: days.compactMap { day in
                let ratings = store.entries(on: day).compactMap(\.rating)
                guard !ratings.isEmpty else { return nil }
                return Point(day: day, value: Double(ratings.reduce(0, +)) / Double(ratings.count))
            })

            chart("Supplements & routines done", unit: "%", color: .accentColor, bars: true, points: days.compactMap { day in
                let scheduled = store.habits.filter { $0.isScheduled(on: day) && $0.createdAt <= day.date().addingTimeInterval(86_400) }
                guard !scheduled.isEmpty else { return nil }
                let done = scheduled.filter { $0.isCompleted(on: day) }.count
                return Point(day: day, value: Double(done * 100) / Double(scheduled.count))
            })
        }
        .navigationTitle("Trends")
        .onAppear(perform: showSavedFromLaunchArguments)
    }

    @ViewBuilder
    private func chart(_ title: String, unit: String, color: Color, bars: Bool, points: [Point]) -> some View {
        if !points.isEmpty {
            let average = points.map(\.value).reduce(0, +) / Double(points.count)
            Section {
                Chart(points) { point in
                    if bars {
                        BarMark(x: .value("Day", point.date, unit: .day), y: .value(title, point.value))
                            .foregroundStyle(color.gradient)
                    } else {
                        LineMark(x: .value("Day", point.date, unit: .day), y: .value(title, point.value))
                            .foregroundStyle(color)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Day", point.date, unit: .day), y: .value(title, point.value))
                            .foregroundStyle(color)
                            .symbolSize(span > 90 ? 6 : 18)
                    }
                    RuleMark(y: .value("Average", average))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .frame(height: 160)
                .padding(.vertical, 6)
                .accessibilityLabel("\(title), average \(Int(average.rounded())) \(unit)")
            } header: {
                HStack {
                    Text(title)
                    Spacer()
                    Text("avg \(Int(average.rounded()).formatted()) \(unit)")
                }
            }
        }
    }

    private func showSavedFromLaunchArguments() {
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            savedMessage = nil
        }
    }
}

/// Pastes an AI answer and saves the daily numbers in it. Uses the system Paste button, so
/// iOS doesn't ask for permission.
struct SaveAnswerButton: View {
    @EnvironmentObject private var store: HabitStore
    @Binding var message: String?

    var body: some View {
        PasteButton(payloadType: String.self) { strings in
            let answer = strings.joined(separator: "\n")
            Task { @MainActor in
                let estimates = EstimateParser.parse(answer)
                if estimates.isEmpty {
                    message = "No daily numbers found in that text. Copy the whole answer, including the FUELPRINT-DAILY block at the end."
                    Haptics.tap()
                } else {
                    store.saveEstimates(estimates)
                    message = estimates.count == 1 ? "Saved estimates for 1 day." : "Saved estimates for \(estimates.count) days."
                    Haptics.success()
                }
            }
        }
        .labelStyle(.titleAndIcon)
        .buttonBorderShape(.capsule)
    }
}
