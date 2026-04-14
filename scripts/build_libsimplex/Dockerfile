# 使用包含 Nix 環境的官方映像檔
# Using official Nix OS image
FROM nixos/nix:latest

# 準備工作目錄
# Prepare working directory
WORKDIR /build

# 由於安全考量，設定 Nix 可以存取 experimental 功能 (flakes) 並加入 IOHK 官方緩存加速
# Enable Nix experimental features and add IOHK cache for faster haskell.nix builds
# Disable sandbox to prevent seccomp BPF errors in Rosetta 2 emulation
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "sandbox = false" >> /etc/nix/nix.conf && \
    echo "substituters = https://cache.nixos.org https://cache.iog.io" >> /etc/nix/nix.conf && \
    echo "trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvycSizITw=" >> /etc/nix/nix.conf && \
    echo "max-jobs = 3" >> /etc/nix/nix.conf && \
    echo "cores = 3" >> /etc/nix/nix.conf

# 安裝基礎建構工具 (git 已內建於映像檔中)
RUN nix-env -iA nixpkgs.gnumake

# 透過 git 取得原始碼 (不再需要 sed 補丁，因為我們使用 Rosetta 2 模擬 x86_64-linux 主機環境)
# Rosetta 2 (Apple Silicon) will present this container as x86_64-linux,
# unlocking the official SimpleX Android cross-compilation targets out-of-the-box.
RUN git clone -b stable https://github.com/simplex-chat/simplex-chat.git .

# 針對 Android ARM64 架構的編譯指令 
RUN nix build .#aarch64-android:lib:simplex-chat --accept-flake-config

# CMD 將保持容器運行，方便外部將產出的 .so 檔使用 podman cp 取出
# Keep container running to allow extraction of .so file
CMD ["tail", "-f", "/dev/null"]
