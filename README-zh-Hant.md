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
- 偵測到連結時顯示一鍵加入按鈕；**設定**可為各服務（Zoom、Google Meet、Teams、Webex、Whereby）分別選擇以 **App** 或**瀏覽器**開啟
- **行事曆來源：** 在**設定**的**行事曆來源**分頁可指定要讀取哪些 Apple 行事曆
- 每 60 秒自動更新，行事曆有異動時立即刷新
- 每日檢查更新（GitHub Releases），並在 App 內提供更新連結
- 支援英文與繁體中文（依系統語言自動切換）

## 系統需求

- macOS 13 Ventura 或更新版本
- macOS 行事曆 App 已與 Google 帳號同步
- **用 `./build.sh` 建置：** 只需 Xcode Command Line Tools（約 500 MB），**不必**安裝完整 Xcode
- **要開啟產生的 `.xcodeproj`：** 需完整 Xcode（方式 B）

## 設定步驟

### 1. 同步 Google 行事曆

開啟**行事曆 App** → 偏好設定 → 帳號 → 新增 Google 帳號。NextMeeting 直接讀取系統行事曆，無需 API 金鑰或 OAuth 授權。

### 2. 使用 Homebrew 安裝

透過 [Homebrew tap](https://github.com/dytsou/homebrew-nextmeeting) 以 Cask 安裝圖形介面 App：

```bash
brew tap dytsou/nextmeeting
brew install --cask nextmeeting
```

若未使用 Homebrew 安裝，則需先建置 App。

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

## 首次開啟與安全性

- **選單列 App：** NextMeeting 在**選單列**執行，啟動後可能**不會出現在 Dock**，請在時鐘附近找圖示。
- **從終端機開啟：** `.app` 是套件目錄，不能像一般指令直接輸入路徑執行。請用 **`open`**，例如：

  ```bash
  open /Applications/NextMeeting.app
  ```

  或在 **Finder → 應用程式** 點兩下 **NextMeeting**。若 Homebrew 因權限改裝到使用者目錄，可試 `open ~/Applications/NextMeeting.app`。

- **Gatekeeper（「Apple 無法驗證…」）：** 目前發行版為 ad-hoc 簽章，**未經 Apple 公證（Notarization）**，第一次開啟時系統可能顯示警告。這代表未通過 Apple 的公證流程，**不代表** Apple 偵測到惡意程式。若你信任[此專案來源](https://github.com/dytsou/NextMeeting)，可這樣做：在 Finder 對 App **按住 Control 點按（或右鍵）→ 開啟**，再於對話框選 **開啟**；或到 **系統設定 → 隱私與安全性**，在列出 NextMeeting 時選 **仍要開啟**。不建議為此關閉整台 Mac 的 Gatekeeper。

## 專案結構

```
NextMeeting/
├── build.sh                        # 用 swiftc 編譯（不需要 Xcode）
├── setup.sh                        # 用 xcodegen 產生專案並開啟
├── project.yml                     # xcodegen 設定
└── NextMeeting/
    ├── NextMeetingApp.swift        # App 進入點 + 選單列 label
    ├── CalendarManager.swift       # EventKit + 視訊連結偵測
    ├── CalendarSelectionStore.swift # UserDefaults：要納入的行事曆
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
