import SwiftUI

struct FinderIntegrationTab: View {
    @Bindable var settings = AppSettings.shared
    @Bindable var finderManager = FinderIntegrationManager.shared
    
    var body: some View {
        Form {
            Section("Right-Click Action Behavior") {
                Picker("When Right-Clicking Files", selection: $settings.finderActionBehavior) {
                    ForEach(FinderActionBehavior.allCases) { behavior in
                        Text(behavior.rawValue).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text(settings.finderActionBehavior == .silentBackground 
                     ? "Files will convert in the background with a completion notification and audio chime without opening the Tossy window."
                     : "Files will be automatically added to the Tossy batch queue and the window will be brought to focus.")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
            }
            
            Section("Finder Quick Actions Installation") {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(finderManager.isInstalled ? "Finder Quick Actions Active" : "Quick Actions Not Installed")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(finderManager.isInstalled ? TossyColor.successGreen : TossyColor.textPrimary)
                        
                        Text(finderManager.statusMessage ?? "Enables 'Convert with Tossy' options directly inside macOS Finder right-click menus.")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textSecondary)
                    }
                    
                    Spacer()
                    
                    if finderManager.isInstalling {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(finderManager.isInstalled ? "Refresh Quick Actions" : "Install Quick Actions") {
                            finderManager.installQuickActions()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
                .padding(.vertical, 4)
                
                if finderManager.isInstalled {
                    Button("Remove Finder Quick Actions") {
                        finderManager.uninstallQuickActions()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(TossyColor.errorRed)
                }
            }
            
            Section("Supported Right-Click Formats") {
                Text("Installed Quick Actions will be available for:")
                    .font(.caption)
                    .foregroundStyle(TossyColor.textSecondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    Group {
                        FormatBadge(name: "PNG", category: "Image")
                        FormatBadge(name: "JPEG", category: "Image")
                        FormatBadge(name: "WebP", category: "Image")
                        FormatBadge(name: "JPEG XL", category: "Image")
                        FormatBadge(name: "MP4", category: "Video")
                        FormatBadge(name: "WebM", category: "Video")
                        FormatBadge(name: "MP3", category: "Audio")
                        FormatBadge(name: "FLAC", category: "Audio")
                        FormatBadge(name: "WAV", category: "Audio")
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
