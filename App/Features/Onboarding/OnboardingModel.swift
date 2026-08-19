import FamilyControls
import Foundation
import ManagedSettings
import Observation
import ScrollCore
import SwiftUI
import UIKit

/// Drives the 5-step onboarding state machine.
@Observable
public final class OnboardingModel {
    public enum Step: Int, CaseIterable {
        case hook, auth, picker, label, finish
    }

    public var step: Step = .hook
    public var selection = FamilyActivitySelection()
    public var labels: [String: AppLabel] = [:]

    public var isRequestingAuthorization = false
    public var authorizationDenied = false
    public var errorMessage: String?

    private let selectionStore: SelectionStore
    private let monitoringService: MonitoringService

    public init(
        selectionStore: SelectionStore,
        monitoringService: MonitoringService = .shared
    ) {
        self.selectionStore = selectionStore
        self.monitoringService = monitoringService
    }

    public var tokenCount: Int {
        selection.applicationTokens.count
    }

    public var canAdvanceFromPicker: Bool {
        tokenCount >= 1
    }

    public var showsTooManyAppsNudge: Bool {
        tokenCount > 5
    }

    public var allTokensLabeled: Bool {
        labeledTokens.allSatisfy { labels[$0.hash] != nil }
    }

    public var labeledTokens: [(token: ApplicationToken, hash: String)] {
        selection.applicationTokens.map { token in
            let data = (try? encoder.encode(token)) ?? Data()
            return (token, TokenHasher.hash(encodedToken: data))
        }
    }

    public func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    /// Requests Family Controls authorization. If already approved, advances immediately.
    public func requestAuthorization() async {
        isRequestingAuthorization = true
        authorizationDenied = false
        defer { isRequestingAuthorization = false }

        do {
            let center = AuthorizationCenter.shared
            if center.authorizationStatus == .approved {
                advance()
                return
            }
            try await center.requestAuthorization(for: .individual)
            advance()
        } catch {
            authorizationDenied = true
            errorMessage = error.localizedDescription
        }
    }

    public func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Persists the selection/labels and starts monitoring.
    public func finishOnboarding() async {
        do {
            try selectionStore.saveSelection(selection)
            try selectionStore.saveLabeledApps(
                selection: selection,
                labels: labels,
                now: Date()
            )
            try monitoringService.startMonitoring(
                selection: selection,
                config: .standard
            )
            AppGroup.defaults.set(true, forKey: "meta.onboardingComplete")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private let encoder = JSONEncoder()
}
