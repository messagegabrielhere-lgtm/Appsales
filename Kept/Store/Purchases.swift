import StoreKit
import SwiftUI

/// The one-time Fuelprint Unlock, with StoreKit 2. Anyone who bought Fuelprint while it was a
/// paid app is unlocked automatically from their App Store receipt; nothing to restore.
@MainActor
final class Purchases: ObservableObject {
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published var problem: String?

    /// Remembered so the app opens unlocked offline, before StoreKit answers.
    private static let cacheKey = "fuelprint.unlocked"
    private var updates: Task<Void, Never>?

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demo") || args.contains("-unlocked") {
            isUnlocked = true
            return
        }
        isUnlocked = !args.contains("-fresh") && UserDefaults.standard.bool(forKey: Self.cacheKey)
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    deinit { updates?.cancel() }

    var displayPrice: String { product?.displayPrice ?? "" }

    func refresh() async {
        if product == nil {
            product = try? await Product.products(for: [UnlockPolicy.productID]).first
        }
        var unlocked = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == UnlockPolicy.productID, transaction.revocationDate == nil {
                unlocked = true
            }
        }
        if !unlocked, let original = await paidAppVersion() {
            unlocked = UnlockPolicy.paidForApp(originalAppVersion: original)
        }
        set(unlocked)
    }

    func buy() async {
        problem = nil
        if product == nil { await refresh() }
        guard let product else {
            problem = "The App Store isn't reachable right now. Check your connection and try again."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                set(true)
                Haptics.success()
            case .success(.unverified):
                problem = "The App Store couldn't confirm the purchase. Try Restore Purchase."
            case .pending:
                problem = "Your purchase is waiting for approval. Fuelprint unlocks as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            problem = "The purchase didn't go through. Try again."
        }
    }

    func restore() async {
        problem = nil
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
        await refresh()
        if !isUnlocked {
            problem = "No Fuelprint purchase was found for this Apple Account."
        }
    }

    /// The build the user first downloaded, from the App Store receipt. Only trusted from the
    /// real App Store: TestFlight and Xcode report "1.0" for everyone.
    private func paidAppVersion() async -> String? {
        guard let result = try? await AppTransaction.shared,
              case .verified(let transaction) = result,
              transaction.environment == .production else { return nil }
        return transaction.originalAppVersion
    }

    private func set(_ unlocked: Bool) {
        if isUnlocked != unlocked { isUnlocked = unlocked }
        UserDefaults.standard.set(unlocked, forKey: Self.cacheKey)
    }
}

/// What the Unlock adds, the price, and Buy and Restore. Shown when a locked feature is tapped.
struct UnlockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchases: Purchases
    /// What the user just tried to do, shown at the top.
    var reason: String? = nil

    private let benefits: [(String, String)] = [
        ("sparkles", "Unlimited AI questions to Grok, ChatGPT, Claude, Gemini or Apple Intelligence"),
        ("calendar", "Any period: 14 days, 30 days, 90 days, a year or all time"),
        ("chart.xyaxis.line", "Trends: calories, protein, fiber, water and mood charted"),
        ("heart.text.square", "Apple Health steps, sleep, workouts and weight in your questions"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accentColor)
                        Text("Fuelprint Unlock")
                            .font(.largeTitle.bold())
                        Text(reason ?? "Pay once. No subscription.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(benefits, id: \.1) { symbol, text in
                            Label {
                                Text(text)
                            } icon: {
                                Image(systemName: symbol)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }

                    Text("Logging, voice, label scanning, your checklist, history, import and export stay free forever. Your data is never locked.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let problem = purchases.problem {
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Task {
                            await purchases.buy()
                            if purchases.isUnlocked { dismiss() }
                        }
                    } label: {
                        Group {
                            if purchases.isPurchasing {
                                ProgressView()
                            } else {
                                Text(purchases.displayPrice.isEmpty ? "Unlock" : "Unlock for \(purchases.displayPrice)")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(purchases.isPurchasing)

                    Button("Restore Purchase") {
                        Task {
                            await purchases.restore()
                            if purchases.isUnlocked { dismiss() }
                        }
                    }
                    .font(.subheadline)
                    .disabled(purchases.isPurchasing)

                    Text("One-time purchase. Bought Fuelprint before it was free? It's already unlocked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
            .task { await purchases.refresh() }
        }
    }
}
