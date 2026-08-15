import SwiftUI

/// Core Protocol for all Dynamic Island Widgets
public protocol DynamicIslandWidget: AnyObject {
    var id: String { get }
    var name: String { get }
    /// Priority order (higher priority takes precedence in compact mode)
    var priority: Int { get }
    var isVisible: Bool { get }
    var preferredCompactWidth: CGFloat { get }
    var preferredExpandedSize: CGSize { get }

    func compactView() -> AnyView
    func expandedView() -> AnyView
    func minimalView() -> AnyView

    func onShow()
    func onHide()
    func update()
    func reset()
}

public extension DynamicIslandWidget {
    var name: String { id }
    var isVisible: Bool { true }
    var preferredCompactWidth: CGFloat { 200 }
    var preferredExpandedSize: CGSize { CGSize(width: 360, height: 160) }
    func minimalView() -> AnyView { compactView() }
    func onShow() {}
    func onHide() {}
    func update() {}
    func reset() {}
}
