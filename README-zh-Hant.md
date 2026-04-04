<p align="center">
  <img src="./NextMeeting/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="NextMeeting" width="128" height="128" />
</p>

# NextMeeting

在 Mac 選單列顯示下一場會議的 macOS 小工具。

![Screenshot](./NextMeeting/screenshot.jpg)

## 功能

- 在選單列顯示下一場會議的開始時間
- 會議進行中時顯示「進行中」
- 點擊展開今日剩餘所有會議清單
- 自動偵測視訊會議連結（Zoom、Google Meet、Teams、Webex、Whereby）
- 偵測到連結時顯示一鍵加入按鈕；**設定**可為各服務（Zoom、Google Meet、Teams、Webex、Whereby）分別選擇以 **App** 或**瀏覽器**開啟；無法辨識的「其他」連結一律以瀏覽器開啟（無設定項）
- 每 60 秒自動更新，行事曆有異動時立即刷新
- 支援英文與繁體中文（依系統語言自動切換）

## 系統需求

- macOS 13 Ventura 或更新版本
- macOS 行事曆 App 已與 Google 帳號同步
- **用 `./build.sh` 建置：** 只需 Xcode Command Line Tools（約 500 MB），**不必**安裝完整 Xcode
- **要開啟產生的 `.xcodeproj`：** 需完整 Xcode（方式 B）

## 設定步驟

### 1. 同步 Google 行事曆

開啟**行事曆 App** → 偏好設定 → 帳號 → 新增 Google 帳號。NextMeeting 直接讀取系統行事曆，無需 API 金鑰或 OAuth 授權。

### 2. 建置與安裝

**方式 A — 僅 Command Line Tools**（不需完整 Xcode App）：

1. 若尚未安裝，執行安裝。若 `xcode-select --install` 顯示**已安裝**，可略過；之後可透過**系統設定 → 一般 → 軟體更新**安裝更新。

   ```bash
   xcode-select --install
   ```

2. 將作用中的開發者目錄指向獨立的 Command Line Tools（僅在 `xcode-select -p` 顯示 `Xcode.app` 路徑時需要執行一次）：

   ```bash
   sudo xcode-select -s /Library/Developer/CommandLineTools
   ```

   僅使用 CLI 建置時，`xcode-select -p` 應顯示 `/Library/Developer/CommandLineTools`。

3. 建置：

   ```bash
   git clone https://github.com/dytsou/NextMeeting.git
   cd NextMeeting
   ./build.sh
   ```

腳本會用 `swiftc` 編譯、產生 `NextMeeting.app`，並詢問是否安裝到 `/Applications`。

**方式 B — 使用 Xcode**（透過 xcodegen 產生專案）：

```bash
git clone https://github.com/dytsou/NextMeeting.git
cd NextMeeting
./setup.sh
```

`setup.sh` 會在需要時透過 Homebrew 安裝 xcodegen，產生 `NextMeeting.xcodeproj` 後開啟 Xcode。

1. 前往 **Signing & Capabilities**，選擇你的 Apple ID Team
2. 按下 **Command+R** 建置並執行
3. 出現行事曆存取請求時，點擊允許

## 專案結構

```
NextMeeting/
├── build.sh                        # 用 swiftc 編譯（不需要 Xcode）
├── setup.sh                        # 用 xcodegen 產生專案並開啟
├── project.yml                     # xcodegen 設定
└── NextMeeting/
    ├── NextMeetingApp.swift        # App 進入點 + 選單列 label
    ├── CalendarManager.swift       # EventKit + 視訊連結偵測
    ├── JoinPreferenceStore.swift   # UserDefaults：各服務以 App 或瀏覽器開啟
    ├── MeetingMenuView.swift       # 彈出視窗 UI
    ├── Info.plist                  # 行事曆權限說明
    ├── NextMeeting.entitlements    # 沙盒 + 行事曆存取
    ├── en.lproj/
    │   └── Localizable.strings
    └── zh-Hant.lproj/
        ├── Localizable.strings
        └── InfoPlist.strings
```

## 支援的視訊會議服務

| 服務            | 網域                  |
| --------------- | --------------------- |
| Zoom            | `zoom.us`             |
| Google Meet     | `meet.google.com`     |
| Microsoft Teams | `teams.microsoft.com` |
| Webex           | `webex.com`           |
| Whereby         | `whereby.com`         |

連結偵測範圍包含：活動 URL、備註、地點欄位。

**加入會議的行為：** 在選單面板中開啟**設定**，可為列出的提供者選擇 **App**（預設）或**瀏覽器**。**瀏覽器**一律先關閉面板，再以預設瀏覽器開啟可於網頁使用的 HTTPS 連結。**App** 則先請 macOS 開啟原始連結；若無對應程式，則關閉面板並改以 HTTPS 對應（`zoommtg://`、`gmeet://`、Teams／Meet 等）。未對應到這些提供者的連結一律走**瀏覽器**流程。偏好設定儲存在 UserDefaults。

## 參與貢獻

請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)（英文）了解如何提案變更、在本機建置與發起 Pull Request。

## 新增語言

1. 建立 `NextMeeting/<語系代碼>.lproj/Localizable.strings`
2. 複製 `en.lproj/Localizable.strings` 的所有 key，翻譯對應的值
3. 在 `Info.plist` 的 `CFBundleLocalizations` 陣列加入新語系代碼
4. 在 `project.yml` 的 `resources` 加入新的 lproj 路徑，再執行 `./setup.sh` 重新產生專案
