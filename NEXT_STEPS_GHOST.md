# 🛰️ Project Ghost: Waku-Flutter Pure P2P Core 專案接力文件

## 🎯 當前進度摘要 (Context Summary)
1. **策略調整**：由於 Mac Mini M4 編譯 SimpleX (Haskell) 遇到 NDK 架構相容性瓶頸，專案已決定開啟「雙軌制」。
2. **新增標的**：開啟 **Project Ghost**，目標是用 **Go-Waku** 打造 Flutter 原生 P2P 核心。
3. **環境狀態**：已完成 SimpleX 的 USB 打包 (準備去 Framework 筆電)；目前留在 Mac Mini 準備開始 Waku 編譯試驗。

---

## 🛠️ 下一階段任務：Phase 1 - 原生橋接 (Foundation)
*   **目標**：在 Mac Mini M4 上成功編譯 `libwaku.so`。
*   **關鍵操作**：
    1. 安裝 Go 環境。
    2. 下載 `go-waku`。
    3. 編譯 C-Shared 庫。
*   **建議模型**：本階段使用 **Gemini 1.5 Flash** 即可。

---

## 💎 密碼學預警點 (Model Switch Warning)
當進入 **Phase 2 (Double Ratchet)** 與 **Phase 3 (ZKP)** 時，**必須提醒使用者切換至 Gemini 3.1 Pro**。這兩部分涉及：
- X3DH 密鑰鏈交換邏輯。
- RLN (Rate Limiting Nullifiers) 的零知識證明電路。

---

## 📝 給下一個對話的 Antigravity
本專案目前位於 `/Volumes/macmini2tbssd01/podmanAll/mvplab-projects/xlinendchat/`。
請優先讀取此檔案以掌握「Waku 代替 Haskell」的戰略轉向，並直接從「Go-Waku 環境搭建」開始引導。
