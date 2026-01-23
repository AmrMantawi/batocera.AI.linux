#!/bin/bash
# Setup script for local-llm models
# This script downloads and installs model files, then generates models.json

set -e

# Default paths
MODELS_DIR="/usr/share/local-llm/models"
CONFIG_DIR="/usr/share/local-llm/config"
CONFIG_FILE="${CONFIG_DIR}/models.json"

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

# Download and extract Sherpa ONNX model archive (non-quantized version)
# This model is based on the same training as the 2022-12-29 version
# Use persistent storage instead of /tmp (which might be tmpfs/in-memory)
TEMP_BASE_DIR="/usr/share/local-llm"
mkdir -p "${TEMP_BASE_DIR}"
SHERPA_ARCHIVE="${TEMP_BASE_DIR}/sherpa-onnx-streaming-zipformer-en-2023-02-21.tar.bz2"
SHERPA_EXTRACT_DIR="${TEMP_BASE_DIR}/sherpa-onnx-extract"

if [ ! -f "${MODELS_DIR}/stt/encoder.onnx" ] || [ ! -f "${MODELS_DIR}/stt/decoder.onnx" ] || [ ! -f "${MODELS_DIR}/stt/joiner.onnx" ] || [ ! -f "${MODELS_DIR}/stt/tokens.txt" ]; then
    # Check disk space before downloading (archive ~600MB, extracted ~1.5GB)
    echo_info "Checking disk space..."
    check_disk_space "${TEMP_BASE_DIR}" 2500 || {
        echo_error "Not enough disk space to download and extract Sherpa ONNX models"
        echo_error "Please free up space or install models manually"
        exit 1
    }
    
    echo_info "Downloading Sherpa ONNX model archive..."
    mkdir -p "${SHERPA_EXTRACT_DIR}"
    
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "${SHERPA_ARCHIVE}" \
            "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-02-21.tar.bz2" || {
            echo_error "Failed to download Sherpa ONNX model archive"
            exit 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "${SHERPA_ARCHIVE}" \
            "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-02-21.tar.bz2" || {
            echo_error "Failed to download Sherpa ONNX model archive"
            exit 1
        }
    else
        echo_error "Neither wget nor curl is available. Please install one."
        exit 1
    fi
    
    echo_info "Extracting Sherpa ONNX model archive..."
    if command -v tar >/dev/null 2>&1; then
        tar -xjf "${SHERPA_ARCHIVE}" -C "${SHERPA_EXTRACT_DIR}" || {
            echo_error "Failed to extract archive"
            exit 1
        }
    else
        echo_error "tar is not available. Please install it."
        exit 1
    fi
    
    # Copy files from extracted archive (using FP32/non-quantized versions)
    MODEL_DIR="${SHERPA_EXTRACT_DIR}/sherpa-onnx-streaming-zipformer-en-2023-02-21"
    if [ -d "${MODEL_DIR}" ]; then
        echo_info "Copying Sherpa ONNX model files (non-quantized FP32 versions)..."
        cp -f "${MODEL_DIR}/encoder-epoch-99-avg-1.onnx" "${MODELS_DIR}/stt/encoder.onnx" || {
            echo_error "Failed to copy encoder.onnx"
            exit 1
        }
        cp -f "${MODEL_DIR}/decoder-epoch-99-avg-1.onnx" "${MODELS_DIR}/stt/decoder.onnx" || {
            echo_error "Failed to copy decoder.onnx"
            exit 1
        }
        cp -f "${MODEL_DIR}/joiner-epoch-99-avg-1.onnx" "${MODELS_DIR}/stt/joiner.onnx" || {
            echo_error "Failed to copy joiner.onnx"
            exit 1
        }
        cp -f "${MODEL_DIR}/tokens.txt" "${MODELS_DIR}/stt/tokens.txt" || {
            echo_error "Failed to copy tokens.txt"
            exit 1
        }
        
        # Verify copied files are not empty
        echo_info "Verifying copied files..."
        for file in "${MODELS_DIR}/stt/encoder.onnx" "${MODELS_DIR}/stt/decoder.onnx" "${MODELS_DIR}/stt/joiner.onnx" "${MODELS_DIR}/stt/tokens.txt"; do
            if [ ! -s "$file" ]; then
                echo_error "File $file is empty or missing after copy"
                exit 1
            fi
        done
        
        # Verify minimum sizes for ONNX files (rough estimates)
        local encoder_size=$(stat -f%z "${MODELS_DIR}/stt/encoder.onnx" 2>/dev/null || stat -c%s "${MODELS_DIR}/stt/encoder.onnx" 2>/dev/null || echo "0")
        local decoder_size=$(stat -f%z "${MODELS_DIR}/stt/decoder.onnx" 2>/dev/null || stat -c%s "${MODELS_DIR}/stt/decoder.onnx" 2>/dev/null || echo "0")
        local joiner_size=$(stat -f%z "${MODELS_DIR}/stt/joiner.onnx" 2>/dev/null || stat -c%s "${MODELS_DIR}/stt/joiner.onnx" 2>/dev/null || echo "0")
        
        if [ "$encoder_size" -lt 100000000 ] || [ "$decoder_size" -lt 1000000 ] || [ "$joiner_size" -lt 500000 ]; then
            echo_error "Copied files appear to be too small (encoder: ${encoder_size}, decoder: ${decoder_size}, joiner: ${joiner_size})"
            echo_error "Files may be incomplete"
            exit 1
        fi
        
        echo_info "File verification complete (encoder: ${encoder_size} bytes, decoder: ${decoder_size} bytes, joiner: ${joiner_size} bytes)"
    else
        echo_error "Extracted model directory not found"
        exit 1
    fi
    
    # Cleanup
    rm -rf "${SHERPA_ARCHIVE}" "${SHERPA_EXTRACT_DIR}"
    echo_info "Sherpa ONNX models downloaded and installed"
else
    echo_info "Sherpa ONNX models already exist, skipping download"
fi

# VAD model (int8 quantized)
echo_info "Downloading VAD model..."
download_file \
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.int8.onnx" \
    "${MODELS_DIR}/stt/silero_vad.int8.onnx" \
    "Silero VAD model (int8 quantized)" \
    100000  # ~100KB minimum

# Download TTS models (Paroli)
echo_info "Setting up TTS (Text-to-Speech) models..."
echo_info "Downloading Paroli models from Hugging Face..."

download_file \
    "https://huggingface.co/amrmantawi/paroli-models/resolve/main/encoder.onnx" \
    "${MODELS_DIR}/tts/encoder.onnx" \
    "Paroli encoder model" \
    20000000  # ~20MB minimum

download_file \
    "https://huggingface.co/amrmantawi/paroli-models/resolve/main/decoder.onnx" \
    "${MODELS_DIR}/tts/decoder.onnx" \
    "Paroli decoder model" \
    30000000  # ~30MB minimum

download_file \
    "https://huggingface.co/amrmantawi/paroli-models/resolve/main/config.json" \
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
    "https://huggingface.co/amrmantawi/Qwen2.5-3B-Instruct-rk3588-1.2.2/resolve/main/Qwen2.5-3B-Instruct-rk3588-w8a8-opt-0-hybrid-ratio-0.0.rkllm" \
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
          "path": "/usr/share/local-llm/models/stt/encoder.onnx",
          "description": "Sherpa encoder model (ONNX)"
        },
        "decoder": {
          "path": "/usr/share/local-llm/models/stt/decoder.onnx",
          "description": "Sherpa decoder model (ONNX)"
        },
        "joiner": {
          "path": "/usr/share/local-llm/models/stt/joiner.onnx",
          "description": "Sherpa joiner model (ONNX)"
        },
        "tokens": {
          "path": "/usr/share/local-llm/models/stt/tokens.txt",
          "description": "Sherpa tokens file"
        },
        "vad": {
          "path": "/usr/share/local-llm/models/stt/silero_vad.int8.onnx",
          "description": "Sherpa VAD model (ONNX)"
        }
      }
    },
    "llm": {
      "rkllm": {
        "model": {
          "path": "/usr/share/local-llm/models/llm/model.rkllm",
          "description": "RKLLM model for text generation"
        }
      }
    },
    "tts": {
      "paroli": {
        "encoder": {
          "path": "/usr/share/local-llm/models/tts/encoder.onnx",
          "description": "Paroli encoder model (ONNX)"
        },
        "decoder": {
          "path": "/usr/share/local-llm/models/tts/decoder.onnx",
          "description": "Paroli decoder model (ONNX)"
        },
        "config": {
          "path": "/usr/share/local-llm/models/tts/config.json",
          "description": "Paroli model configuration JSON"
        }
      }
    },
    "rag": {
      "kb_root_dir": "/usr/share/local-llm/kb",
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
