import SwiftUI
import AppKit

struct WhatsNewModalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: WhatsNewTab = .guide
    @Bindable var changelogService = GitHubChangelogService.shared
    
    enum WhatsNewTab: String, CaseIterable, Identifiable {
        case guide = "Quick Start Guide"
        case changelog = "Release Changelogs"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Hero Header
            VStack(spacing: 8) {
                if let logoURL = Bundle.main.url(forResource: "TossyLogo", withExtension: "png"),
                   let nsImg = NSImage(contentsOf: logoURL) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                Text("Welcome to Tossy 2.0")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(TossyColor.textPrimary)
                
                Text("The only file utility you will ever need on macOS.")
                    .font(.subheadline)
                    .foregroundStyle(TossyColor.textSecondary)
                
                Picker("", selection: $selectedTab) {
                    ForEach(WhatsNewTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
                .padding(.top, 4)
            }
            .padding(.top, 22)
            .padding(.bottom, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(TossyColor.surfaceDeep)
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == .guide {
                        quickStartGuideContent
                    } else {
                        changelogContent
                    }
                }
                .padding(20)
            }
            
            Divider().overlay(TossyColor.borderSubtle)
            
            // Footer
            HStack {
                Text("Tossy v\(AppVersion.string)")
                    .font(.caption.monospaced())
                    .foregroundStyle(TossyColor.textTertiary)
                
                Spacer()
                
                Button("Get Started") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(TossyColor.surfaceDeep)
        }
        .frame(minWidth: 620, minHeight: 560)
        .background(TossyColor.pitchBlack)
        .preferredColorScheme(AppSettings.shared.appTheme == .light ? .light : .dark)
    }
    
    // MARK: - Monochromatic Black & White Quick Start Guide
    
    private var quickStartGuideContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            guideRow(
                icon: "rectangle.stack.fill",
                title: "Universal File Canvas",
                description: "Drag any image, video, audio, PDF, source code, or archive into the window. Tossy automatically routes and queues items for batch processing."
            )
            
            guideRow(
                icon: "doc.richtext.fill",
                title: "PDF & Document Studio",
                description: "Merge multiple PDFs, split custom page ranges (e.g. 1-5, 8), burst single pages into folders, compress DPI for email, and extract on-device Vision OCR text."
            )
            
            guideRow(
                icon: "film.stack.fill",
                title: "Lossless Media Studio",
                description: "Trim videos in milliseconds without re-encoding, extract high-bitrate audio tracks, adjust geometry and playback speed, and apply custom watermark overlays."
            )
            
            guideRow(
                icon: "curlybraces.square.fill",
                title: "Carbon Code Card Studio",
                description: "Drop source code files to instantly generate beautiful syntax-highlighted code cards with macOS window chrome and language-specific VS Code coloring."
            )
            
            guideRow(
                icon: "archivebox.fill",
                title: "Archive Suite & Watch Folders",
                description: "Create AES-256 encrypted archives, split multi-part volumes, and configure background hot folders in Settings for zero-click automatic conversions."
            )
        }
    }
    
    private func guideRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(TossyColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(TossyColor.surfaceHighlight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TossyColor.textPrimary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(TossyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TossyColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
        )
    }
    
    // MARK: - Live GitHub Release Changelogs (with Paginated View More)
    
    private var changelogContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Official GitHub Release History")
                    .font(.caption.bold())
                    .foregroundStyle(TossyColor.textSecondary)
                
                Spacer()
                
                if changelogService.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task {
                            await changelogService.fetchReleases()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(TossyColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh from GitHub")
                }
            }
            
            ForEach(changelogService.visibleReleases) { release in
                changelogCard(release: release)
            }
            
            if changelogService.canLoadMore {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        changelogService.loadMore()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down.circle")
                        Text("View More Releases (showing \(changelogService.visibleReleases.count) of \(changelogService.releases.count))")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TossyColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(TossyColor.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(TossyColor.borderMedium, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
    
    private func changelogCard(release: GitHubReleaseItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Text(release.versionString)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(TossyColor.textPrimary)
                    
                    if release.name != release.tagName && !release.name.isEmpty {
                        Text(release.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TossyColor.textSecondary)
                    }
                }
                
                Spacer()
                
                Text(release.formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(TossyColor.textTertiary)
                
                Button {
                    NSWorkspace.shared.open(release.htmlURL)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(TossyColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Open Release on GitHub")
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(release.highlights, id: \.self) { highlight in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TossyColor.textSecondary)
                        
                        Text(highlight)
                            .font(.system(size: 12))
                            .foregroundStyle(TossyColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TossyColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
        )
    }
}
