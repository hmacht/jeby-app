//
//  VesselPicker.swift
//  Jeby
//
//  Native menu for choosing which vessel the BumpyScore is computed for.
//

import SwiftUI

struct VesselPicker: View {
    let vessels: [Vessel]
    let selected: String
    let disabled: Bool
    let onSelect: (String) -> Void

    private var selectedName: String {
        vessels.first { $0.code == selected }?.name ?? "Select vessel"
    }

    var body: some View {
        Menu {
            ForEach(vessels) { vessel in
                Button {
                    onSelect(vessel.code)
                } label: {
                    if vessel.code == selected {
                        Label(vessel.name, systemImage: "checkmark")
                    } else {
                        Text(vessel.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedName)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(CardStyle.surface, in: Capsule())
        }
        .disabled(disabled)
    }
}
