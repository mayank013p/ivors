import AppKit
import SwiftUI

public final class IslandLayoutEngine: ObservableObject {
    public static let shared = IslandLayoutEngine()

    @Published public private(set) var hasNotch: Bool = false
    @Published public private(set) var notchWidth: CGFloat = 0
    @Published public private(set) var notchHeight: CGFloat = 0

    // Standardized Consistent Card Dimensions Across ALL Widgets
    public static let compactContentWidth: CGFloat = 380.0
    public static let expandedWidth: CGFloat = 380.0
    public static let expandedContentHeight: CGFloat = 195.0

    private init() {
        updateNotchGeometry()
    }

    public func updateNotchGeometry() {
        guard let screen = NSScreen.main else {
            hasNotch = true
            notchWidth = 200
            notchHeight = 32
            return
        }

        let showNotch = SettingsManager.shared.showNotchIntegration
        let topInset = screen.safeAreaInsets.top

        if showNotch {
            hasNotch = true
            notchHeight = topInset > 0 ? topInset : 32.0

            if let leftArea = screen.auxiliaryTopLeftArea, let rightArea = screen.auxiliaryTopRightArea {
                let calculatedNotchWidth = screen.frame.width - (leftArea.width + rightArea.width)
                notchWidth = max(calculatedNotchWidth, 180)
            } else {
                notchWidth = 200 // Standard Apple Silicon MacBook notch width
            }
        } else {
            hasNotch = false
            notchWidth = 0
            notchHeight = 0
        }
    }

    public var compactPanelHeight: CGFloat {
        hasNotch ? notchHeight : 36.0
    }

    public var alertPanelHeight: CGFloat {
        hasNotch ? (notchHeight + 48.0) : 74.0
    }

    public var expandedPanelHeight: CGFloat {
        hasNotch ? (notchHeight + IslandLayoutEngine.expandedContentHeight) : IslandLayoutEngine.expandedContentHeight
    }

    public var maximizedPanelHeight: CGFloat {
        hasNotch ? (notchHeight + 455.0) : 455.0
    }

    /// Calculates exact panel frame matching the 4 positions
    public func calculatePanelFrame(for state: IslandState, activeWidget: DynamicIslandWidget?) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 100, y: 100, width: 380, height: 38)
        }

        let screenFrame = screen.frame
        let totalWidth: CGFloat
        let totalHeight: CGFloat

        switch state {
        case .hidden, .minimal:
            // Position 1: EXACTLY in size of Mac notch (looks closed)
            totalWidth = hasNotch ? notchWidth : 180.0
            totalHeight = hasNotch ? notchHeight : 32.0
        case .compact:
            // Position 2: Bigger menu bar wing bar
            totalWidth = IslandLayoutEngine.expandedWidth
            totalHeight = compactPanelHeight
        case .alertPopup:
            // Position 3: Notification Dropdown coming down below the notch a little bit
            totalWidth = IslandLayoutEngine.expandedWidth
            totalHeight = alertPanelHeight
        case .expanded:
            // Position 4: Full expanded card
            totalWidth = IslandLayoutEngine.expandedWidth
            totalHeight = expandedPanelHeight
        case .maximized:
            // Position 4: Maximized theater dashboard
            totalWidth = 780.0
            totalHeight = maximizedPanelHeight
        }

        let x = screenFrame.midX - (totalWidth / 2.0)
        let topY = screenFrame.maxY
        let y = topY - totalHeight

        return NSRect(x: x, y: y, width: totalWidth, height: totalHeight)
    }
}
