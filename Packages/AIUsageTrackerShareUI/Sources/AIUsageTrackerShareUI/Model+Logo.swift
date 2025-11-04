import Foundation
import SwiftUI
import AIUsageTrackerModel

public extension AIModelBrands {
    /// Load images from the SPM module resources. On macOS we read PDF/PNG directly by URL to avoid name lookup issues.
    private func moduleImage(_ name: String) -> Image {
        #if canImport(AppKit)
        if let url = Bundle.module.url(forResource: name, withExtension: "pdf"),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        // Fallback placeholder so the UI never renders empty.
        return Image(systemName: "app")
        #else
        if let url = Bundle.module.url(forResource: name, withExtension: "pdf"),
           let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        // Fallback placeholder so the UI never renders empty.
        return Image(systemName: "app")
        #endif
    }

    var logo: Image {
        switch self {
        case .gpt:
            return moduleImage("gpt")
        case .claude:
            return moduleImage("claude")
        case .deepseek:
            return moduleImage("deepseek")
        case .gemini:
            return moduleImage("gemini")
        case .grok:
            return moduleImage("grok").renderingMode(.template)
        case .kimi:
            return moduleImage("kimi")
        case .default:
            return moduleImage("cursor")
        }
    }
}