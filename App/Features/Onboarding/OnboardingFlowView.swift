import FamilyControls
import ManagedSettings
import ScrollCore
import SwiftUI

/// Root onboarding container. Switches between the 5 step views.
public struct OnboardingFlowView: View {
    @State private var model: OnboardingModel

    public init(selectionStore: SelectionStore) {
        _model = State(wrappedValue: OnboardingModel(selectionStore: selectionStore))
    }

    public var body: some View {
        Group {
            switch model.step {
            case .hook:
                HookStepView(model: model)
            case .auth:
                AuthStepView(model: model)
            case .picker:
                PickerStepView(model: model)
            case .label:
                LabelStepView(model: model)
            case .finish:
                FinishStepView(model: model)
            }
        }
    }
}

// MARK: - Step 1: Hook

private struct HookStepView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("How far does your thumb travel?")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            Text("Scrollometer estimates the distance you scroll in your most-used apps.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Everything stays on your iPhone. We can't see what you watch — or that you watch anything at all.")
                .font(.callout)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Continue") {
                model.advance()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

// MARK: - Step 2: Authorization

private struct AuthStepView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: 24) {
            if model.authorizationDenied {
                Spacer()
                Text("Screen Time access is required")
                    .font(.title2)
                Text("Scrollometer uses Apple's Screen Time API to measure app usage. The data never leaves your device.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    model.openSettings()
                }
                .buttonStyle(.bordered)
                Button("Try Again") {
                    Task { await model.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Spacer()
            } else {
                Spacer()
                ProgressView("Requesting Screen Time access…")
                Spacer()
            }
        }
        .padding()
        .task {
            await model.requestAuthorization()
        }
    }
}

// MARK: - Step 3: Picker

private struct PickerStepView: View {
    @Bindable var model: OnboardingModel
    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Choose your most tempting apps")
                .font(.title2)
                .multilineTextAlignment(.center)

            if model.showsTooManyAppsNudge {
                Text("Pick your top 5 tempting apps for the cleanest experience.")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Button("Select Apps") {
                showingPicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .familyActivityPicker(isPresented: $showingPicker, selection: $model.selection)

            Text("\(model.tokenCount) app\(model.tokenCount == 1 ? "" : "s") selected")
                .foregroundStyle(.secondary)

            Spacer()

            Button("Continue") {
                model.advance()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canAdvanceFromPicker)
        }
        .padding()
    }
}

// MARK: - Step 4: Label

private struct LabelStepView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Label each app")
                    .font(.title2)
                Text("This helps Scrollometer estimate how fast you scroll.")
                    .foregroundStyle(.secondary)

                ForEach(model.labeledTokens, id: \.hash) { item in
                    AppLabelRow(
                        token: item.token,
                        hash: item.hash,
                        selectedLabel: binding(for: item.hash)
                    )
                }

                Button("Finish") {
                    model.advance()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.allTokensLabeled)
            }
            .padding()
        }
    }

    private func binding(for hash: String) -> Binding<AppLabel?> {
        Binding(
            get: { model.labels[hash] },
            set: { model.labels[hash] = $0 }
        )
    }
}

private struct AppLabelRow: View {
    let token: ApplicationToken
    let hash: String
    @Binding var selectedLabel: AppLabel?

    var body: some View {
        HStack(spacing: 16) {
            Label(token)
            Spacer()
            ForEach(AppLabel.allCases, id: \.self) { label in
                Button(label.displayName) {
                    selectedLabel = label
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedLabel == label ? .accentColor : .secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Step 5: Finish

private struct FinishStepView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("You're all set")
                .font(.title2)
            Text("First numbers appear within about an hour of scrolling.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding()
        .task {
            await model.finishOnboarding()
        }
    }
}
