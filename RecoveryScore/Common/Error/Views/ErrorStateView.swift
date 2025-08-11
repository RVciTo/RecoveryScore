///
/// ErrorStateView.swift
/// RecoveryScore
///
/// SwiftUI view for displaying error states with retry functionality.
/// Used when entire views need to show error states instead of overlays.
///

import SwiftUI

// MARK: - Error State View

public struct ErrorStateView: View {
    
    // MARK: - Properties
    
    let errorPresentation: ErrorPresentation
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    private var primaryColor: Color {
        errorPresentation.alertStyle.color
    }
    
    private var systemImage: String {
        errorPresentation.alertStyle.systemImage
    }
    
    // MARK: - Initialization
    
    public init(
        errorPresentation: ErrorPresentation,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.errorPresentation = errorPresentation
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 24) {
            // Error Icon
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundColor(primaryColor)
                .accessibilityHidden(true)
            
            // Error Content
            VStack(spacing: 16) {
                Text(errorPresentation.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(errorPresentation.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, 32)
            
            // Action Buttons
            VStack(spacing: 12) {
                if errorPresentation.isRetryable, let retry = onRetry {
                    Button {
                        retry()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(primaryColor)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Retry the failed operation")
                }
                
                // Secondary actions from error presentation
                ForEach(errorPresentation.actions.prefix(2), id: \.self) { actionTitle in
                    Button(actionTitle) {
                        handleActionButton(actionTitle)
                    }
                    .font(.subheadline)
                    .foregroundColor(primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(primaryColor, lineWidth: 1)
                    )
                }
                
                if errorPresentation.isDismissable, let dismiss = onDismiss {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error state: \(errorPresentation.title)")
        .accessibilityHint(errorPresentation.message)
    }
    
    // MARK: - Action Handling
    
    private func handleActionButton(_ actionTitle: String) {
        switch actionTitle.lowercased() {
        case "open settings", "settings":
            openSettings()
        case "contact support", "support":
            // Could implement support contact flow
            onDismiss?()
        default:
            // Generic action - just dismiss
            onDismiss?()
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
        onDismiss?()
    }
}

// MARK: - Convenience Initializers

public extension ErrorStateView {
    
    /// Create error state view from ErrorManager
    init(
        errorManager: ErrorManager,
        onRetry: (() -> Void)? = nil,
        customDismiss: (() -> Void)? = nil
    ) {
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
                onRetry: onRetry,
                onDismiss: customDismiss ?? { errorManager.dismissError() }
            )
            return
        }
        
        self.init(
            errorPresentation: presentation,
            onRetry: onRetry ?? (presentation.isRetryable ? { errorManager.retryLastOperation() } : nil),
            onDismiss: customDismiss ?? { errorManager.dismissError() }
        )
    }
    
    /// Create error state from RecoveryError directly
    init(
        error: RecoveryError,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        let summary = error.userSummary()
        let presentation = ErrorPresentation(
            title: summary.title,
            message: summary.message,
            severity: error.severity,
            actions: summary.actions,
            isRetryable: error.isRetryable && onRetry != nil,
            isDismissable: true
        )
        
        self.init(
            errorPresentation: presentation,
            onRetry: onRetry,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Loading State View

public struct LoadingStateView: View {
    
    let message: String
    let showProgress: Bool
    
    public init(message: String = "Loading...", showProgress: Bool = true) {
        self.message = message
        self.showProgress = showProgress
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            if showProgress {
                ProgressView()
                    .scaleEffect(1.2)
                    .accessibilityLabel("Loading")
            }
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Empty State View

public struct EmptyStateView: View {
    
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    public init(
        title: String,
        message: String,
        systemImage: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Preview

#if DEBUG
struct ErrorStateView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            // Error State
            ErrorStateView(
                errorPresentation: ErrorPresentation(
                    title: "Health Data Unavailable",
                    message: "Unable to access your health data. Please check your permissions in the Health app and try again.",
                    severity: .error,
                    actions: ["Open Settings"],
                    isRetryable: true,
                    isDismissable: true
                ),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Error State")
            
            // Loading State
            LoadingStateView(message: "Loading your health data...")
                .previewDisplayName("Loading State")
            
            // Empty State
            EmptyStateView(
                title: "No Data Available",
                message: "We need at least 7 days of health data to calculate your readiness score.",
                systemImage: "heart.text.square",
                actionTitle: "Check Health App",
                action: {}
            )
            .previewDisplayName("Empty State")
        }
    }
}
#endif