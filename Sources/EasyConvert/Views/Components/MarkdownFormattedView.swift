import SwiftUI
import AppKit

enum MarkdownBlockType: Identifiable {
    case h1(String)
    case h2(String)
    case h3(String)
    case bullet(String)
    case numbered(Int, String)
    case codeBlock(String)
    case blockquote(String)
    case paragraph(String)
    case divider
    
    var id: String {
        switch self {
        case .h1(let s): return "h1_\(s)"
        case .h2(let s): return "h2_\(s)"
        case .h3(let s): return "h3_\(s)"
        case .bullet(let s): return "b_\(s)"
        case .numbered(let i, let s): return "num_\(i)_\(s)"
        case .codeBlock(let s): return "code_\(s.prefix(20))"
        case .blockquote(let s): return "quote_\(s)"
        case .paragraph(let s): return "p_\(s)"
        case .divider: return "divider_\(UUID().uuidString)"
        }
    }
}

struct MarkdownFormattedView: View {
    let markdown: String
    
    private var blocks: [MarkdownBlockType] {
        parseMarkdown(markdown)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlockType) -> some View {
        switch block {
        case .h1(let text):
            Text(LocalizedStringKey(text))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(TossyColor.textPrimary)
                .padding(.top, 6)
                .padding(.bottom, 2)
            
        case .h2(let text):
            Text(LocalizedStringKey(text))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(TossyColor.textPrimary)
                .padding(.top, 4)
                .padding(.bottom, 1)
            
        case .h3(let text):
            Text(LocalizedStringKey(text))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TossyColor.textSecondary)
                .padding(.top, 2)
            
        case .bullet(let text):
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 4))
                    .foregroundStyle(TossyColor.textTertiary)
                    .padding(.top, 6)
                
                Text(LocalizedStringKey(text))
                    .font(.system(size: 12))
                    .foregroundStyle(TossyColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
            
        case .numbered(let num, let text):
            HStack(alignment: .top, spacing: 6) {
                Text("\(num).")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(TossyColor.textTertiary)
                    .frame(width: 18, alignment: .trailing)
                
                Text(LocalizedStringKey(text))
                    .font(.system(size: 12))
                    .foregroundStyle(TossyColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
        case .codeBlock(let code):
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(TossyColor.textPrimary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TossyColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(TossyColor.borderSubtle, lineWidth: 1)
                )
            
        case .blockquote(let text):
            HStack(spacing: 8) {
                Rectangle()
                    .fill(TossyColor.accentProminentBg.opacity(0.6))
                    .frame(width: 3)
                
                Text(LocalizedStringKey(text))
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundStyle(TossyColor.textSecondary)
            }
            .padding(.vertical, 2)
            
        case .paragraph(let text):
            Text(LocalizedStringKey(text))
                .font(.system(size: 12))
                .foregroundStyle(TossyColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
        case .divider:
            Divider().overlay(TossyColor.borderSubtle)
        }
    }
    
    private func parseMarkdown(_ raw: String) -> [MarkdownBlockType] {
        let lines = raw.components(separatedBy: .newlines)
        var result: [MarkdownBlockType] = []
        var inCodeBlock = false
        var codeBlockBuffer: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Fenced code blocks
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                    result.append(.codeBlock(codeBlockBuffer.joined(separator: "\n")))
                    codeBlockBuffer.removeAll()
                } else {
                    inCodeBlock = true
                }
                continue
            }
            
            if inCodeBlock {
                codeBlockBuffer.append(line)
                continue
            }
            
            if trimmed.isEmpty {
                continue
            }
            
            // Dividers
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(.divider)
                continue
            }
            
            // Headers
            if trimmed.hasPrefix("### ") {
                result.append(.h3(String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") {
                result.append(.h2(String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") {
                result.append(.h1(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                // Bullet point
                result.append(.bullet(String(trimmed.dropFirst(2))))
            } else if let numMatch = parseNumberedList(trimmed) {
                result.append(.numbered(numMatch.number, numMatch.text))
            } else if trimmed.hasPrefix("> ") {
                result.append(.blockquote(String(trimmed.dropFirst(2))))
            } else {
                result.append(.paragraph(trimmed))
            }
        }
        
        if inCodeBlock && !codeBlockBuffer.isEmpty {
            result.append(.codeBlock(codeBlockBuffer.joined(separator: "\n")))
        }
        
        if result.isEmpty {
            result.append(.paragraph("No release details provided."))
        }
        
        return result
    }
    
    private func parseNumberedList(_ line: String) -> (number: Int, text: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let numStr = String(line[..<dotIndex]).trimmingCharacters(in: .whitespaces)
        guard let num = Int(numStr) else { return nil }
        let text = String(line[line.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
        return (num, text)
    }
}
