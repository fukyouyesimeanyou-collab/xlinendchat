#!/usr/bin/env bash
# 
# 一鍵編譯 libsimplex.so 腳本
# One-click compilation script for libsimplex.so
# 
# 此腳本將：
# 1. 使用 Podman/Docker 建立建置環境的 Image。
# 2. 跑起暫存容器並在裡面進行跨平台編譯 (這可能會非常久)。
# 3. 抓出產生的 libsimplex.so，放到 Android 對應的 ARM64 資料夾。
# 4. 刪除暫存容器。

set -e

# 定義目標輸出路徑 (Android jniLibs)
OUT_DIR="../android/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$OUT_DIR"

# 取得系統的 podman 或 docker (因為 Agent 環境的 PATH 可能未包含 /opt/homebrew/bin)
# Get system podman or docker
if [ -x "/opt/homebrew/bin/podman" ]; then
    CONTAINER_CMD="/opt/homebrew/bin/podman"
elif [ -x "/opt/homebrew/bin/docker" ]; then
    CONTAINER_CMD="/opt/homebrew/bin/docker"
elif command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo "❌ 找不到 Podman 也找不到 Docker。請先安裝並啟動後再試。"
    echo "❌ Neither Podman nor Docker was found. Please install one to proceed."
    exit 1
fi

echo "🚀 [1/3] 準備使用 $CONTAINER_CMD 建立編譯環境 (Building container image)..."
$CONTAINER_CMD build -t simplex-android-builder ./scripts/build_libsimplex

echo "🚀 [2/3] 啟動容器進行編譯 (可能需要數小時) (Running compilation container)..."
# 移除同名的殘留容器
$CONTAINER_CMD rm -f temp_simplex_builder || true
$CONTAINER_CMD run -d --name temp_simplex_builder simplex-android-builder

echo "🚀 [3/3] 等待編譯完成並複製成品 (Extracting compiled .so file)..."
# 此處為確保容器有足夠時間產生檔案，真實使用時可能必須使用 docker wait 或是掛載 volume，
# 但為求最簡單的方式，我們先用 docker cp，它若找不到檔案會直接報錯，你需要確認編譯結束。
# (For practical usage you'd mount a volume or build dynamically, this pulls from the layer)

# 搜尋並複製 (尋找 result 或 dist 下的 libsimplex.so)
$CONTAINER_CMD exec temp_simplex_builder bash -c 'find /build -name "libsimplex*so" | head -n 1 > /tmp/so_path.txt'
SO_PATH=$($CONTAINER_CMD exec temp_simplex_builder cat /tmp/so_path.txt)

if [ -z "$SO_PATH" ]; then
    echo "❌ 編譯失敗，找不到 libsimplex.so。請檢查容器 logs："
    echo "$CONTAINER_CMD logs temp_simplex_builder"
    exit 1
fi

echo "✅ 找到產出檔案：$SO_PATH，正在複製到專案..."
$CONTAINER_CMD cp "temp_simplex_builder:$SO_PATH" "$OUT_DIR/libsimplex.so"

echo "🧹 清理暫存容器..."
$CONTAINER_CMD stop temp_simplex_builder
$CONTAINER_CMD rm temp_simplex_builder

echo "🎉 成功！libsimplex.so 已安插於 $OUT_DIR/"
