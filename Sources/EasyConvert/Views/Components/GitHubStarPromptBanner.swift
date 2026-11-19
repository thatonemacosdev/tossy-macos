import SwiftUI
import AppKit

struct GitHubStarPromptBanner: View {
    @Bindable var settings = AppSettings.shared
    @State private var isHoveringStar: Bool = false
    @State private var isHoveringDismiss: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Star Icon Badge
            ZStack {
                Circle()
                    .fill(settings.appTheme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    .frame(width: 28, height: 28)

                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.yellow)
            }

            // Headline & Non-Intrusive Permanence Note
            VStack(alignment: .leading, spacing: 2) {
                Text("Enjoying Tossy? Support independent development with a GitHub star.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TossyColor.textPrimary)

                Text("Whether you star or say no, you will never see this prompt again.")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(TossyColor.textTertiary)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    TossyHaptic.performFeedback(.alignment)
                    withAnimation(TossyMotion.springSmooth) {
                        settings.dismissGitHubStarPrompt()
                    }
                } label: {
                    Text("No thanks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TossyColor.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isHoveringDismiss ? (settings.appTheme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringDismiss = $0 }
                .help("Dismiss permanently")

                Button {
                    TossyHaptic.performFeedback(.alignment)
                    if let url = URL(string: "https://github.com/thatonemacosdev/tossy-macos") {
                        NSWorkspace.shared.open(url)
                    }
                    withAnimation(TossyMotion.springSmooth) {
                        settings.dismissGitHubStarPrompt()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Star on GitHub")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(TossyColor.accentProminentBg)
                    )
                    .foregroundStyle(TossyColor.accentProminentFg)
                    .opacity(isHoveringStar ? 0.9 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringStar = $0 }
                .help("Open GitHub repository to star Tossy")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(TossyColor.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}
