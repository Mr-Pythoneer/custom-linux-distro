#!/usr/bin/env bash
#
# Builds llama.cpp with CUDA support from source.
#
# Unlike the Windows port (01-install-llamacpp.ps1), this does NOT try a
# prebuilt-release download first: upstream llama.cpp does not ship prebuilt
# Linux CUDA binaries (CUDA Linux builds are coupled too tightly to the
# host's exact toolkit/driver version to distribute generically) — only
# Windows gets a prebuilt CUDA asset. Building from source is the correct,
# documented path on Linux, not a fallback.
#
# Usage: ./01-install-llamacpp.sh [install_dir]
#   install_dir defaults to ../bin/llama.cpp relative to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${1:-$SCRIPT_DIR/../bin/llama.cpp}"
SRC_DIR="$SCRIPT_DIR/../bin/llama.cpp-src"

echo -e "\033[36mChecking build dependencies...\033[0m"
if ! command -v nvcc >/dev/null 2>&1; then
    echo -e "\033[33mCUDA toolkit (nvcc) not found on PATH.\033[0m"
    cat <<'EOF'
Install the CUDA Toolkit first. 12.8 is the FIRST toolkit with Blackwell
sm_120 support, so 12.8+ is required for the RTX 50-series. CUDA 13.x (current
in 2026) also works and keeps sm_120 -- cuda-toolkit-12-8 is a known-good floor.

  Ubuntu (NVIDIA's official repo):
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt-get update
    sudo apt-get install -y cuda-toolkit-12-8     # or a current cuda-toolkit-13-x

Then re-run this script. (Not auto-installing this for you — it's a large,
system-level package and you should review what's being added.)
EOF
    exit 1
fi

MISSING_PKGS=()
for pkg in build-essential cmake git libcurl4-openssl-dev; do
    dpkg -s "$pkg" >/dev/null 2>&1 || MISSING_PKGS+=("$pkg")
done
if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo -e "\033[36mInstalling build dependencies: ${MISSING_PKGS[*]}\033[0m"
    sudo apt-get update
    sudo apt-get install -y "${MISSING_PKGS[@]}"
fi

if [ -d "$SRC_DIR" ]; then
    echo -e "\033[36mUpdating existing llama.cpp checkout...\033[0m"
    git -C "$SRC_DIR" fetch --depth 1 origin master
    git -C "$SRC_DIR" reset --hard origin/master
else
    echo -e "\033[36mCloning llama.cpp...\033[0m"
    git clone --depth 1 https://github.com/ggml-org/llama.cpp "$SRC_DIR"
fi

echo -e "\033[36mConfiguring (GGML_CUDA=ON, sm_120 for Blackwell)...\033[0m"
cmake -S "$SRC_DIR" -B "$SRC_DIR/build" \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES=120 \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release

echo -e "\033[36mBuilding (this takes a while)...\033[0m"
cmake --build "$SRC_DIR/build" --config Release -j"$(nproc)"

SERVER_BIN=$(find "$SRC_DIR/build" -type f -name "llama-server" | head -n1)
if [ -z "$SERVER_BIN" ]; then
    echo -e "\033[33mBuild finished but llama-server binary not found under $SRC_DIR/build — check the build log above.\033[0m"
    exit 1
fi

mkdir -p "$INSTALL_DIR/bin"
cp "$SRC_DIR/build/bin/"* "$INSTALL_DIR/bin/" 2>/dev/null || cp "$SERVER_BIN" "$INSTALL_DIR/bin/"

echo -e "\033[32m\nInstalled: $INSTALL_DIR/bin/llama-server\033[0m"
echo "Make sure your NVIDIA driver is recent enough for RTX 50-series / Blackwell (CUDA 12.8+)."
echo "Next: run 02-download-models.sh, then 03-install-opencode.sh."
