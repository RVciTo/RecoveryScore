import SwiftUI

/// A reusable score display component for metrics like Readiness, Adherence, Nutrition, etc.
/// This card shows the metric title, a colored numeric score, a description or status, and a "See why this score" link.
struct ScoreCardView: View {
    /// The title of the score, e.g., "Readiness", "Adherence"
    let title: String

    /// The numeric score (0–100 recommended)
    let score: Int

    /// Optional destination view for tapping the entire card
    let tapDestination: AnyView?

    /// Optional destination view for tapping "See why this score"
    let seeWhyDestination: AnyView?

    /// Controls whether to show the full-screen readiness explanation
    @Binding var showReadinessExplanation: Bool

    /// Custom initializer with default for showReadinessExplanation
    /// so you don’t have to pass it everywhere.
    init(
        title: String,
        score: Int,
        tapDestination: AnyView? = nil,
        seeWhyDestination: AnyView? = nil,
        showReadinessExplanation: Binding<Bool> = .constant(false)
    ) {
        self.title = title
        self.score = score
        self.tapDestination = tapDestination
        self.seeWhyDestination = seeWhyDestination
        self._showReadinessExplanation = showReadinessExplanation
    }

    var body: some View {
        Group {
            if let tapDestination = tapDestination {
                NavigationLink(destination: tapDestination) {
                    cardContent
                }
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(score)")
                    .font(.largeTitle.bold())
                    .foregroundColor(scoreColor(score))
            }

            if let seeWhyDestination = seeWhyDestination {
                NavigationLink(destination: seeWhyDestination) {
                    Text("See why this score")
                        .font(.footnote)
                        .underline()
                        .accessibilityLabel("See explanation for \(title) score")
                }
            } else {
                Button(action: {}) {
                    Text("See why this score")
                        .font(.footnote)
                        .underline()
                        .accessibilityLabel("See explanation for \(title) score")
                }
                .disabled(true)
                .opacity(0)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) score \(score)")
    }

    /// Applies consistent color logic based on score range.
    func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}
