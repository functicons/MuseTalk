#!/usr/bin/env bash
#
# Setup a Python virtualenv for MuseTalk.
#
# What it does:
#   1. Creates a virtualenv in .venv/ using the specified Python (default: python3.10)
#   2. Delegates to install-deps.sh for all dependency installation
#
# Usage:
#   bash scripts/setup-venv.sh                    # defaults: python3.10, CUDA 11.8
#   bash scripts/setup-venv.sh --python python3   # use a different python
#   bash scripts/setup-venv.sh --cuda 12.1        # use CUDA 12.1 torch index
#   bash scripts/setup-venv.sh --skip-mmlab       # skip MMLab packages
#   bash scripts/setup-venv.sh --dry-run          # print commands without executing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults
PYTHON_BIN="python3.10"
VENV_DIR="${PROJECT_DIR}/.venv"
DRY_RUN=0

# Collect args to forward to install-deps.sh
FORWARD_ARGS=()

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --python BIN      Python binary to use (default: python3.10)"
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
        --python)    PYTHON_BIN="$2"; shift 2 ;;
        --venv)      VENV_DIR="$2"; FORWARD_ARGS+=("--venv" "$2"); shift 2 ;;
        --dry-run)   DRY_RUN=1; FORWARD_ARGS+=("--dry-run"); shift ;;
        --cuda)      FORWARD_ARGS+=("--cuda" "$2"); shift 2 ;;
        --skip-mmlab) FORWARD_ARGS+=("--skip-mmlab"); shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

echo "==> MuseTalk venv setup"
echo "    Python:       ${PYTHON_BIN}"
echo "    Venv dir:     ${VENV_DIR}"
echo ""

# Check Python exists
if ! command -v "${PYTHON_BIN}" &>/dev/null; then
    echo "Error: ${PYTHON_BIN} not found. Install Python 3.10+ or use --python to specify."
    exit 1
fi

# Handle existing venv
if [ -d "${VENV_DIR}" ]; then
    echo "Existing venv found at ${VENV_DIR}."
    printf "Remove and recreate? [y/N] "
    read -r answer
    if [ "${answer}" = "y" ] || [ "${answer}" = "Y" ]; then
        run_cmd rm -rf "${VENV_DIR}"
        echo "==> Creating virtualenv..."
        run_cmd "${PYTHON_BIN}" -m venv "${VENV_DIR}"
    else
        echo "==> Keeping existing venv, installing dependencies only..."
    fi
else
    echo "==> Creating virtualenv..."
    run_cmd "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi

# Install dependencies
bash "${SCRIPT_DIR}/install-deps.sh" "${FORWARD_ARGS[@]}"

echo ""
echo "==> Done! Activate with:"
echo "    source ${VENV_DIR}/bin/activate"
