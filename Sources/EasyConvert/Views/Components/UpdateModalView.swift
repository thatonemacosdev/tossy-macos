import SwiftUI

struct UpdateModalView: View {
    let release: AppReleaseInfo
    @Bindable var updateManager = UpdateManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            HStack(alignment: .top, spacing: 14) {
                if let logoURL = Bundle.main.url(forResource: "TossyLogo", withExtension: "png"),
                   let nsImg = NSImage(contentsOf: logoURL) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(TossyColor.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("A new version of Tossy is available!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TossyColor.textPrimary)
                    
                    Text("Tossy \(release.versionNumber) is now available (you have \(AppVersion.string)). Would you like to install it now?")
                        .font(.system(size: 12))
                        .foregroundStyle(TossyColor.textSecondary)
                }
                
                Spacer()
            }
            .padding(18)
            .background(TossyColor.surfaceDeep)
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // Release Notes / Change Log View
            VStack(alignment: .leading, spacing: 6) {
                Text("Release Notes:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TossyColor.textSecondary)
                
                ScrollView(.vertical) {
                    Text(cleanReleaseNotes(release.body))
                        .font(.system(size: 12, design: .default))
                        .foregroundStyle(TossyColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 180)
                .background(TossyColor.surfaceBase)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                )
            }
            .padding(16)
            
            // Error Message (if any)
            if let errorMsg = updateManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(TossyColor.errorRed)
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(TossyColor.errorRed)
                    Spacer()
                    Button("Open in Browser") {
                        NSWorkspace.shared.open(release.htmlURL)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // Action Controls
            HStack {
                if updateManager.isDownloading {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: max(0.02, updateManager.downloadProgress), total: 1.0)
                            .progressViewStyle(.linear)
                        
                        Text(updateManager.installStatusText)
                            .font(.caption2)
                            .foregroundStyle(TossyColor.textSecondary)
                    }
                    .frame(maxWidth: 320)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        updateManager.cancelDownload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                } else {
                    Button("Skip This Version") {
                        updateManager.skipVersion(release.tagName)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(TossyColor.textTertiary)
                    
                    Spacer()
                    
                    Button("Remind Me Later") {
                        updateManager.isShowingUpdateModal = false
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    Button {
                        updateManager.downloadAndInstall(release: release)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Update Now")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TossyColor.accentProminentBg)
                    .foregroundStyle(TossyColor.accentProminentFg)
                    .controlSize(.regular)
                }
            }
            .padding(14)
            .background(TossyColor.surfaceDeep)
        }
        .frame(width: 520)
        .background(TossyColor.pitchBlack)
        .preferredColorScheme(AppSettings.shared.appTheme == .light ? .light : .dark)
    }
    
    private func cleanReleaseNotes(_ text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return "No detailed release notes provided for this version."
        }
        return cleaned
    }
}
