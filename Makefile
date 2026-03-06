.PHONY: help venv install-deps download-weights \
       infer infer-realtime demo \
       preprocess train-stage1 train-stage2 \
       clean-results check-ffmpeg check-weights check-venv

# ─── Configuration ────────────────────────────────────────────────────

VENV_DIR ?= .venv
PYTHON_BIN ?= python3.10
CUDA_VERSION ?= 11.8
VENV_PYTHON = $(VENV_DIR)/bin/python
VENV_PIP = $(VENV_DIR)/bin/pip
VENV_ACCELERATE = $(VENV_DIR)/bin/accelerate

VERSION ?= v15
GPU_ID ?= 0
BATCH_SIZE ?= 8
FPS ?= 25
FLOAT16 ?=
GRADIO_PORT ?= 7860

# Model paths
ifeq ($(VERSION),v15)
  UNET_MODEL_PATH = models/musetalkV15/unet.pth
  UNET_CONFIG = models/musetalkV15/musetalk.json
  VERSION_ARG = v15
else
  UNET_MODEL_PATH = models/musetalk/pytorch_model.bin
  UNET_CONFIG = models/musetalk/musetalk.json
  VERSION_ARG = v1
endif

##@ General
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "; section=""} \
		/^##@/ {section=substr($$0, 5); next} \
		/^[a-zA-Z0-9_-]+:.*?## / { \
			if (section != prev) {printf "\n\033[1m%s\033[0m\n", section; prev=section} \
			printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)
	@echo ""

##@ Setup
venv: ## Create venv and install all dependencies (PyTorch, requirements, MMLab)
	bash scripts/setup-venv.sh --python $(PYTHON_BIN) --cuda $(CUDA_VERSION) --venv $(VENV_DIR)

install-deps: check-venv ## Install all dependencies into existing venv (no recreate)
	bash scripts/install-deps.sh --cuda $(CUDA_VERSION) --venv $(VENV_DIR)

download-weights: ## Download all model weights
	bash scripts/download_weights.sh

##@ Training
preprocess: check-venv ## Preprocess training data
	$(VENV_PYTHON) -m scripts.preprocess --config configs/training/preprocess.yaml

train-stage1: check-venv ## Train stage 1 (L1 + perceptual + GAN)
	$(VENV_ACCELERATE) launch \
		--config_file configs/training/gpu.yaml \
		--main_process_port 29502 \
		train.py --config configs/training/stage1.yaml

train-stage2: check-venv ## Train stage 2 (adds sync loss, temporal sampling)
	$(VENV_ACCELERATE) launch \
		--config_file configs/training/gpu.yaml \
		--main_process_port 29502 \
		train.py --config configs/training/stage2.yaml

##@ Inference
infer: check-venv check-ffmpeg ## Run normal inference (VERSION=v15|v1, default: v15)
	$(VENV_PYTHON) -m scripts.inference \
		--inference_config configs/inference/test.yaml \
		--result_dir results/test \
		--unet_model_path $(UNET_MODEL_PATH) \
		--unet_config $(UNET_CONFIG) \
		--version $(VERSION_ARG) \
		--batch_size $(BATCH_SIZE) \
		--gpu_id $(GPU_ID)

infer-realtime: check-venv check-ffmpeg ## Run real-time inference (VERSION=v15|v1, default: v15)
	$(VENV_PYTHON) -m scripts.realtime_inference \
		--inference_config configs/inference/realtime.yaml \
		--result_dir results/realtime \
		--unet_model_path $(UNET_MODEL_PATH) \
		--unet_config $(UNET_CONFIG) \
		--version $(VERSION_ARG) \
		--fps $(FPS) \
		--gpu_id $(GPU_ID)

demo: check-venv check-ffmpeg ## Launch Gradio web demo (FLOAT16=1 for half precision, GRADIO_PORT=7860)
	$(VENV_PYTHON) app.py \
		$(if $(FLOAT16),--use_float16) \
		--port $(GRADIO_PORT)

##@ Checks
check-venv: ## Verify venv exists
	@test -x $(VENV_PYTHON) || { echo "Error: venv not found at $(VENV_DIR). Run 'make venv' first."; exit 1; }

check-ffmpeg: ## Verify ffmpeg is installed
	@command -v ffmpeg >/dev/null 2>&1 || { echo "Error: ffmpeg not found. Please install ffmpeg first."; exit 1; }

check-weights: ## Verify all required model weights exist
	@missing=0; \
	for f in \
		models/musetalkV15/unet.pth \
		models/musetalkV15/musetalk.json \
		models/sd-vae/config.json \
		models/sd-vae/diffusion_pytorch_model.bin \
		models/whisper/config.json \
		models/whisper/pytorch_model.bin \
		models/dwpose/dw-ll_ucoco_384.pth \
		models/syncnet/latentsync_syncnet.pt \
		models/face-parse-bisent/79999_iter.pth \
		models/face-parse-bisent/resnet18-5c106cde.pth; \
	do \
		if [ ! -f "$$f" ]; then \
			echo "Missing: $$f"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo "Run 'make download-weights' to download missing files."; \
		exit 1; \
	else \
		echo "All model weights present."; \
	fi

##@ Cleanup
clean-results: ## Remove generated results
	rm -rf results/test results/realtime results/output results/debug

# ─── Deprecated ───────────────────────────────────────────────────────
# Conda setup is deprecated. Use 'make venv' instead.
# See README.md for legacy conda instructions if needed.
