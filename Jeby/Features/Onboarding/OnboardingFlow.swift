//
//  OnboardingFlow.swift
//  Jeby
//
//  The container for the post-sign-up flow: a progress row, the current step,
//  and the Continue/Skip pair. Every step is skippable — whatever gets skipped
//  shows up on the profile page as an incomplete piece.
//

import SwiftUI

struct OnboardingFlow: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    /// Where to start. The profile page passes the step for the piece the user
    /// tapped; a fresh sign-up starts at the beginning.
    var startingStep: OnboardingStep = .name
    /// True when resuming for one specific piece, so finishing it returns to the
    /// profile instead of continuing through the rest of the flow.
    var singleStep = false

    @State private var model: OnboardingViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(CardStyle.sheetSurface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // An escape hatch out of the whole flow, not just this step.
                    // "Skip for now" below already handles leaving one step.
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .disabled(model?.isSaving ?? false)
                    .accessibilityLabel("Close")
                }
            }
        }
        .interactiveDismissDisabled(model?.isSaving ?? false)
        .task {
            // Built here rather than in an initializer because it needs the
            // environment's AuthService.
            if model == nil {
                model = OnboardingViewModel(auth: auth, startingAt: startingStep, singleStep: singleStep)
            }
        }
    }

    @ViewBuilder
    private func content(_ model: OnboardingViewModel) -> some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            if !singleStep {
                progress(current: model.stepIndex)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            ScrollView {
                VStack(spacing: 28) {
                    switch model.step {
                    case .name:
                        NameStep(name: $model.name, bio: $model.bio, image: $model.profileImage)
                    case .boat:
                        BoatStep(
                            name: $model.boatName,
                            description: $model.boatDescription,
                            homeHarbor: $model.boatHomeHarbor,
                            length: $model.boatLength,
                            weight: $model.boatWeight,
                            horsepower: $model.boatHorsepower,
                            maxPassengers: $model.boatMaxPassengers,
                            image: $model.boatImage
                        )
                    case .pet:
                        PetStep(name: $model.petName, image: $model.petImage)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            actions(model)
        }
        .onChange(of: model.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }

    /// One dot per step, the current one stretched into a bar.
    private func progress(current: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(OnboardingStep.allCases.enumerated()), id: \.element) { index, _ in
                Capsule()
                    .fill(index <= current ? Color.accentColor : CardStyle.surface)
                    .frame(width: index == current ? 28 : 8, height: 8)
                    .animation(.snappy, value: current)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actions(_ model: OnboardingViewModel) -> some View {
        VStack(spacing: 12) {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await model.continueFromCurrentStep() }
            } label: {
                Group {
                    if model.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(model.step == .pet || singleStep ? "Done" : "Continue")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(model.isSaving)

            Button("Skip for now") {
                model.skipCurrentStep()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .disabled(model.isSaving)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            OnboardingFlow()
                .environment(AuthService())
        }
        .preferredColorScheme(.dark)
}
