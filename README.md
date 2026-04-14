# 👻 Project Ghost: XLinendChat

[![Git Integrity](https://img.shields.io/badge/Privacy-Military--Grade-red.svg)](https://github.com/fukyouyesimeanyou-collab/xlinendchat)
[![Network](https://img.shields.io/badge/Network-P2P--Waku-blue.svg)](https://waku.org/)
[![Encryption](https://img.shields.io/badge/Encryption-Double--Ratchet-green.svg)](https://signal.org/docs/specifications/doubleratchet/)

**XLinendChat (Project Ghost)** 是一款追求極致隱私、完全去中心化的 P2P 通訊應用程式。我們的願景是 **「Zero-Junk, Zero-Store, Zero-Knowledge」** —— 所有的訊息與檔案皆不在中繼伺服器停留，所有的數據生命週期皆由用戶完全掌控。

---

## 🌟 核心願景 (Vision)

*   **Zero-Store (零存儲)**：不依賴任何中心化伺服器。訊息僅存在於 P2P Gossip 網路與用戶本地。
*   **Zero-Knowledge (零知識)**：所有的通訊內容、檔名與元數據皆經過端到端加密（E2EE），任何中間節點皆無法窺探。
*   **Pure P2P (純對等)**：直接的在線握手，確保數據傳送的即時性與匿名性。

---

## 🛠️ 技術架構 (Technical Stack)

*   **Frontend**: Flutter (Dart) - 具備多 UI 皮膚架構 (LINE / WhatsApp / Telegram Skins)。
*   **P2P Layer**: [Waku v2](https://waku.org/) - 透過 FFI 整合 Rust/Go 原生庫，實作去中心化訊息傳播。
*   **Encryption**:
    *   **Double Ratchet (雙棘輪)**：提供完美前向安全性 (Perfect Forward Secrecy)。
    *   **X25519 PAKE (密碼認證金鑰交換)**：用於無第三方參與的安全身分發現。
    *   **AES-256-GCM**：硬體層級的資料庫加密保護。
*   **Storage**: [Hive](https://pub.dev/packages/hive) - 整合 iOS Keychain / Android Keystore 提供硬體加密保護。

---

## 🔥 關鍵功能 (Key Features)

### 1. 匿名 P2P 通訊 (Phase 5-7)
*   **PAKE 邀請機制**：透過 `xline://` 協定進行匿名握手，無需註冊帳號或提供門號。
*   **自定義 WebP 貼圖**：實作 P2P 貼圖分片傳輸，支持自動壓縮與去 EXIF 處理。

### 2. 匿名檔案傳輸 (Phase 8)
*   **元數據洗滌 (Sanitizer)**：自動清除圖片/影片的 GPS 與設備資訊。
*   **分片傳輸 (Chunking)**：支持大檔案切割並透過 ACK 機制確保傳輸穩定性。
*   **無痕檔名**：全面使用隨機檔名 (Contextless Filenames)，斷絕檔案與原始上下文的聯繫。

### 3. 生命周期管理 (Phase 9)
*   **閱後即焚 (BAR)**：預設 24 小時讀後自動物理銷毀（Shredding）。
*   **導出即焚**：檔案一旦從 App 匯出至系統相簿，立即抹除內部暫存。
*   **磁碟配額管理**：用戶可自由拉桿分配 App 佔用的暫存空間比例。
*   **在線握手**：發送前自動執行 Ping/Pong 檢測，杜絕數據 Orphaned 在網路中。

### 4. 皮膚系統 (Skins)
*   **Modular UI**：一鍵切換不同社交軟體的視覺風格，同時保持底層高強度加密不變。

---

## 🔒 安全性特徵 (Security)

*   **截圖偵測**：當對方執行截圖時，系統會立即發送警告並提供「一鍵銷毀對話」的決策選項。
*   **物理粉碎 (Shredding)**：刪除數據時不僅是邏輯刪除，還會執行數據覆寫，防止 SSD 數據恢復。
*   **硬體金鑰守護**：資料庫加密金鑰受作業系統 Secure Enclave 保護。

---

## 🚀 開發階段路徑圖 (Roadmap)

- [x] **Phase 1-4**: 基礎 UI、Skins 系統與 Waku FFI 初始化。
- [x] **Phase 5**: PAKE 匿名身分發現與邀請機制。
- [x] **Phase 6**: Hive 硬體加密資料庫與持久化。
- [x] **Phase 7**: 自定義貼圖全鏈路 (選取、壓縮、P2P 傳送)。
- [x] **Phase 8**: 匿名分片檔案傳輸。
- [x] **Phase 9**: 24h 生命周期管理與磁碟配額管理。
- [x] **Phase 10**: 專案彙整與多端存檔。

---

## 👨‍💻 貢獻與開發

```bash
# 安裝依賴
flutter pub get

# 執行 Build Runner (用於生成 Hive Adapters)
dart run build_runner build --delete-conflicting-outputs

# 啟動應用
flutter run
```

---

🛡️ **Project Ghost: 您的隱私是我們的最高法律。**
