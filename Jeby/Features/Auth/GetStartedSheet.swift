//
//  GetStartedSheet.swift
//  Jeby
//
//  The sign-in gate. Reading conditions needs no account; writing to the backend
//  — posting a report, saving your boats — does. Tapping the camera or profile
//  button while signed out lands here instead of failing later.
//

import AuthenticationServices
import SwiftUI

struct GetStartedSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEmailForm = false

    var body: some View {
        VStack(spacing: 0) {
            // Centered in the space above the actions when it fits, scrollable
            // when it doesn't — large Dynamic Type overflows an iPhone SE.
            ViewThatFits(in: .vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 0)
                    header
                    perks
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        perks
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            signInActions
        }
        .background(CardStyle.sheetSurface)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(CardStyle.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 16)
            .accessibilityLabel("Close")
        }
        .sheet(isPresented: $showEmailForm) {
            EmailAuthView()
        }
        // Closing the email form is this sheet's business; closing the gate
        // isn't. HomeView owns that, because a brand-new account has to go
        // straight into onboarding rather than back to the map.
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn { showEmailForm = false }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "water.waves")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(CardStyle.gradient(base: .blue), in: RoundedRectangle(cornerRadius: 18))
                .padding(.bottom, 4)

            Text("Get started")
                .font(.largeTitle.weight(.bold))

            Text("Conditions are open to everyone. Sign in to add your own reports and boats.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var perks: some View {
        VStack(alignment: .leading, spacing: 18) {
            perk(
                icon: "camera.fill",
                title: "Post a report",
                detail: "Share a photo and how bumpy it really was."
            )
            perk(
                icon: "sailboat.fill",
                title: "Save your boats",
                detail: "Keep your own vessels and their specs on hand."
            )
            perk(
                icon: "square.stack.3d.up.fill",
                title: "Join the feed",
                detail: "Your reports show up alongside everyone else's."
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func perk(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var signInActions: some View {
        VStack(spacing: 12) {
            if let errorMessage = auth.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SignInWithAppleButton(.signIn) { request in
                auth.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await auth.completeAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                showEmailForm = true
            } label: {
                Text("Continue with email")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                    // The action bar's material washes the fill out; the stroke
                    // is what makes this read as a button next to Apple's.
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.primary.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Text("We only ever store your name and email.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        // Clears the home indicator; without it the fine print gets clipped.
        .padding(.bottom, 20)
        .disabled(auth.isWorking)
        .opacity(auth.isWorking ? 0.5 : 1)
        .overlay {
            if auth.isWorking {
                ProgressView()
            }
        }
        .background(.ultraThinMaterial)
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            GetStartedSheet()
                .environment(AuthService())
                .presentationDetents([.medium, .large])
        }
        .preferredColorScheme(.dark)
}
