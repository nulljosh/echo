import Foundation
import StoreKit

/// Local, server-free entitlement for Echo Pro.
///
/// One non-consumable unlock (`com.nulljosh.echo.pro`). Ownership is read straight
/// from StoreKit's `Transaction.currentEntitlements`, so there is no account, no
/// receipt server, and nothing leaves the device. Fits the whole pitch: own it once.
@MainActor
final class StoreManager: ObservableObject {
    static let productID = "com.nulljosh.echo.pro"

    /// Free file transcriptions before the unlock is required. Live mic stays free forever.
    static let freeFileLimit = 3
    private static let usedCountKey = "echo.fileTranscriptionsUsed"

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var purchasing = false
    @Published var showPaywall = false

    private var updatesTask: Task<Void, Never>?

    init() {
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
        product = try? await Product.products(for: [Self.productID]).first
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
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                isPro = true
                return
            }
        }
        isPro = false
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
