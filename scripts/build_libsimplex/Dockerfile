# 使用包含 Nix 環境的官方映像檔
# Using official Nix OS image
FROM nixos/nix:latest

# 準備工作目錄
# Prepare working directory
WORKDIR /build

# 由於安全考量，設定 Nix 可以存取 experimental 功能 (flakes)
# Enable Nix experimental features for flake compatibility if needed
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# 複製外部傳入的一鍵編譯腳本 (如果有)
# 或者直接以指令執行 clone (透過 nix-shell 載入 git 以防套件衝突)
RUN nix-shell -p git --run "git clone -b stable https://github.com/simplex-chat/simplex-chat.git ."

# 針對 Android ARM64 架構的編譯指令 (這將會花費大量時間與網路流量)
# Cross-compile command for Android ARM64 (Requires significant time and bandwidth)
# NOTE: In official simplex-chat repo, they use a specific make script for Android.
# We execute their predefined make script "make libsimplex-android-arm64".
# If they use Nix directly, it's typically `nix-build -A android.aarch64`.
# Using the make wrapper is often safer as it invokes Nix properly.
RUN cd scripts && make -f Makefile.android android-aarch64 || nix-build -A android.aarch64

# CMD 將保持容器運行，方便外部將產出的 .so 檔使用 podman cp 取出
# Keep container running to allow extraction of .so file
CMD ["tail", "-f", "/dev/null"]
