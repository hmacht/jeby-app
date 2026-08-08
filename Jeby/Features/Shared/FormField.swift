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
    /// A fixed unit shown inside the field's trailing edge — "ft", "lb", "hp".
    /// The unit is a property of the field, not something the user types, which
    /// is why it's decoration rather than part of the value.
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField(placeholder, text: $value)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(autocapitalization)

                if let unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// A numeric spec field: decimal keypad, unit label, no autocapitalization.
struct SpecFormField: View {
    let label: String
    let placeholder: String
    let unit: String
    @Binding var value: String
    var allowsDecimal = true

    var body: some View {
        FormField(
            label: label,
            placeholder: placeholder,
            value: $value,
            keyboard: allowsDecimal ? .decimalPad : .numberPad,
            autocapitalization: .never,
            unit: unit
        )
    }
}
