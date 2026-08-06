//
//  EmailAuthView.swift
//  Jeby
//
//  Email and password, for people who'd rather not use Apple. One screen that
//  toggles between creating an account and signing in — creating one is what
//  leads into onboarding.
//

import SwiftUI

struct EmailAuthView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    /// Which side of the form we're on. Sign-up is the default because this is
    /// reached from the Get Started card.
    @State private var mode: Mode = .signUp
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focused: Field?

    private enum Mode {
        case signUp, signIn

        var title: String { self == .signUp ? "Create account" : "Welcome back" }
        var action: String { self == .signUp ? "Create account" : "Sign in" }
        var toggleprompt: String {
            self == .signUp ? "Already have an account? Sign in" : "New here? Create an account"
        }
    }

    private enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(mode.title)
                        .font(.largeTitle.weight(.bold))
                        .padding(.top, 8)

                    fields
                    messages
                    submitButton

                    if mode == .signIn {
                        Button("Forgot password?") {
                            Task { await auth.sendPasswordReset(email: email) }
                        }
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                        .disabled(email.isEmpty || auth.isWorking)
                    }

                    Button(mode.toggleprompt) {
                        withAnimation(.snappy) {
                            mode = mode == .signUp ? .signIn : .signUp
                        }
                        auth.clearMessages()
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CardStyle.sheetSurface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { auth.clearMessages() }
    }

    private var fields: some View {
        VStack(spacing: 14) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .fieldStyle()

            SecureField("Password", text: $password)
                // .newPassword prompts iOS to offer a strong one on sign-up and
                // stops it autofilling the wrong saved credential.
                .textContentType(mode == .signUp ? .newPassword : .password)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await submit() } }
                .fieldStyle()
        }
    }

    @ViewBuilder
    private var messages: some View {
        if let errorMessage = auth.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let noticeMessage = auth.noticeMessage {
            Text(noticeMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            Group {
                if auth.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(mode.action)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!isValid || auth.isWorking)
        .opacity(isValid ? 1 : 0.5)
    }

    /// Cheap client-side gate so an obviously empty form doesn't round-trip.
    /// Firebase does the real validation and its errors surface above.
    private var isValid: Bool {
        email.contains("@") && password.count >= 6
    }

    private func submit() async {
        guard isValid else { return }
        focused = nil

        switch mode {
        case .signUp: await auth.signUp(email: email, password: password)
        case .signIn: await auth.signIn(email: email, password: password)
        }
        // Sign-in flips the whole gate closed; GetStartedSheet watches for that
        // and dismisses the stack.
    }
}

private extension View {
    func fieldStyle() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    EmailAuthView()
        .environment(AuthService())
        .preferredColorScheme(.dark)
}
