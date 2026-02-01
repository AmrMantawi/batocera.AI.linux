#!/bin/bash
# Setup script for local-llm models
# This script downloads and installs model files, then generates models.json

set -e

# Default paths
MODELS_DIR="/userdata/system/local-llm/models"
CONFIG_DIR="/userdata/system/local-llm/config"
CONFIG_FILE="${CONFIG_DIR}/models.json"

# Model URLs
# STT (Sherpa ONNX)
SHERPA_ENCODER_URL="https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06/resolve/main/encoder.onnx"
SHERPA_DECODER_URL="https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06/resolve/main/decoder.onnx"
SHERPA_JOINER_URL="https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06/resolve/main/joiner.onnx"
SHERPA_TOKENS_URL="https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06/resolve/main/tokens.txt"
SILERO_VAD_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.int8.onnx"

# TTS (Paroli)
PAROLI_ENCODER_URL="https://huggingface.co/amrmantawi/paroli-models/resolve/main/encoder.onnx"
PAROLI_DECODER_URL="https://huggingface.co/amrmantawi/paroli-models/resolve/main/decoder.onnx"
PAROLI_CONFIG_URL="https://huggingface.co/amrmantawi/paroli-models/resolve/main/config.json"

# LLM (RKLLM)
RKLLM_MODEL_URL="https://huggingface.co/amrmantawi/Qwen2.5-3B-Instruct-rk3588-1.2.2/resolve/main/Qwen2.5-3B-Instruct-rk3588-w8a8-opt-0-hybrid-ratio-0.0.rkllm"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo_error "Please run as root (use sudo)"
    exit 1
fi

# Function to check available disk space (in MB)
check_disk_space() {
    local path=$1
    local required_mb=$2
    
    if [ -d "$path" ]; then
        local available_mb=$(df -m "$path" | tail -1 | awk '{print $4}')
        if [ "$available_mb" -lt "$required_mb" ]; then
            echo_error "Insufficient disk space on $(df -h "$path" | tail -1 | awk '{print $1}')"
            echo_error "Required: ${required_mb}MB, Available: ${available_mb}MB"
            return 1
        fi
        echo_info "Available disk space: ${available_mb}MB (required: ${required_mb}MB)"
        return 0
    else
        echo_warn "Cannot check disk space for $path (directory doesn't exist yet)"
        return 0
    fi
}

# Create directories
echo_info "Creating model directories..."
echo_info "Models will be installed to: ${MODELS_DIR}"
echo_info "This location uses persistent storage (not memory)"
mkdir -p "${MODELS_DIR}/stt"
mkdir -p "${MODELS_DIR}/tts"
mkdir -p "${MODELS_DIR}/llm"
mkdir -p "${CONFIG_DIR}"

# Clean up any partial/incomplete files from previous failed downloads
echo_info "Checking for incomplete downloads from previous runs..."
find "${MODELS_DIR}" -name "*.tmp" -type f -delete 2>/dev/null || true
# Remove empty files that might have been created during failed downloads
find "${MODELS_DIR}" -type f -empty -delete 2>/dev/null || true

# Function to download a file if it doesn't exist
download_file() {
    local url=$1
    local dest=$2
    local desc=$3
    local min_size=${4:-0}  # Optional minimum file size in bytes
    
    if [ -f "$dest" ]; then
        # Verify file is not empty and meets minimum size if specified
        if [ "$min_size" -gt 0 ]; then
            local file_size=$(stat -f%z "$dest" 2>/dev/null || stat -c%s "$dest" 2>/dev/null || echo "0")
            if [ "$file_size" -lt "$min_size" ]; then
                echo_warn "$desc exists but appears incomplete (${file_size} bytes, expected at least ${min_size} bytes)"
                echo_info "Removing incomplete file and re-downloading..."
                rm -f "$dest"
            else
                echo_info "$desc already exists at $dest (${file_size} bytes)"
                return 0
            fi
        else
            # Basic check - file should not be empty
            if [ ! -s "$dest" ]; then
                echo_warn "$desc exists but is empty, removing and re-downloading..."
                rm -f "$dest"
            else
                echo_info "$desc already exists at $dest"
                return 0
            fi
        fi
    fi
    
    echo_info "Downloading $desc..."
    # Use a temporary file during download to avoid partial files
    local temp_dest="${dest}.tmp"
    
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "$temp_dest" "$url" || {
            echo_error "Failed to download $desc from $url"
            rm -f "$temp_dest"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$temp_dest" "$url" || {
            echo_error "Failed to download $desc from $url"
            rm -f "$temp_dest"
            return 1
        }
    else
        echo_error "Neither wget nor curl is available. Please install one."
        return 1
    fi
    
    # Verify downloaded file is not empty
    if [ ! -s "$temp_dest" ]; then
        echo_error "Downloaded file is empty"
        rm -f "$temp_dest"
        return 1
    fi
    
    # Verify minimum size if specified
    if [ "$min_size" -gt 0 ]; then
        local file_size=$(stat -f%z "$temp_dest" 2>/dev/null || stat -c%s "$temp_dest" 2>/dev/null || echo "0")
        if [ "$file_size" -lt "$min_size" ]; then
            echo_error "Downloaded file is too small (${file_size} bytes, expected at least ${min_size} bytes)"
            rm -f "$temp_dest"
            return 1
        fi
    fi
    
    # Move temp file to final destination atomically
    mv "$temp_dest" "$dest" || {
        echo_error "Failed to move downloaded file to destination"
        rm -f "$temp_dest"
        return 1
    }
    
    echo_info "Successfully downloaded $desc"
}

# Download STT models (Sherpa ONNX)
echo_info "Setting up STT (Speech-to-Text) models..."
echo_info "Downloading Sherpa ONNX models from GitHub releases..."

echo_info "Downloading Sherpa ONNX models..."

# Disk space check for individual files (~100MB total)
# encoder ~70MB, decoder ~0.6MB, joiner ~0.3MB, tokens ~6KB
check_disk_space "${MODELS_DIR}/stt" 150 || {
    echo_error "Not enough disk space to download Sherpa ONNX models"
    echo_error "Please free up space or install models manually"
    exit 1
}

# Download Encoder
download_file \
    "${SHERPA_ENCODER_URL}" \
    "${MODELS_DIR}/stt/encoder.onnx" \
    "Sherpa encoder model" \
    50000000 # ~50MB minimum

# Download Decoder
download_file \
    "${SHERPA_DECODER_URL}" \
    "${MODELS_DIR}/stt/decoder.onnx" \
    "Sherpa decoder model" \
    500000 # ~500KB minimum

# Download Joiner
download_file \
    "${SHERPA_JOINER_URL}" \
    "${MODELS_DIR}/stt/joiner.onnx" \
    "Sherpa joiner model" \
    200000 # ~200KB minimum

# Download Tokens
download_file \
    "${SHERPA_TOKENS_URL}" \
    "${MODELS_DIR}/stt/tokens.txt" \
    "Sherpa tokens file" \
    1000 # ~1KB minimum

echo_info "Sherpa ONNX models downloaded"

# VAD model (int8 quantized)
echo_info "Downloading VAD model..."
download_file \
    "${SILERO_VAD_URL}" \
    "${MODELS_DIR}/stt/silero_vad.int8.onnx" \
    "Silero VAD model (int8 quantized)" \
    100000  # ~100KB minimum

# Download TTS models (Paroli)
echo_info "Setting up TTS (Text-to-Speech) models..."
echo_info "Downloading Paroli models from Hugging Face..."

download_file \
    "${PAROLI_ENCODER_URL}" \
    "${MODELS_DIR}/tts/encoder.onnx" \
    "Paroli encoder model" \
    20000000  # ~20MB minimum

download_file \
    "${PAROLI_DECODER_URL}" \
    "${MODELS_DIR}/tts/decoder.onnx" \
    "Paroli decoder model" \
    30000000  # ~30MB minimum

download_file \
    "${PAROLI_CONFIG_URL}" \
    "${MODELS_DIR}/tts/config.json" \
    "Paroli config file" \
    1000  # 1KB minimum

# Download LLM model (RKLLM)
echo_info "Setting up LLM (Large Language Model) models..."
echo_info "Downloading RKLLM model from Hugging Face..."

# Check disk space before downloading large RKLLM model (~3-4GB)
check_disk_space "${MODELS_DIR}/llm" 5000 || {
    echo_error "Not enough disk space to download RKLLM model (requires ~5GB free)"
    echo_error "Please free up space or install model manually"
    exit 1
}

download_file \
    "${RKLLM_MODEL_URL}" \
    "${MODELS_DIR}/llm/model.rkllm" \
    "RKLLM model (Qwen2.5-3B-Instruct-rk3588)" \
    1000000000  # ~1GB minimum (model is likely 3-4GB)

# Generate models.json
echo_info "Generating models.json configuration file..."

# Check disk space before writing config file
check_disk_space "${CONFIG_DIR}" 1 || {
    echo_error "Not enough disk space to write configuration file"
    echo_error "Please free up space on $(df -h "${CONFIG_DIR}" | tail -1 | awk '{print $1}')"
    exit 1
}

# Write config file to temp location first, then move atomically
TEMP_CONFIG="${CONFIG_FILE}.tmp"
cat > "${TEMP_CONFIG}" <<'EOF'
{
  "models": {
    "stt": {
      "sherpa": {
        "encoder": {
          "path": "/userdata/system/local-llm/models/stt/encoder.onnx",
          "description": "Sherpa encoder model (ONNX)"
        },
        "decoder": {
          "path": "/userdata/system/local-llm/models/stt/decoder.onnx",
          "description": "Sherpa decoder model (ONNX)"
        },
        "joiner": {
          "path": "/userdata/system/local-llm/models/stt/joiner.onnx",
          "description": "Sherpa joiner model (ONNX)"
        },
        "tokens": {
          "path": "/userdata/system/local-llm/models/stt/tokens.txt",
          "description": "Sherpa tokens file"
        },
        "vad": {
          "path": "/userdata/system/local-llm/models/stt/silero_vad.int8.onnx",
          "description": "Sherpa VAD model (ONNX)"
        }
      }
    },
    "llm": {
      "rkllm": {
        "model": {
          "path": "/userdata/system/local-llm/models/llm/model.rkllm",
          "description": "RKLLM model for text generation"
        }
      }
    },
    "tts": {
      "paroli": {
        "encoder": {
          "path": "/userdata/system/local-llm/models/tts/encoder.onnx",
          "description": "Paroli encoder model (ONNX)"
        },
        "decoder": {
          "path": "/userdata/system/local-llm/models/tts/decoder.onnx",
          "description": "Paroli decoder model (ONNX)"
        },
        "config": {
          "path": "/userdata/system/local-llm/models/tts/config.json",
          "description": "Paroli model configuration JSON"
        }
      }
    },
    "rag": {
      "kb_root_dir": "/userdata/system/local-llm/kb",
      "top_k": 4,
      "similarity_threshold": 0.3,
      "max_context_tokens": 512,
      "model": "sentence-transformers/all-MiniLM-L6-v2"
    }
  },
  "settings": {
    "audio": {
      "alsa_device": "default",
      "sample_rate": 16000,
      "buffer_ms": 30000,
      "vad_threshold": 0.6,
      "vad_capture_ms": 10000
    }
  }
}
EOF

# Move temp file to final location atomically
mv "${TEMP_CONFIG}" "${CONFIG_FILE}" || {
    echo_error "Failed to write configuration file (disk may be full)"
    rm -f "${TEMP_CONFIG}"
    exit 1
}
chmod 644 "${CONFIG_FILE}"
echo_info "Configuration file created at ${CONFIG_FILE}"

# Summary
echo ""
echo_info "Setup complete!"
echo ""
echo "Storage location: All models are installed to persistent storage (not memory)"
echo "  Base directory: ${MODELS_DIR}"
echo "  Filesystem: $(df -h "${MODELS_DIR}" 2>/dev/null | tail -1 | awk '{print $1 " (" $4 " free)"}')"
echo ""
echo "Model directories created:"
echo "  - STT models: ${MODELS_DIR}/stt"
echo "  - TTS models: ${MODELS_DIR}/tts"
echo "  - LLM models: ${MODELS_DIR}/llm"
echo "  - Config file: ${CONFIG_FILE}"
echo ""
echo_info "Downloaded models:"
echo ""
echo "STT (Sherpa) models:"
echo "  - encoder.onnx"
echo "  - decoder.onnx"
echo "  - joiner.onnx"
echo "  - tokens.txt"
echo "  - silero_vad.int8.onnx"
echo ""
echo "TTS (Paroli) models:"
echo "  - encoder.onnx"
echo "  - decoder.onnx"
echo "  - config.json"
echo ""
echo "LLM (RKLLM) model:"
echo "  - model.rkllm (Qwen2.5-3B-Instruct-rk3588)"
echo ""
echo_info "local-llm should now be ready to use!"
