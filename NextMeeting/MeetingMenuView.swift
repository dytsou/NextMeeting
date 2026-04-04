import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted before opening a meeting in the browser so the menu popover can dismiss (browser preference or native fallback).
    static let nextMeetingDismissPopover = Notification.Name("NextMeetingDismissPopover")
}

// MARK: - Root Menu View

enum MeetingTab { case today, tomorrow }

struct MeetingMenuView: View {
    @EnvironmentObject var manager: CalendarManager
    @EnvironmentObject var joinPreferences: JoinPreferenceStore
    @State private var selectedTab: MeetingTab = .today
    @State private var showJoinSettings = false

    private var defaultTab: MeetingTab {
        manager.upcomingMeetings.isEmpty ? .tomorrow : .today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(selectedTab: $selectedTab, showJoinSettings: $showJoinSettings)
            Divider()
            ContentView(selectedTab: selectedTab)
            Divider()
            FooterView()
        }
        .frame(width: 340)
        .environmentObject(manager)
        .environmentObject(joinPreferences)
        .onAppear { selectedTab = defaultTab }
        .sheet(isPresented: $showJoinSettings) {
            JoinSettingsView()
                .environmentObject(joinPreferences)
        }
    }
}

// MARK: - Header

private struct HeaderView: View {
    @EnvironmentObject var manager: CalendarManager
    @Binding var selectedTab: MeetingTab
    @Binding var showJoinSettings: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("header.title")
                        .font(.headline)
                    Text(Date(), format: .dateTime.year().month(.wide).day().weekday(.wide))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        manager.fetchMeetings()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(Text("header.refresh"))

                    Button {
                        showJoinSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(Text("footer.settings"))
                }
            }

            Picker("", selection: $selectedTab) {
                Text("tab.today").tag(MeetingTab.today)
                Text("tab.tomorrow").tag(MeetingTab.tomorrow)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

// MARK: - Content

private struct ContentView: View {
    @EnvironmentObject var manager: CalendarManager
    let selectedTab: MeetingTab

    var body: some View {
        if !manager.isAuthorized {
            UnauthorizedView()
        } else {
            let meetings = selectedTab == .today ? manager.upcomingMeetings : manager.tomorrowMeetings
            if meetings.isEmpty {
                NoMeetingsView(selectedTab: selectedTab)
            } else {
                MeetingListView(meetings: meetings)
            }
        }
    }
}

private struct UnauthorizedView: View {
    @EnvironmentObject var manager: CalendarManager

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("auth.required")
                .font(.subheadline)
            Button("auth.grant") {
                manager.requestAccess()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

private struct NoMeetingsView: View {
    let selectedTab: MeetingTab

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Group {
                switch selectedTab {
                case .today:
                    Text("empty.no_meetings")
                case .tomorrow:
                    Text("empty.no_meetings_tomorrow")
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .id(selectedTab)
    }
}

private struct MeetingListView: View {
    let meetings: [Meeting]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(meetings.enumerated()), id: \.element.id) { index, meeting in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 14)
                    }
                    MeetingRow(meeting: meeting)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 360)
    }
}

// MARK: - Meeting Row

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Time column
            VStack(alignment: .trailing, spacing: 1) {
                Text(meeting.formattedStartTime)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text(meeting.formattedEndTime)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50, alignment: .trailing)

            // Status bar
            RoundedRectangle(cornerRadius: 2)
                .fill(meeting.isNow ? Color.green : Color.accentColor.opacity(0.4))
                .frame(width: 3, height: 36)

            // Title
            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(.system(size: 13))
                    .lineLimit(2)
            }

            Spacer()

            // Join button
            if let url = meeting.meetingURL {
                JoinButton(url: url, service: meeting.meetingService)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(meeting.isNow ? Color.green.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Meeting join URL

private func openMeetingJoinURL(url: URL, mode: JoinOpenMode) {
    switch mode {
    case .browser:
        let target = url.browserFallbackJoinURL() ?? url
        NotificationCenter.default.post(name: .nextMeetingDismissPopover, object: nil)
        _ = NSWorkspace.shared.open(target)
    case .native:
        if NSWorkspace.shared.open(url) { return }
        NotificationCenter.default.post(name: .nextMeetingDismissPopover, object: nil)
        guard let fallback = url.browserFallbackJoinURL() else { return }
        _ = NSWorkspace.shared.open(fallback)
    }
}

private extension URL {
    /// HTTPS (or same http/s) URL to open in the default browser when the native handler is missing.
    func browserFallbackJoinURL() -> URL? {
        let scheme = (self.scheme ?? "").lowercased()
        if scheme == "http" || scheme == "https" {
            return self
        }
        if scheme == "zoommtg" {
            return zoomWebURLFromZoommtg()
        }
        if scheme == "gmeet" {
            return googleMeetWebURLFromGmeet()
        }
        let lower = absoluteString.lowercased()
        if lower.contains("teams.microsoft.com") || lower.contains("meet.google.com") {
            var comps = URLComponents(url: self, resolvingAgainstBaseURL: false)
            comps?.scheme = "https"
            return comps?.url
        }
        return nil
    }

    private func zoomWebURLFromZoommtg() -> URL? {
        guard let comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        let items = comps.queryItems ?? []
        let confnoFromQuery = items.first { $0.name.lowercased() == "confno" }?.value
        let confnoFromPath: String? = {
            let p = comps.path
            guard let r = p.range(of: "/j/") else { return nil }
            let after = p[r.upperBound...]
            let segment = after.split(separator: "/").first.map(String.init)
            return segment.flatMap { $0.isEmpty ? nil : $0 }
        }()
        guard let confno = confnoFromQuery ?? confnoFromPath, !confno.isEmpty else { return nil }
        let pwd = items.first { $0.name.lowercased() == "pwd" }?.value
        var web = URLComponents()
        web.scheme = "https"
        web.host = "zoom.us"
        web.path = "/j/\(confno)"
        if let pwd, !pwd.isEmpty {
            web.queryItems = [URLQueryItem(name: "pwd", value: pwd)]
        }
        return web.url
    }

    /// `gmeet://meeting-code` (Google Meet iOS / app deep link) → `https://meet.google.com/meeting-code`
    private func googleMeetWebURLFromGmeet() -> URL? {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        if comps.host?.lowercased() == "meet.google.com" {
            comps.scheme = "https"
            return comps.url
        }
        let trimmedPath = comps.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let code: String? = {
            if let host = comps.host, !host.isEmpty { return host }
            if !trimmedPath.isEmpty { return trimmedPath }
            return nil
        }()
        guard let code, !code.isEmpty else { return nil }
        var web = URLComponents()
        web.scheme = "https"
        web.host = "meet.google.com"
        web.path = "/\(code)"
        return web.url
    }
}

// MARK: - Join Button

private struct JoinButton: View {
    @EnvironmentObject private var joinPreferences: JoinPreferenceStore
    let url: URL
    let service: MeetingService

    var body: some View {
        Button {
            openMeetingJoinURL(url: url, mode: joinPreferences.mode(for: service))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "video.fill")
                    .font(.system(size: 9))
                Text(LocalizedStringKey(service.displayName))
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(String(format: NSLocalizedString("row.join_help", comment: ""), service.displayName))
    }
}

// MARK: - Join settings sheet

private struct JoinSettingsView: View {
    @EnvironmentObject private var joinPreferences: JoinPreferenceStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("settings.title")
                    .font(.headline)
                Spacer()
                Button("settings.done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Form {
                Section {
                    ForEach(MeetingService.joinPreferenceServices, id: \.self) { service in
                        HStack(alignment: .center) {
                            Text(LocalizedStringKey(service.joinSettingsLabelKey))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Picker("", selection: Binding(
                                get: { joinPreferences.mode(for: service) },
                                set: { joinPreferences.setMode($0, for: service) }
                            )) {
                                Text("settings.join.native").tag(JoinOpenMode.native)
                                Text("settings.join.browser").tag(JoinOpenMode.browser)
                            }
                            .labelsHidden()
                            .frame(width: 196)
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("settings.join.section")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 360, height: 340)
        .padding(.bottom, 8)
    }
}

// MARK: - Footer

private enum FooterLinks {
    static let license = URL(string: "https://github.com/dytsou/NextMeeting/blob/main/LICENSE")!
}

private struct FooterView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("footer.open_calendar") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Spacer()

                Button("footer.quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            Link(destination: FooterLinks.license) {
                Text("footer.copyright")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
