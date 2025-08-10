//
//  SparklineView.swift
//  RecoveryScore
//

import SwiftUI

struct SparklineView: View {
    let values: [Double]

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        // Handle empty/one-point series by duplicating the last value so we can draw a flat line
        guard !values.isEmpty else { return [] }
        let series: [Double] = (values.count == 1) ? [values[0], values[0]] : values
        guard let minV = series.min(), let maxV = series.max() else { return [] }
        let range = max(maxV - minV, 0.000001)
        let isFlat = (maxV - minV) < 0.000001
        return series.enumerated().map { idx, v in
            let x = size.width * CGFloat(idx) / CGFloat(series.count - 1)
            let yNorm = (v - minV) / range
            let y = isFlat ? size.height * 0.5 : size.height * (1 - CGFloat(yNorm))
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let pts = normalizedPoints(in: geo.size)
            ZStack {
                if pts.count > 1 {
                    Path { p in
                        p.move(to: pts.first!)
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(.secondary.opacity(0.6), lineWidth: 2)

                    // Last point marker
                    if let last = pts.last {
                        Circle()
                            .fill(Color.secondary.opacity(0.9))
                            .frame(width: 4, height: 4)
                            .position(last)
                    }
                }
            }
        }
    }
}
