import Foundation
import SwiftUI

/// States of the Dynamic Island
public enum IslandState: String, CaseIterable, Codable {
    case hidden
    case minimal
    case compact
    case alertPopup
    case expanded
    case maximized

    /// Preferred corner radius for the pill container in this state
    public var cornerRadius: CGFloat {
        switch self {
        case .hidden: return 12
        case .minimal: return 14
        case .compact: return 20
        case .alertPopup: return 24
        case .expanded: return 32
        case .maximized: return 36
        }
    }

    /// Default dimensions when no widget overrides preferred dimensions
    public var defaultSize: CGSize {
        switch self {
        case .hidden: return CGSize(width: 140, height: 4)
        case .minimal: return CGSize(width: 160, height: 32)
        case .compact: return CGSize(width: 350, height: 36)
        case .alertPopup: return CGSize(width: 350, height: 68)
        case .expanded: return CGSize(width: 350, height: 180)
        case .maximized: return CGSize(width: 780, height: 440)
        }
    }

    /// Background material blur / container opacity
    public var opacity: Double {
        switch self {
        case .hidden: return 0.0
        case .minimal, .compact, .alertPopup, .expanded, .maximized: return 1.0
        }
    }

    /// Shadow blur radius for standard macOS floating UI depth
    public var shadowRadius: CGFloat {
        switch self {
        case .hidden: return 0
        case .minimal: return 4
        case .compact: return 10
        case .alertPopup: return 16
        case .expanded: return 24
        case .maximized: return 36
        }
    }
}
