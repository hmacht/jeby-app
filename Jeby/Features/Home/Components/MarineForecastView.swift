//
//  MarineForecastView.swift
//  Jeby
//
//  NOAA marine forecast. Shows the next two periods with a "More" button that
//  opens a sheet listing the full forecast.
//

import SwiftUI

struct MarineForecastView: View {
    let forecast: ForecastSummary?
    let location: String

    @State private var showAll = false

    private var periods: [ForecastPeriod] { forecast?.periods ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Marine forecast", systemImage: "cloud.sun")
                if periods.count > 2 {
                    Button("More") { showAll = true }
                        .font(.subheadline.weight(.semibold))
                }
            }

            if periods.isEmpty {
                Text("Forecast unavailable right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(periods.prefix(2)) { period in
                    ForecastPeriodCard(period: period)
                }
            }
        }
        .sheet(isPresented: $showAll) {
            ForecastDetailSheet(forecast: forecast, location: location)
        }
    }
}

struct ForecastPeriodCard: View {
    let period: ForecastPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(period.header.capitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(period.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CardStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ForecastDetailSheet: View {
    let forecast: ForecastSummary?
    let location: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(forecast?.periods ?? []) { period in
                        ForecastPeriodCard(period: period)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Marine Forecast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
