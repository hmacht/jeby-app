//
//  AboutCard.swift
//  Jeby
//
//  The report's closing card — the app's version of the jeby-web site footer:
//  who we are, the open-source API, where the readings come from, and how to
//  get in touch, under the same repeating-squiggle strip.
//

import SwiftUI

struct AboutCard: View {
    private let org = "Jeby Oceanographic Lab"
    private let apiURL = URL(string: "https://github.com/hmacht/jeby-go")!
    private let contactEmail = "henryamacht@gmail.com"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "About", systemImage: "info.circle.fill")

            VStack(alignment: .leading, spacing: 22) {
                mission
                dataSources
                contact
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var mission: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(org)
                .font(.headline)

            Text("A nonprofit oceanographic lab bringing live marine conditions and AI marine analysis to the waters around Martha's Vineyard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: apiURL) {
                HStack(spacing: 8) {
                    Image(.githubLogo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 17, height: 17)
                    Text("Open Source API")
                }
                .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
        }
    }

    private var dataSources: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            source(
                logo: .noaaLogo,
                name: "National Oceanic and Atmospheric Administration",
                abbreviation: "NOAA"
            )
            source(
                logo: .whoiLogo,
                name: "Woods Hole Oceanographic Institution",
                abbreviation: "WHOI"
            )
        }
    }

    private func source(logo: ImageResource, name: String, abbreviation: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)

            Text("\(name) \(Text("(\(abbreviation))").foregroundStyle(.secondary))")
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var contact: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            if let url = URL(string: "mailto:\(contactEmail)") {
                Link(destination: url) {
                    Label(contactEmail, systemImage: "envelope")
                        .font(.subheadline)
                }
            }
        }
    }
}
