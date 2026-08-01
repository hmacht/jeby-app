//
//  TunedForView.swift
//  Jeby
//
//  "Tuned for" card describing the vessel the BumpyScore is currently computed
//  for, with its specs.
//

import SwiftUI

struct TunedForView: View {
    let vessel: Vessel

    private var specs: [(String, String)] {
        [
            ("Length", vessel.length),
            ("Weight", vessel.weight),
            ("Horsepower", vessel.horsepower),
            ("Max passengers", vessel.maxPassengers),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Vessel", systemImage: "sailboat")

            VStack(alignment: .leading, spacing: 12) {
                Text(vessel.name)
                    .font(.title3.weight(.semibold))

                Text(vessel.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                ForEach(specs, id: \.0) { spec in
                    HStack {
                        Text(spec.0)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(spec.1)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
