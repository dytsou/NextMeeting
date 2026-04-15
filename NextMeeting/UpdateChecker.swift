import AppKit
import Foundation

private enum UpdateDefaultsKeys {
    static let lastUpdateCheckDate = "updates.lastUpdateCheckDate"
    static let availableVersion = "updates.availableVersion"
    static let availableDownloadURL = "updates.availableDownloadURL"
}

private struct GitHubLatestRelease: Decodable {
    let tag_name: String
    let html_url: String
}

@MainActor
final class UpdateChecker: ObservableObject {
    private let defaults = UserDefaults.standard
    private let releaseURL = URL(string: "https://api.github.com/repos/dytsou/NextMeeting/releases/latest")!

    private var dailyTimer: Timer?

    @Published private(set) var availableVersion: String?
    @Published private(set) var availableDownloadURL: URL?

    init(loadFromDefaults: Bool = true) {
        if loadFromDefaults {
            self.availableVersion = defaults.string(forKey: UpdateDefaultsKeys.availableVersion)
            if let raw = defaults.string(forKey: UpdateDefaultsKeys.availableDownloadURL) {
                self.availableDownloadURL = URL(string: raw)
            } else {
                self.availableDownloadURL = nil
            }
        } else {
            self.availableVersion = nil
            self.availableDownloadURL = nil
        }
    }

    func start() {
        Task { [weak self] in
            await self?.checkIfNeeded()
            await self?.scheduleNextDailyCheck()
        }
    }

    func checkIfNeeded() async {
        if let last = defaults.object(forKey: UpdateDefaultsKeys.lastUpdateCheckDate) as? Date,
           Calendar.current.isDateInToday(last) {
            return
        }
        defaults.set(Date(), forKey: UpdateDefaultsKeys.lastUpdateCheckDate)
        await checkNow()
    }

    func scheduleNextDailyCheck() async {
        dailyTimer?.invalidate()
        dailyTimer = nil

        let now = Date()
        guard let next = Self.nextNineAM(after: now) else { return }
        let interval = max(5, next.timeIntervalSince(now))

        dailyTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.checkIfNeeded()
                await self?.scheduleNextDailyCheck()
            }
        }
    }

    private func checkNow() async {
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        guard let currentVersion = SemVer(current) else { return }

        var request = URLRequest(url: releaseURL)
        request.setValue("NextMeeting", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let latest = try JSONDecoder().decode(GitHubLatestRelease.self, from: data)
            let latestTag = latest.tag_name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let latestVersion = SemVer(latestTag) else { return }

            guard latestVersion > currentVersion else { return }

            let downloadURL = URL(string: latest.html_url) ?? URL(string: "https://github.com/dytsou/NextMeeting/releases/latest")!
            setAvailableUpdate(version: latestVersion.stringValue, downloadURL: downloadURL)
        } catch {
            // Ignore transient network/decoding errors; we will retry tomorrow.
        }
    }

    private func setAvailableUpdate(version: String, downloadURL: URL) {
        defaults.set(version, forKey: UpdateDefaultsKeys.availableVersion)
        defaults.set(downloadURL.absoluteString, forKey: UpdateDefaultsKeys.availableDownloadURL)
        availableVersion = version
        availableDownloadURL = downloadURL
    }

    private static func nextNineAM(after date: Date) -> Date? {
        let cal = Calendar.current
        let todayNine = cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)
        if let todayNine, date < todayNine { return todayNine }
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: date) else { return nil }
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
    }
}

private struct SemVer: Comparable {
    let parts: [Int]
    let stringValue: String

    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let noPrefix = trimmed.hasPrefix("v") || trimmed.hasPrefix("V") ? String(trimmed.dropFirst()) : trimmed

        let tokens = noPrefix.split(separator: ".").map { String($0) }
        let ints = tokens.compactMap { Int($0.filter(\.isNumber)) }
        guard !ints.isEmpty else { return nil }

        self.parts = ints
        self.stringValue = noPrefix
    }

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        let maxCount = max(lhs.parts.count, rhs.parts.count)
        for i in 0..<maxCount {
            let a = i < lhs.parts.count ? lhs.parts[i] : 0
            let b = i < rhs.parts.count ? rhs.parts[i] : 0
            if a != b { return a < b }
        }
        return false
    }
}

