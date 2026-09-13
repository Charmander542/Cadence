import Foundation
import SwiftUI
import LinkKit

/// Owns a Plaid Link session and completes Item enrollment into SwiftData.
@MainActor
final class PlaidLinkCoordinator: ObservableObject {
    @Published var isPreparing = false
    @Published var isPresentingLink = false
    @Published var isReady = false
    @Published var statusMessage: String?
    @Published var lastError: String?

    private var linkSession: PlaidLinkSession?
    private var linkToken: String?

    func prepareAndOpen() async {
        lastError = nil
        statusMessage = nil
        isPreparing = true
        defer { isPreparing = false }

        SpendPreferences.ingestLocalSecretsIfNeeded()

        guard let secret = KeychainStore.loadPlaidSecret()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !secret.isEmpty else {
            lastError = PlaidClient.PlaidError.missingCredentials.localizedDescription
            return
        }

        do {
            let client = PlaidClient()
            let token = try await client.createLinkToken(
                clientID: SpendPreferences.clientID,
                secret: secret,
                environment: SpendPreferences.environment,
                clientUserID: SpendPreferences.clientUserID,
                redirectURI: SpendPreferences.redirectURI
            )
            linkToken = token
            try buildSession(linkToken: token)
            isPresentingLink = true
        } catch {
            lastError = error.localizedDescription
            linkSession = nil
            isReady = false
        }
    }

    func sheetContent() -> AnyView? {
        guard let linkSession else { return nil }
        return AnyView(linkSession.sheet())
    }

    private func buildSession(linkToken: String) throws {
        isReady = false
        let configuration = LinkTokenConfiguration(
            token: linkToken,
            onSuccess: { [weak self] success in
                Task { @MainActor in
                    await self?.handleSuccess(publicToken: success.publicToken, metadata: success.metadata)
                }
            },
            onExit: { [weak self] exit in
                Task { @MainActor in
                    self?.isPresentingLink = false
                    if let error = exit.error {
                        self?.lastError = error.displayMessage ?? error.errorMessage ?? "Link closed."
                    }
                }
            },
            onEvent: { _ in },
            onLoad: { [weak self] in
                Task { @MainActor in
                    self?.isReady = true
                }
            }
        )
        linkSession = try Plaid.createPlaidLinkSession(configuration: configuration)
    }

    private func handleSuccess(publicToken: String, metadata: SuccessMetadata) async {
        isPresentingLink = false
        isPreparing = true
        defer { isPreparing = false }

        guard let secret = KeychainStore.loadPlaidSecret(), !secret.isEmpty else {
            lastError = PlaidClient.PlaidError.missingCredentials.localizedDescription
            return
        }

        do {
            let client = PlaidClient()
            let exchanged = try await client.exchangePublicToken(
                clientID: SpendPreferences.clientID,
                secret: secret,
                environment: SpendPreferences.environment,
                publicToken: publicToken
            )
            KeychainStore.savePlaidAccessToken(exchanged.access_token, itemID: exchanged.item_id)

            let institution = metadata.institution.name.isEmpty
                ? (metadata.institution.id.isEmpty ? "Linked bank" : metadata.institution.id)
                : metadata.institution.name

            statusMessage = "Linked \(institution). Syncing…"
            NotificationCenter.default.post(
                name: .plaidItemLinked,
                object: nil,
                userInfo: [
                    "itemID": exchanged.item_id,
                    "institutionName": institution,
                    "isSandbox": SpendPreferences.environment == .sandbox,
                ]
            )
        } catch {
            lastError = error.localizedDescription
        }
    }
}

extension Notification.Name {
    static let plaidItemLinked = Notification.Name("cadence.plaidItemLinked")
}
