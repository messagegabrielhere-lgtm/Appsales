import SwiftUI
import WidgetKit

/// A home-screen-style arrangement of the real widget views, used only for the App Store
/// screenshot (launch with `-demo -screen widgets`). Not reachable from the UI.
struct WidgetShowcaseView: View {
    let habits: [Habit]
    let waterMilliliters: Int

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let corner: CGFloat = 22

    var body: some View {
        let entry = KeptEntry(date: Date(), habits: habits, today: DayKey.today(), waterMilliliters: waterMilliliters)
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.984, green: 0.749, blue: 0.141),
                    Color(red: 0.976, green: 0.451, blue: 0.086),
                    Color(red: 0.882, green: 0.114, blue: 0.282),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()
                card(entry: entry, family: .systemLarge, width: 338, height: 354)
                HStack(spacing: 18) {
                    card(entry: entry, family: .systemSmall, width: 160, height: 160)
                    lockScreenCard(entry: entry)
                }
                Spacer()
            }
            .scaleEffect(sizeClass == .regular ? 1.5 : 1)
        }
    }

    private func card(entry: KeptEntry, family: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        KeptWidgetView(entry: entry, family: family)
            .padding(16)
            .frame(width: width, height: height)
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
    WidgetShowcaseView(habits: HabitStore.demoHabits(), waterMilliliters: 1330)
}
