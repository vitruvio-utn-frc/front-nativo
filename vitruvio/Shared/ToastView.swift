//
//  ToastView.swift
//  vitruvio
//

import SwiftUI

struct Toast: Equatable, Identifiable {
    enum Style {
        case success
        case error

        var systemImage: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .error: "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .success: .green
            case .error: .red
            }
        }
    }

    let id = UUID()
    let message: String
    let style: Style

    static func success(_ message: String) -> Toast { Toast(message: message, style: .success) }
    static func error(_ message: String) -> Toast { Toast(message: message, style: .error) }
}

private struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    let duration: Duration

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    ToastBanner(toast: toast)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { self.toast = nil }
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .animation(.spring(duration: 0.35), value: toast)
            .task(id: toast?.id) {
                guard toast != nil else { return }
                try? await Task.sleep(for: duration)
                if !Task.isCancelled { toast = nil }
            }
    }
}

private struct ToastBanner: View {
    let toast: Toast

    var body: some View {
        Label {
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
        } icon: {
            Image(systemName: toast.style.systemImage)
                .foregroundStyle(toast.style.tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

extension View {
    /// Shows `toast` as a banner at the top and dismisses it after `duration` or on tap.
    func toast(_ toast: Binding<Toast?>, duration: Duration = .seconds(3)) -> some View {
        modifier(ToastModifier(toast: toast, duration: duration))
    }
}
