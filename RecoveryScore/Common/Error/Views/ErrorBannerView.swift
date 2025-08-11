///
/// ErrorBannerView.swift
/// RecoveryScore
///
/// SwiftUI banner component for displaying errors at the top of views.
/// Integrates with ErrorManager for consistent error presentation.
///

import SwiftUI

public struct ErrorBannerView: View {
    
    // MARK: - Properties
    
    let errorPresentation: ErrorPresentation
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    @State private var isVisible: Bool = false
    
    // MARK: - Initialization
    
    public init(
        errorPresentation: ErrorPresentation,
        onDismiss: @escaping () -> Void,
        onRetry: (() -> Void)? = nil
    ) {
        self.errorPresentation = errorPresentation
        self.onDismiss = onDismiss
        self.onRetry = onRetry
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: errorPresentation.alertStyle.systemImage)
                        .foregroundColor(errorPresentation.alertStyle.color)
                        .font(.title3)
                        .accessibilityHidden(true)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(errorPresentation.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(errorPresentation.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        if errorPresentation.isRetryable, let retry = onRetry {
                            Button("Retry") {
                                retry()
                            }
                            .font(.caption)
                            .foregroundColor(errorPresentation.alertStyle.color)
                        }
                        
                        if errorPresentation.isDismissable {
                            Button {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isVisible = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDismiss()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                            .accessibilityLabel("Dismiss error")
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(errorPresentation.alertStyle.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(errorPresentation.alertStyle.color.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(errorPresentation.severity.rawValue.capitalized) error: \(errorPresentation.title)")
        .accessibilityHint(errorPresentation.message)
    }
}

// MARK: - Convenience Initializers

public extension ErrorBannerView {
    
    /// Create banner directly from ErrorManager
    init(errorManager: ErrorManager) {
        guard let presentation = errorManager.getCurrentErrorPresentation() else {
            self.init(
                errorPresentation: ErrorPresentation(
                    title: "Unknown Error",
                    message: "An unknown error occurred",
                    severity: .error,
                    actions: [],
                    isRetryable: false,
                    isDismissable: true
                ),
                onDismiss: {},
                onRetry: nil
            )
            return
        }
        
        self.init(
            errorPresentation: presentation,
            onDismiss: { errorManager.dismissError() },
            onRetry: presentation.isRetryable ? { errorManager.retryLastOperation() } : nil
        )
    }
}

// MARK: - View Modifier

public struct ErrorBannerModifier: ViewModifier {
    
    @ObservedObject private var errorManager: ErrorManager
    
    public init(errorManager: ErrorManager) {
        self.errorManager = errorManager
    }
    
    public func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if errorManager.isShowingError {
                ErrorBannerView(errorManager: errorManager)
                    .zIndex(1000) // Ensure banner appears above content
            }
            
            content
        }
    }
}

public extension View {
    /// Show error banner when errors occur
    func errorBanner(errorManager: ErrorManager? = nil) -> some View {
        let manager = errorManager ?? ErrorManager.shared
        return modifier(ErrorBannerModifier(errorManager: manager))
    }
}

// MARK: - Preview

#if DEBUG
struct ErrorBannerView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            // Info Error
            ErrorBannerView(
                errorPresentation: ErrorPresentation(
                    title: "Information",
                    message: "This is an informational message to let you know about something.",
                    severity: .info,
                    actions: [],
                    isRetryable: false,
                    isDismissable: true
                ),
                onDismiss: {}
            )
            .previewDisplayName("Info Banner")
            
            // Warning Error
            ErrorBannerView(
                errorPresentation: ErrorPresentation(
                    title: "Missing Data",
                    message: "Some secondary metrics are missing. Score accuracy may be affected.",
                    severity: .warning,
                    actions: ["Check Settings"],
                    isRetryable: true,
                    isDismissable: true
                ),
                onDismiss: {},
                onRetry: {}
            )
            .previewDisplayName("Warning Banner with Retry")
            
            // Error
            ErrorBannerView(
                errorPresentation: ErrorPresentation(
                    title: "Health Data Error",
                    message: "Unable to access heart rate data. Please check your Health app permissions.",
                    severity: .error,
                    actions: ["Open Settings"],
                    isRetryable: true,
                    isDismissable: true
                ),
                onDismiss: {},
                onRetry: {}
            )
            .previewDisplayName("Error Banner")
            
            // Critical Error
            ErrorBannerView(
                errorPresentation: ErrorPresentation(
                    title: "Critical System Error",
                    message: "A critical error has occurred that requires immediate attention.",
                    severity: .critical,
                    actions: ["Contact Support"],
                    isRetryable: false,
                    isDismissable: false
                ),
                onDismiss: {}
            )
            .previewDisplayName("Critical Banner")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif