//
//  FormField.swift
//  Jeby
//
//  The labeled text field used by the onboarding steps and the edit sheets, so
//  a boat's specs look the same wherever you're typing them.
//

import SwiftUI

/// A labeled field. Values are free-form text because specs are ranges
/// ("26-65 ft") or unknown, matching how the backend stores them.
struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $value)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
