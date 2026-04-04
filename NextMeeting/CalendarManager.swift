import Combine
import EventKit
import AppKit

// MARK: - Models

struct Meeting: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let meetingURL: URL?
    let notes: String?

    var formattedStartTime: String {
        startDate.formatted(date: .omitted, time: .shortened)
    }

    var formattedEndTime: String {
        endDate.formatted(date: .omitted, time: .shortened)
    }

    var isNow: Bool {
        let now = Date()
        return startDate <= now && now <= endDate
    }

    var meetingService: MeetingService {
        guard let url = meetingURL else { return .unknown }
        let str = url.absoluteString
        if str.contains("zoom.us") { return .zoom }
        if str.contains("meet.google.com") { return .googleMeet }
        if str.contains("teams.microsoft.com") { return .teams }
        if str.contains("webex.com") { return .webex }
        if str.contains("whereby.com") { return .whereby }
        return .unknown
    }
}

enum MeetingService {
    case zoom, googleMeet, teams, webex, whereby, unknown

    var displayName: String {
        switch self {
        case .zoom: "Zoom"
        case .googleMeet: "Meet"
        case .teams: "Teams"
        case .webex: "Webex"
        case .whereby: "Whereby"
        case .unknown: "join.button"
        }
    }
}

// MARK: - CalendarManager

@MainActor
class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()

    @Published var nextMeeting: Meeting?
    @Published var upcomingMeetings: [Meeting] = []
    @Published var tomorrowMeetings: [Meeting] = []
    @Published var isAuthorized = false

    private var timer: Timer?
    private var notificationObserver: NSObjectProtocol?

    init() {
        checkAndFetch()
        setupChangeObserver()
    }

    deinit {
        timer?.invalidate()
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: Authorization

    func checkAndFetch() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            isAuthorized = true
            startRefreshing()
        case .notDetermined, .restricted:
            requestAccess()
        default:
            isAuthorized = false
        }
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            Task {
                do {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    isAuthorized = granted
                    if granted { startRefreshing() }
                } catch {
                    isAuthorized = false
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                Task { @MainActor [weak self] in
                    self?.isAuthorized = granted
                    if granted { self?.startRefreshing() }
                }
            }
        }
    }

    // MARK: Refresh

    private func setupChangeObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchMeetings()
            }
        }
    }

    private func startRefreshing() {
        fetchMeetings()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchMeetings()
            }
        }
    }

    func fetchMeetings() {
        let now = Date()
        let calendar = Calendar.current

        // Today: look back up to 4 hours to catch long ongoing meetings
        let searchStart = calendar.date(byAdding: .hour, value: -4, to: now) ?? now
        guard let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) else { return }

        let todayPredicate = eventStore.predicateForEvents(withStart: searchStart, end: endOfToday, calendars: nil)
        let todayEvents = eventStore.events(matching: todayPredicate)

        let meetings = todayEvents
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .map { makeMeeting(from: $0) }

        upcomingMeetings = meetings
        nextMeeting = meetings.first

        // Tomorrow
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let startOfTomorrow = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow),
              let endOfTomorrow = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: tomorrow) else { return }

        let tomorrowPredicate = eventStore.predicateForEvents(withStart: startOfTomorrow, end: endOfTomorrow, calendars: nil)
        let tomorrowEvents = eventStore.events(matching: tomorrowPredicate)

        tomorrowMeetings = tomorrowEvents
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { makeMeeting(from: $0) }
    }

    // MARK: Meeting Construction

    private func makeMeeting(from event: EKEvent) -> Meeting {
        Meeting(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? String(localized: "event.untitled"),
            startDate: event.startDate,
            endDate: event.endDate,
            meetingURL: extractMeetingURL(from: event),
            notes: event.notes
        )
    }

    // MARK: URL Extraction

    private static let videoPatterns = [
        "zoom.us/j/",
        "zoom.us/my/",
        "meet.google.com/",
        "teams.microsoft.com/l/meetup-join",
        "teams.microsoft.com/meet/",
        "webex.com/meet/",
        "webex.com/join/",
        "whereby.com/",
    ]

    private func extractMeetingURL(from event: EKEvent) -> URL? {
        // 1. Check event.url directly
        if let url = event.url,
           Self.videoPatterns.contains(where: { url.absoluteString.contains($0) }) {
            return url
        }

        // 2. Search in notes and location
        let textToSearch = [event.notes, event.location]
            .compactMap { $0 }
            .joined(separator: "\n")

        guard !textToSearch.isEmpty else { return nil }
        return extractURL(from: textToSearch)
    }

    private func extractURL(from text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        return matches
            .compactMap { $0.url }
            .first { url in
                Self.videoPatterns.contains(where: { url.absoluteString.contains($0) })
            }
    }
}
