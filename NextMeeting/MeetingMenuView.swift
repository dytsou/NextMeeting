import SwiftUI
import AppKit

// MARK: - Root Menu View

enum MeetingTab { case today, tomorrow }

struct MeetingMenuView: View {
    @EnvironmentObject var manager: CalendarManager
    @State private var selectedTab: MeetingTab = .today

    private var defaultTab: MeetingTab {
        manager.upcomingMeetings.isEmpty ? .tomorrow : .today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(selectedTab: $selectedTab)
            Divider()
            ContentView(selectedTab: selectedTab)
            Divider()
            FooterView()
        }
        .frame(width: 340)
        .environmentObject(manager)
        .onAppear { selectedTab = defaultTab }
    }
}

// MARK: - Header

private struct HeaderView: View {
    @EnvironmentObject var manager: CalendarManager
    @Binding var selectedTab: MeetingTab

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
                Button {
                    manager.fetchMeetings()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Text("header.refresh"))
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

// MARK: - Join Button

private struct JoinButton: View {
    let url: URL
    let service: MeetingService

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
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

// MARK: - Footer

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
            Text("footer.copyright")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
