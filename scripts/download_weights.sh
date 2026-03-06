#!/usr/bin/env bash
#
# Download all model weights required by MuseTalk.
#
# Uses huggingface-cli and gdown from the project venv.
# Downloads to ./models/ relative to the project root.
#
# Usage:
#   bash scripts/download_weights.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_DIR="${PROJECT_DIR}/.venv"
MODELS_DIR="${PROJECT_DIR}/models"

# Use venv binaries if available, otherwise fall back to system
if [ -x "${VENV_DIR}/bin/pip" ]; then
    PIP="${VENV_DIR}/bin/pip"
    HF_CLI="${VENV_DIR}/bin/huggingface-cli"
    GDOWN="${VENV_DIR}/bin/gdown"
else
    PIP="pip"
    HF_CLI="huggingface-cli"
    GDOWN="gdown"
fi

# Create necessary directories
mkdir -p "${MODELS_DIR}"/{musetalk,musetalkV15,syncnet,dwpose,face-parse-bisent,sd-vae,whisper}

# Install required packages (pin huggingface_hub<1.0 for transformers compatibility)
"${PIP}" install "huggingface_hub[cli]<1.0" gdown

# Download MuseTalk V1.0 weights
echo "==> Downloading MuseTalk V1.0 weights..."
"${HF_CLI}" download TMElyralab/MuseTalk \
  --local-dir "${MODELS_DIR}" \
  --include "musetalk/musetalk.json" "musetalk/pytorch_model.bin"

# Download MuseTalk V1.5 weights
echo "==> Downloading MuseTalk V1.5 weights..."
"${HF_CLI}" download TMElyralab/MuseTalk \
  --local-dir "${MODELS_DIR}" \
  --include "musetalkV15/musetalk.json" "musetalkV15/unet.pth"

# Download SD VAE weights
echo "==> Downloading SD VAE weights..."
"${HF_CLI}" download stabilityai/sd-vae-ft-mse \
  --local-dir "${MODELS_DIR}/sd-vae" \
  --include "config.json" "diffusion_pytorch_model.bin"

# Download Whisper weights
echo "==> Downloading Whisper weights..."
"${HF_CLI}" download openai/whisper-tiny \
  --local-dir "${MODELS_DIR}/whisper" \
  --include "config.json" "pytorch_model.bin" "preprocessor_config.json"

# Download DWPose weights
echo "==> Downloading DWPose weights..."
"${HF_CLI}" download yzd-v/DWPose \
  --local-dir "${MODELS_DIR}/dwpose" \
  --include "dw-ll_ucoco_384.pth"

# Download SyncNet weights
echo "==> Downloading SyncNet weights..."
"${HF_CLI}" download ByteDance/LatentSync \
  --local-dir "${MODELS_DIR}/syncnet" \
  --include "latentsync_syncnet.pt"

# Download Face Parse Bisent weights
echo "==> Downloading Face Parse weights..."
"${GDOWN}" --id 154JgKpzCPW82qINcVieuPH3fZ2e0P812 -O "${MODELS_DIR}/face-parse-bisent/79999_iter.pth"
curl -L https://download.pytorch.org/models/resnet18-5c106cde.pth \
  -o "${MODELS_DIR}/face-parse-bisent/resnet18-5c106cde.pth"

echo "==> All weights downloaded successfully!"
