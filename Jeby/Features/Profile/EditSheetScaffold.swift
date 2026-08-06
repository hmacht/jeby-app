//
//  EditSheetScaffold.swift
//  Jeby
//
//  The shared frame around the three edit sheets: a navigation bar with Cancel
//  and Save, an inline error, and an optional destructive Delete with its
//  confirmation. Each sheet supplies its own form and its own save/delete work.
//

import SwiftUI

struct EditSheetScaffold<Form: View>: View {
    let title: String
    /// Nil on the profile sheet — you can't delete yourself here.
    var deleteTitle: String?
    var canSave: Bool = true
    let save: () async -> Bool
    var delete: (() async -> Bool)?
    @ViewBuilder var form: () -> Form

    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    form()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let deleteTitle {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Text(deleteTitle)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CardStyle.sheetSurface)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await run(save) }
                        }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                    }
                }
            }
        }
        // A half-finished upload shouldn't be swipeable out from under itself.
        .interactiveDismissDisabled(isWorking)
        .confirmationDialog(
            "This can't be undone.",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button(deleteTitle ?? "Delete", role: .destructive) {
                Task { await run(delete ?? { true }) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Runs a save or delete, keeping the sheet open on failure so nothing typed
    /// is lost to a dropped connection.
    private func run(_ work: () async -> Bool) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        if await work() {
            dismiss()
        } else {
            errorMessage = "That didn't save. Check your connection and try again."
        }
    }
}
