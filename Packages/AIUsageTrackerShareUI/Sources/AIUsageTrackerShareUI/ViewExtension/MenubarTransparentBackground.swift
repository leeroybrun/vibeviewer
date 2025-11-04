import SwiftUI
import AppKit

public struct MenuBarExtraTransparencyHelperView: NSViewRepresentable {
    public init() {}

    public class WindowConfiguratorView: NSView {
        public override func viewWillDraw() {
            super.viewWillDraw()
            self.configure(window: self.window)
        }
        public override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            self.configure(window: newWindow)
        }

        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.configure(window: self.window)
        }

        private func configure(window: NSWindow?) {
            guard let window else { return }

            // Make the underlying Menu Bar Extra panel/window transparent
            window.styleMask.insert(.fullSizeContentView)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.hasShadow = true

            guard let contentView = window.contentView else { return }
            // Ensure content view is fully transparent
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
            contentView.layer?.isOpaque = false

            // Clear any default backgrounds across the entire ancestor chain
            self.clearBackgroundUpwards(from: contentView)

            // If you want translucent blur instead of fully transparent, uncomment the block below
            // addBlur(in: contentView)
        }

        private func clearBackgroundRecursively(in view: NSView?) {
            guard let view else { return }
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.clear.cgColor
            view.layer?.isOpaque = false

            if let eff = view as? NSVisualEffectView, eff.identifier?.rawValue != "vv_transparent_blur" {
                // Remove the default system blur/material view to guarantee full transparency.
                eff.removeFromSuperview()
                return
            }

            for sub in view.subviews { clearBackgroundRecursively(in: sub) }
        }

        private func clearBackgroundUpwards(from view: NSView) {
            var current: NSView? = view
            while let node = current {
                clearBackgroundRecursively(in: node)
                current = node.superview
            }
        }

        private func addBlur(in contentView: NSView) {
            let identifier = NSUserInterfaceItemIdentifier("vv_transparent_blur")
            if contentView.subviews.contains(where: { $0.identifier == identifier }) { return }

            let blurView = NSVisualEffectView()
            blurView.identifier = identifier
            blurView.blendingMode = .withinWindow
            blurView.state = .active
            blurView.material = .hudWindow
            blurView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(blurView, positioned: .below, relativeTo: nil)

            NSLayoutConstraint.activate([
                blurView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                blurView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                blurView.topAnchor.constraint(equalTo: contentView.topAnchor),
                blurView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
    }

    public func makeNSView(context: Context) -> WindowConfiguratorView {
        WindowConfiguratorView()
    }

    public func updateNSView(_ nsView: WindowConfiguratorView, context: Context) { }
}

public extension View {
    /// Enables a transparent background for a MenuBarExtra window (with optional system blur).
    /// Usage: apply as a background modifier on the menu root view.
    func menuBarExtraTransparentBackground() -> some View {
        self.background(MenuBarExtraTransparencyHelperView())
    }
}


