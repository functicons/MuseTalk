#!/usr/bin/env bash
#
# Install dependencies into an existing MuseTalk venv.
#
# What it does:
#   1. Installs ffmpeg if not already present
#   2. Installs PyTorch with the appropriate CUDA/cpu index
#   3. Installs project dependencies from requirements.txt
#   4. Installs MMLab packages (mmcv, mmdet, mmpose)
#
# Requires an existing venv — use scripts/setup-venv.sh to create one first.
#
# Usage:
#   bash scripts/install-deps.sh                    # defaults: CUDA 11.8 (cpu on macOS)
#   bash scripts/install-deps.sh --cuda 12.1        # use CUDA 12.1 torch index
#   bash scripts/install-deps.sh --skip-mmlab       # skip MMLab packages
#   bash scripts/install-deps.sh --dry-run          # print commands without executing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults
CUDA_VERSION="11.8"
VENV_DIR="${PROJECT_DIR}/.venv"
SKIP_MMLAB=0
DRY_RUN=0

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cuda VERSION    CUDA version for PyTorch: 11.8 | 12.1 | cpu (default: 11.8)"
    echo "  --venv DIR        Virtualenv directory (default: .venv)"
    echo "  --skip-mmlab      Skip MMLab package installation"
    echo "  --dry-run         Print commands without executing"
    echo "  -h, --help        Show this help"
}

run_cmd() {
    echo "+ $*"
    if [ "${DRY_RUN}" -eq 0 ]; then
        "$@"
    fi
}

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --cuda)      CUDA_VERSION="$2"; shift 2 ;;
        --venv)      VENV_DIR="$2"; shift 2 ;;
        --skip-mmlab) SKIP_MMLAB=1; shift ;;
        --dry-run)   DRY_RUN=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Check venv exists
if [ ! -x "${VENV_DIR}/bin/python" ]; then
    echo "Error: venv not found at ${VENV_DIR}. Run 'make venv' first."
    exit 1
fi

# Auto-detect: force cpu on macOS (no CUDA wheels available; MPS is included in cpu wheels)
if [ "$(uname -s)" = "Darwin" ] && [ "${CUDA_VERSION}" != "cpu" ]; then
    echo "Note: macOS detected, overriding CUDA to 'cpu' (MPS support is included automatically)."
    CUDA_VERSION="cpu"
fi

# Resolve torch index URL
case "${CUDA_VERSION}" in
    11.8) TORCH_INDEX="https://download.pytorch.org/whl/cu118" ;;
    12.1) TORCH_INDEX="https://download.pytorch.org/whl/cu121" ;;
    cpu)  TORCH_INDEX="https://download.pytorch.org/whl/cpu" ;;
    *)    echo "Error: unsupported CUDA version '${CUDA_VERSION}'. Use 11.8, 12.1, or cpu."; exit 1 ;;
esac

echo "==> Installing dependencies into ${VENV_DIR}"
echo "    CUDA:         ${CUDA_VERSION}"
echo "    Skip MMLab:   ${SKIP_MMLAB}"
echo ""

# Install ffmpeg if not found
if ! command -v ffmpeg &>/dev/null; then
    echo "==> Installing ffmpeg..."
    if [ "$(uname -s)" = "Darwin" ]; then
        if command -v brew &>/dev/null; then
            run_cmd brew install ffmpeg
        else
            echo "Error: ffmpeg not found and Homebrew is not installed."
            echo "Install Homebrew (https://brew.sh) then re-run, or install ffmpeg manually."
            exit 1
        fi
    elif command -v apt-get &>/dev/null; then
        run_cmd sudo apt-get update -qq
        run_cmd sudo apt-get install -y ffmpeg
    elif command -v yum &>/dev/null; then
        run_cmd sudo yum install -y ffmpeg
    else
        echo "Error: ffmpeg not found and no supported package manager detected."
        echo "Please install ffmpeg manually: https://ffmpeg.org/download.html"
        exit 1
    fi
else
    echo "==> ffmpeg already installed: $(ffmpeg -version 2>&1 | head -1)"
fi
echo ""

# Activate venv
# shellcheck disable=SC1091
if [ "${DRY_RUN}" -eq 0 ]; then
    source "${VENV_DIR}/bin/activate"
else
    echo "+ source ${VENV_DIR}/bin/activate"
fi

# Upgrade pip
echo "==> Upgrading pip..."
# Pin setuptools<72 to keep pkg_resources (needed by mmcv build)
run_cmd pip install --upgrade pip "setuptools<72"

# Install PyTorch
echo ""
echo "==> Installing PyTorch 2.0.1 (CUDA ${CUDA_VERSION})..."
run_cmd pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url "${TORCH_INDEX}"

# Install project dependencies
echo ""
echo "==> Installing project dependencies..."
run_cmd pip install -r "${PROJECT_DIR}/requirements.txt"

# Install MMLab packages
if [ "${SKIP_MMLAB}" -eq 0 ]; then
    echo ""
    echo "==> Installing MMLab packages..."
    # Constrain setuptools in pip's build isolation to keep pkg_resources
    CONSTRAINTS_FILE="$(mktemp)"
    echo "setuptools<72" > "${CONSTRAINTS_FILE}"
    export PIP_CONSTRAINT="${CONSTRAINTS_FILE}"

    run_cmd pip install --no-cache-dir -U openmim
    run_cmd mim install mmengine

    # mmcv: on macOS, mim install doesn't compile C extensions properly.
    # Use pip directly with MMCV_WITH_OPS=1 and FORCE_CUDA=0 to ensure ops are built.
    if [ "$(uname -s)" = "Darwin" ]; then
        run_cmd env MMCV_WITH_OPS=1 FORCE_CUDA=0 \
            pip install "mmcv==2.0.1" --no-build-isolation --no-cache-dir
    else
        run_cmd mim install "mmcv==2.0.1"
    fi
    run_cmd mim install "mmdet==3.1.0"
    # Pre-install mmpose deps that fail in build isolation:
    # - chumpy: broken setup.py tries to import pip
    # - xtcocotools: needs numpy and cython at build time
    run_cmd pip install --no-build-isolation chumpy
    run_cmd pip install cython
    run_cmd pip install --no-build-isolation xtcocotools
    run_cmd mim install "mmpose==1.1.0"

    rm -f "${CONSTRAINTS_FILE}"
    unset PIP_CONSTRAINT
else
    echo ""
    echo "==> Skipping MMLab packages (--skip-mmlab)"
fi

echo ""
echo "==> Done!"
