import SwiftUI

/// Animation Controller providing Apple-style spring animations for 120Hz smooth rendering
public enum AnimationController {
    /// Default snappy spring curve for state expansion and interactive transitions (instant zero-delay feel)
    public static var defaultSpring: Animation {
        .snappy(duration: 0.18, extraBounce: 0.0)
    }

    /// Interactive spring for hover and drag responses
    public static var interactiveSpring: Animation {
        .interactiveSpring(response: 0.16, dampingFraction: 0.86, blendDuration: 0.05)
    }

    /// Clean spring for notification minimal pops and alerts
    public static var bouncyPop: Animation {
        .bouncy(duration: 0.20, extraBounce: 0.04)
    }

    /// Smooth morphing animation for width/height resizing
    public static var morphingSpring: Animation {
        .spring(response: 0.18, dampingFraction: 0.88)
    }
}
