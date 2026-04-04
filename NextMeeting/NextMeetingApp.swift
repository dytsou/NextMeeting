import SwiftUI
import AppKit
import Combine

@main
struct NextMeetingApp: App {
    private let statusBarController = StatusBarController(manager: CalendarManager())

    // MenuBarExtra is no longer used — popover is managed by StatusBarController
    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - AppKit Status Bar Controller

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var cancellable: AnyCancellable?
    private var sizeObservation: NSKeyValueObservation?

    init(manager: CalendarManager) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        let hostingController = NSHostingController(
            rootView: MeetingMenuView().environmentObject(manager)
        )
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true

        super.init()

        sizeObservation = hostingController.observe(\.preferredContentSize, options: [.new]) { [weak self] hc, _ in
            let size = hc.preferredContentSize
            DispatchQueue.main.async { [weak self] in
                guard let self, self.popover.isShown else { return }
                self.popover.contentSize = size
            }
        }

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        update(meeting: nil)

        cancellable = manager.$nextMeeting
            .receive(on: RunLoop.main)
            .sink { [weak self] meeting in self?.update(meeting: meeting) }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func update(meeting: Meeting?) {
        guard let button = statusItem.button else { return }

        let symbolName = meeting?.isNow == true ? "calendar.badge.clock" : "calendar"
        let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        icon?.isTemplate = true

        button.image = icon
        button.imagePosition = .imageLeft
        button.imageScaling = .scaleProportionallyDown

        guard let meeting else {
            let str = NSAttributedString(
                string: NSLocalizedString("label.no_meeting", comment: ""),
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
            button.attributedTitle = str
            return
        }

        let title = String(meeting.title.prefix(10))
        let time =
            meeting.formattedEndTime.isEmpty
            ? "\(meeting.formattedStartTime)"
            : "\(meeting.formattedStartTime) – \(meeting.formattedEndTime)"

        let str = NSMutableAttributedString(
            string: time + "\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 6, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )
        str.append(NSAttributedString(
            string: title,
            attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)]
        ))
        button.attributedTitle = str
    }
}
