import SwiftUI

/// Renders a `ShareCardView` to a 1080×1920 / 1080×1080 `UIImage`.
public struct ShareCardRenderer {
    public init() {}

    /// Synchronous render (must run on the main actor because `ImageRenderer`
    /// touches SwiftUI state).
    @MainActor
    public func render(week: RecapData, format: ShareCardFormat) -> UIImage? {
        let renderer = ImageRenderer(
            content: ShareCardView(week: week, format: format)
        )
        renderer.scale = 1
        return renderer.uiImage
    }

    /// Async wrapper that hops to the main actor for rendering.
    public func renderedImage(week: RecapData, format: ShareCardFormat) async -> UIImage? {
        await MainActor.run {
            render(week: week, format: format)
        }
    }
}
