#!/bin/sh

# Download Local LLM models into /userdata on first boot
# This script is intended to be run by systemd (oneshot) and can also be run manually

set -e

BASE_DIR="/userdata/system/local-llm/models"
STT_DIR="$BASE_DIR/stt"
LLM_DIR="$BASE_DIR/llm"
TTS_DIR="$BASE_DIR/tts"

# Model URLs
URL_STT_WHISPER="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
URL_LLM_JAN="https://huggingface.co/Menlo/Jan-nano-gguf/resolve/main/jan-nano-4b-Q3_K_M.gguf"
URL_TTS_ENCODER="https://huggingface.co/amrmantawi/paroli-models/resolve/main/encoder.onnx"
URL_TTS_DECODER="https://huggingface.co/amrmantawi/paroli-models/resolve/main/decoder.onnx"
URL_TTS_CONFIG="https://huggingface.co/amrmantawi/paroli-models/resolve/main/config.json"

log() { echo "[local-llm-install] $*"; }

download_if_missing() {
  dest="$1"
  url="$2"
  if [ -f "$dest" ]; then
    log "Already present: $dest"
    return 0
  fi
  tmp="$dest.tmp$$"
  log "Downloading: $url -> $dest"
  mkdir -p "$(dirname "$dest")"
  if command -v wget >/dev/null 2>&1; then
    wget -nv --tries=3 --timeout=300 -O "$tmp" "$url"
  else
    # Busybox build typically provides wget; fallback to curl if available
    if command -v curl >/dev/null 2>&1; then
      curl -L --fail --retry 3 --connect-timeout 30 -o "$tmp" "$url"
    else
      log "Neither wget nor curl available" >&2
      exit 1
    fi
  fi
  mv "$tmp" "$dest"
}

mkdir -p "$STT_DIR" "$LLM_DIR" "$TTS_DIR"

# Whisper STT
download_if_missing "$STT_DIR/ggml-base.en.bin" "$URL_STT_WHISPER"

# LLM (Jan nano)
download_if_missing "$LLM_DIR/jan-nano-4b-Q3_K_M.gguf" "$URL_LLM_JAN"

# TTS (Paroli models: encoder, decoder, config, espeak data)
download_if_missing "$TTS_DIR/encoder.onnx" "$URL_TTS_ENCODER"
download_if_missing "$TTS_DIR/decoder.onnx" "$URL_TTS_DECODER"
download_if_missing "$TTS_DIR/config.json" "$URL_TTS_CONFIG"

log "Model installation complete in $BASE_DIR"


