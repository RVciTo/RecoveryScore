//
//  MetricChipView.swift
//  RecoveryScore
//

import SwiftUI

struct MetricChipView: View {
    let title: String
    let value: String
    let subvalue: String?
    let deltaText: String?
    let systemImage: String
    let tint: Color
    let timestamp: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .imageScale(.medium)
                Text(title)
                    .font(.subheadline).bold()
                Spacer()
            }
            Text(value)
                .font(.title3).bold()
                .foregroundStyle(.primary)
            if let sub = subvalue {
                Text(sub).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                if let delta = deltaText {
                    Text(delta).font(.footnote)
                }
                Spacer()
                if let ts = timestamp {
                    Text(ts).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}
