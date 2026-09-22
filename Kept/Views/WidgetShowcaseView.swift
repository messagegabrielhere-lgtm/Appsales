import SwiftUI
import WidgetKit

/// A home-screen-style arrangement of the real widget views, used only for the App Store
/// screenshot (launch with `-demo -screen widgets`). Not reachable from the UI.
struct WidgetShowcaseView: View {
    let habits: [Habit]

    private let corner: CGFloat = 22

    var body: some View {
        let entry = KeptEntry(date: Date(), habits: habits, today: DayKey.today())
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.46, blue: 0.43), Color(red: 0.13, green: 0.77, blue: 0.37)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()
                card(entry: entry, family: .systemMedium, width: 338)
                HStack(spacing: 18) {
                    card(entry: entry, family: .systemSmall, width: 160)
                    lockScreenCard(entry: entry)
                }
                Spacer()
                Spacer()
            }
        }
    }

    private func card(entry: KeptEntry, family: WidgetFamily, width: CGFloat) -> some View {
        KeptWidgetView(entry: entry, family: family)
            .padding(16)
            .frame(width: width, height: 160)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }

    private func lockScreenCard(entry: KeptEntry) -> some View {
        VStack(spacing: 12) {
            KeptWidgetView(entry: entry, family: .accessoryCircular)
                .frame(width: 64, height: 64)
            KeptWidgetView(entry: entry, family: .accessoryRectangular)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: 160, height: 160)
        .foregroundStyle(.white)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: corner, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

#Preview {
    WidgetShowcaseView(habits: HabitStore.preview().habits)
}
