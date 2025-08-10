//
//  DriversCardView.swift
//  RecoveryScore
//

import SwiftUI

struct DriversCardView: View {
    @ObservedObject var viewModel: RecoveryBiometricsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("What influenced your score")
                    .font(.headline)
                Spacer()
            }
            HStack(alignment: .top, spacing: 16) {
                DriverList(title: "Helped", items: viewModel.helpedDrivers, positive: true)
                DriverList(title: "Hurt", items: viewModel.hurtDrivers, positive: false)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DriverList: View {
    let title: String
    let items: [DriverItem]
    let positive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(positive ? .green : .red)
            if items.isEmpty {
                Text(positive ? "No major positives today." : "No major negatives today.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: item.icon)
                        Text(item.name).font(.callout).bold()
                        Spacer(minLength: 8)
                        Text(item.change).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
