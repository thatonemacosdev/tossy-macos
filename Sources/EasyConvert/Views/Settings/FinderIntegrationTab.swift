import SwiftUI

struct FinderIntegrationTab: View {
    @Bindable var settings = AppSettings.shared
    @Bindable var finderManager = FinderIntegrationManager.shared
    
    var body: some View {
        Form {
            Section("Right-Click Action Behavior") {
                Picker("When Right-Clicking Files in Finder", selection: $settings.finderActionBehavior) {
                    ForEach(FinderActionBehavior.allCases) { behavior in
                        Text(behavior.rawValue).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text(settings.finderActionBehavior == .silentBackground 
                     ? "Opens the sleek Mini Tossy quick-convert popup to choose your target format and convert directly."
                     : "Files will be automatically added to the full Tossy batch queue and the window will be brought to focus.")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
            }
            
            Section("Finder Quick Action Installation") {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(finderManager.isInstalled ? "Finder Quick Action Active" : "Quick Action Not Installed")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(finderManager.isInstalled ? TossyColor.successGreen : TossyColor.textPrimary)
                        
                        Text(finderManager.statusMessage ?? "Adds 'Convert with Tossy' directly into macOS Finder right-click Quick Actions to open the Mini Tossy format picker.")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                    }
                    
                    Spacer()
                    
                    if finderManager.isInstalling {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(finderManager.isInstalled ? "Reinstall Quick Action" : "Install Quick Action") {
                            finderManager.installQuickActions()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
                .padding(.vertical, 4)
                
                if finderManager.isInstalled {
                    Button("Remove Finder Quick Action") {
                        finderManager.uninstallQuickActions()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(TossyColor.errorRed)
                }
            }
            
            Section("Mini Tossy Fast Conversion Formats") {
                Text("Selecting 'Convert with Tossy' in Finder opens the format picker for:")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Group {
                        FormatBadge(name: "PNG, JPEG, WebP", category: "Images")
                        FormatBadge(name: "JPEG XL, HEIC, GIF", category: "Images")
                        FormatBadge(name: "MP4 (H.264 / HEVC)", category: "Videos")
                        FormatBadge(name: "MKV, WebM, ProRes", category: "Videos")
                        FormatBadge(name: "MP3, FLAC, WAV", category: "Audio")
                        FormatBadge(name: "AAC, OGG, ALAC", category: "Audio")
                    }
                }
                .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            finderManager.checkInstallationStatus()
        }
    }
}

private struct FormatBadge: View {
    let name: String
    let category: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(TossyColor.successGreen)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TossyColor.textPrimary)
                Text(category)
                    .font(.system(size: 9))
                    .foregroundStyle(TossyColor.textTertiary)
            }
            Spacer()
        }
        .padding(8)
        .background(TossyColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
