import Foundation
import StoreKit

/// Local, server-free entitlement for Voxprint Pro.
///
/// One non-consumable unlock (`com.nulljosh.echo.unlock`). Ownership is read straight
/// from StoreKit's `Transaction.currentEntitlements`, so there is no account, no
/// receipt server, and nothing leaves the device. Fits the whole pitch: own it once.
@MainActor
final class StoreManager: ObservableObject {
    static let productID = "com.nulljosh.echo.unlock"

    /// Free file transcriptions before the unlock is required. Live mic stays free forever.
    static let freeFileLimit = 3
    private static let usedCountKey = "echo.fileTranscriptionsUsed"

    // ponytail: no Paid Apps Agreement/bank account on the dev account yet, so IAP
    // can't function in review at all — ship v1 fully unlocked, re-enable for v2.
    @Published private(set) var isPro = true
    @Published private(set) var product: Product?
    @Published private(set) var purchasing = false
    @Published var showPaywall = false

    private var updatesTask: Task<Void, Never>?

    init() {
        if CommandLine.arguments.contains("UITEST_PAYWALL") {
            showPaywall = true
        }
        updatesTask = listenForTransactions()
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Free tier gating

    var freeFilesUsed: Int { UserDefaults.standard.integer(forKey: Self.usedCountKey) }
    var freeFilesRemaining: Int { max(0, Self.freeFileLimit - freeFilesUsed) }

    /// File transcription is allowed if Pro, or while free transcriptions remain.
    func canTranscribeFile() -> Bool { isPro || freeFilesUsed < Self.freeFileLimit }

    /// Call after a successful free file transcription so the counter advances.
    func recordFileTranscription() {
        guard !isPro else { return }
        UserDefaults.standard.set(freeFilesUsed + 1, forKey: Self.usedCountKey)
        objectWillChange.send()
    }

    /// The most accurate model is a Pro feature; auto/tiny/base are free.
    func isModelLocked(_ model: String) -> Bool {
        !isPro && model == "openai_whisper-small"
    }

    // MARK: - Purchase flow

    func loadProduct() async {
        // ponytail: sandbox/App Review StoreKit fetches occasionally fail transiently;
        // retry a few times with backoff instead of leaving the button dead forever.
        for attempt in 0..<3 {
            if let fetched = try? await Product.products(for: [Self.productID]).first {
                product = fetched
                return
            }
            if attempt < 2 { try? await Task.sleep(for: .seconds(1 << attempt)) }
        }
    }

    func purchase() async {
        guard let product, !purchasing else { return }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshEntitlement()
                showPaywall = false
            }
        } catch {
            // Purchase failed or was cancelled; leave entitlement untouched.
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    // MARK: - Entitlement

    private func refreshEntitlement() async {
        // ponytail: no-op while isPro is hardcoded true above; restore this body
        // (removing the early return) when IAP is re-enabled for v2.
        return
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }
}
