#!/usr/bin/env bash

# xlinendchat 遠端編譯遷移腳本 (Migration Script for Framework x86_64)
# 此腳本將在您的 Framework Laptop 上執行，用以快速建立穩定的 x86_64 編譯環境。

set -e

echo "🚀 [1/3] 正在 Framework 筆電上準備 xlinendchat 編譯環境..."

# 檢查系統架構
if [ "$(uname -m)" != "x86_64" ]; then
    echo "❌ 錯誤：這台機器不是 x86_64 系統！確保您在 Framework Laptop 上執行此腳本。"
    exit 1
fi

echo "✅ 系統架構確認為 x86_64。"

# 安裝 Nix，如果尚未安裝
if ! command -v nix &> /dev/null; then
    echo "📦 正在安裝 Nix 套件管理器..."
    sh <(curl -L https://nixos.org/nix/install) --daemon
fi

echo "🚀 [2/3] 取得 xlinendchat 的 SimpleX 編譯腳本..."
git clone https://github.com/simplex-chat/simplex-chat.git simplex-chat-src
cd simplex-chat-src
git checkout stable

echo "🚀 [3/3] 啟用高速快取並啟動編譯引擎..."
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
echo "substituters = https://cache.nixos.org https://cache.iog.io" >> ~/.config/nix/nix.conf
echo "trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvycSizITw=" >> ~/.config/nix/nix.conf

echo "🔥 開始編譯 aarch64-android:lib:simplex-chat (預計耗時：30-60分鐘)"
nix build .#aarch64-android:lib:simplex-chat --accept-flake-config

echo "🎉 編譯成功！請將 result/ 內的 libsimplex.so 丟回 Mac Mini 的專案資料夾中。"
