import SwiftUI
import EventKit
import AppKit

public final class CalendarWidget: DynamicIslandWidget, ObservableObject {
    public let id: String = "calendar"
    public let name: String = "Calendar"
    public let priority: Int = 80
    public var isVisible: Bool { true }
    public var preferredCompactWidth: CGFloat { 210 }
    public var preferredExpandedSize: CGSize { CGSize(width: 340, height: 160) }

    @Published public var monthShortName: String = "AUG"
    @Published public var dayOfMonth: String = "6"
    @Published public var upcomingTitle: String = "Product Sync & Review"
    @Published public var upcomingTime: String = "2:00 PM - 3:00 PM"
    @Published public var location: String = "Google Meet / Xcode"

    private var eventStore = EKEventStore()
    private var timer: Timer?

    public init() {
        updateDate()
        fetchCalendarEvents()
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateDate()
            self?.fetchCalendarEvents()
        }
    }

    public func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        }
    }

    private func fetchCalendarEvents() {
        let handler: (Bool, Error?) -> Void = { [weak self] granted, error in
            guard granted else { return }
            let now = Date()
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            let predicate = self?.eventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)

            if let predicate = predicate, let events = self?.eventStore.events(matching: predicate), let first = events.first {
                DispatchQueue.main.async {
                    self?.upcomingTitle = first.title
                    let formatter = DateFormatter()
                    formatter.dateFormat = "h:mm a"
                    let startStr = formatter.string(from: first.startDate)
                    let endStr = formatter.string(from: first.endDate)
                    self?.upcomingTime = "\(startStr) - \(endStr)"
                    if let loc = first.location, !loc.isEmpty {
                        self?.location = loc
                    }
                }
            }
        }

        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents(completion: handler)
        } else {
            eventStore.requestAccess(to: .event, completion: handler)
        }
    }

    private func updateDate() {
        let now = Date()
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        monthShortName = monthFormatter.string(from: now).uppercased()

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        dayOfMonth = dayFormatter.string(from: now)
    }

    public func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 22, height: 22)
                    Text(monthShortName)
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(.white)
                        .offset(y: -4)
                    Text(dayOfMonth)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                        .offset(y: 4)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(upcomingTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(upcomingTime)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 8)
        )
    }

    public func expandedView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .bold))
                    Text("Today's Schedule")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Open Calendar") {
                        self.openCalendarApp()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(upcomingTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text(upcomingTime)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                HStack {
                    Capsule()
                        .fill(Color.red.opacity(0.2))
                        .overlay(
                            Text(location)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.red)
                                .lineLimit(1)
                        )
                        .frame(height: 26)

                    Button("Open App") {
                        self.openCalendarApp()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                }
            }
            .padding(14)
        )
    }

    public func minimalView() -> AnyView {
        AnyView(
            Image(systemName: "calendar")
                .foregroundColor(.red)
                .font(.system(size: 12))
        )
    }
}
