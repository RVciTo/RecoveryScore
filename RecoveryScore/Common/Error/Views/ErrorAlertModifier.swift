///
/// ErrorAlertModifier.swift
/// RecoveryScore
///
/// SwiftUI modifier for displaying errors as system alerts.
/// Provides consistent error presentation across the app.
///

import SwiftUI

// MARK: - Error Alert Modifier

public struct ErrorAlertModifier: ViewModifier {
    
    @ObservedObject private var errorManager: ErrorManager
    private let preferBanner: Bool
    
    public init(
        errorManager: ErrorManager,
        preferBanner: Bool = false
    ) {
        self.errorManager = errorManager
        self.preferBanner = preferBanner
    }
    
    public func body(content: Content) -> some View {
        content
            .alert(
                errorManager.currentError?.title ?? "Error",
                isPresented: Binding<Bool>(
                    get: { errorManager.isShowingError && !preferBanner },
                    set: { if !$0 { errorManager.dismissError() } }
                )
            ) {
                alertButtons
            } message: {
                if let errorPresentation = errorManager.getCurrentErrorPresentation() {
                    Text(errorPresentation.message)
                }
            }
    }
    
    @ViewBuilder
    private var alertButtons: some View {
        if let errorPresentation = errorManager.getCurrentErrorPresentation() {
            // Dismiss button (always available)
            if errorPresentation.isDismissable {
                Button("OK") {
                    errorManager.dismissError()
                }
            }
            
            // Retry button (if retryable)
            if errorPresentation.isRetryable {
                Button("Retry") {
                    errorManager.retryLastOperation()
                }
            }
            
            // Action buttons from error presentation
            ForEach(errorPresentation.actions.prefix(2), id: \.self) { actionTitle in
                Button(actionTitle) {
                    handleActionButton(actionTitle)
                }
            }
        } else {
            Button("OK") {
                errorManager.dismissError()
            }
        }
    }
    
    private func handleActionButton(_ actionTitle: String) {
        switch actionTitle.lowercased() {
        case "open settings", "settings":
            openSettings()
        case "contact support", "support":
            // Could implement support contact flow
            break
        default:
            // Generic action - just dismiss for now
            errorManager.dismissError()
        }
    }
    
    private func openSettings() {
        errorManager.dismissError()
        
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - View Extension

public extension View {
    
    /// Show errors as system alerts
    func errorAlert(errorManager: ErrorManager? = nil) -> some View {
        let manager = errorManager ?? ErrorManager.shared
        return modifier(ErrorAlertModifier(errorManager: manager, preferBanner: false))
    }
    
    /// Show errors as banners, with alert fallback for critical errors  
    func errorBannerWithAlertFallback(errorManager: ErrorManager? = nil) -> some View {
        let manager = errorManager ?? ErrorManager.shared
        return modifier(ErrorBannerModifier(errorManager: manager))
            .modifier(ErrorAlertModifier(
                errorManager: manager,
                preferBanner: true
            ))
    }
}

// MARK: - Error Sheet Modifier

public struct ErrorSheetModifier: ViewModifier {
    
    @ObservedObject private var errorManager: ErrorManager
    @State private var showingSheet = false
    
    public init(errorManager: ErrorManager) {
        self.errorManager = errorManager
    }
    
    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingSheet) {
                if let errorPresentation = errorManager.getCurrentErrorPresentation() {
                    ErrorDetailView(
                        errorPresentation: errorPresentation,
                        errorHistory: errorManager.errorHistory,
                        onDismiss: {
                            showingSheet = false
                            errorManager.dismissError()
                        },
                        onRetry: errorPresentation.isRetryable ? {
                            showingSheet = false
                            errorManager.retryLastOperation()
                        } : nil
                    )
                }
            }
            .onChange(of: errorManager.isShowingError) { _, isShowing in
                // Only show sheet for critical errors
                if isShowing, 
                   let error = errorManager.currentError,
                   error.severity == .critical {
                    showingSheet = true
                }
            }
    }
}

// MARK: - Error Detail View

public struct ErrorDetailView: View {
    
    let errorPresentation: ErrorPresentation
    let errorHistory: [ErrorHistoryEntry]
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Error Icon and Title
                    VStack(spacing: 16) {
                        Image(systemName: errorPresentation.alertStyle.systemImage)
                            .font(.system(size: 48))
                            .foregroundColor(errorPresentation.alertStyle.color)
                        
                        Text(errorPresentation.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    
                    // Error Message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(errorPresentation.message)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Suggested Actions
                    if !errorPresentation.actions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested Actions")
                                .font(.headline)
                            
                            ForEach(errorPresentation.actions, id: \.self) { action in
                                HStack {
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(errorPresentation.alertStyle.color)
                                    Text(action)
                                }
                                .font(.body)
                            }
                        }
                    }
                    
                    // Recent Errors (Debug Info)
                    if !errorHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Issues")
                                .font(.headline)
                            
                            ForEach(errorHistory.suffix(3)) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Circle()
                                            .fill(entry.error.severity == .critical ? Color.red : Color.orange)
                                            .frame(width: 6, height: 6)
                                        
                                        Text(entry.error.title)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text(entry.timestamp, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if entry.wasRetried || entry.wasResolved {
                                        HStack {
                                            if entry.wasRetried {
                                                Image(systemName: "arrow.clockwise")
                                                Text("Retried")
                                            }
                                            if entry.wasResolved {
                                                Image(systemName: "checkmark")
                                                Text("Resolved")
                                            }
                                        }
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Error Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if errorPresentation.isDismissable {
                        Button("Close") {
                            dismiss()
                            onDismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let onRetry = onRetry {
                        Button("Retry") {
                            dismiss()
                            onRetry()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

public extension View {
    /// Show critical errors as full-screen sheets
    func errorSheet(errorManager: ErrorManager? = nil) -> some View {
        let manager = errorManager ?? ErrorManager.shared
        return modifier(ErrorSheetModifier(errorManager: manager))
    }
}