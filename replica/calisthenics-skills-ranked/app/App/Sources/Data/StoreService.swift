import Foundation
import Observation
import StoreKit

/// StoreKit 2. Entitlement nur aus currentEntitlements ableiten, nie hochzählen (architecture.md: Idempotenz).
@MainActor @Observable
final class StoreService {
    static let productIDs = ["pro.weekly", "pro.yearly"]
    static let groupID = "21000001"     // = subscriptionGroups.id in Products.storekit; für App Store Connect ersetzen

    private(set) var isPro = false
    private var updates: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: "isProCache")   // nur für schnellen Kaltstart
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.productIDs.contains(t.productID), t.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
        UserDefaults.standard.set(pro, forKey: "isProCache")
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }
}
