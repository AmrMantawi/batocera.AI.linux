#!/bin/sh
set -e

DEST=/userdata/system/local-llm/models
mkdir -p "$DEST/stt" "$DEST/llm" "$DEST/tts"

# URLs (keep in sync with local-llm.mk)
URL_STT="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
URL_RKLLM="https://huggingface.co/amrmantawi/chatglm3-6b-rkllm/resolve/main/chatglm3-6b.rkllm"
URL_TTS_ENC="https://huggingface.co/amrmantawi/paroli-models/resolve/main/encoder.onnx"
URL_TTS_DEC="https://huggingface.co/amrmantawi/paroli-models/resolve/main/decoder.onnx"
URL_TTS_CFG="https://huggingface.co/amrmantawi/paroli-models/resolve/main/config.json"

download_if_missing() {
  url="$1"; out="$2";
  if [ ! -f "$out" ]; then
    echo "Downloading $(basename "$out") ..."
    mkdir -p "$(dirname "$out")"
    wget -O "$out.tmp" "$url"
    mv "$out.tmp" "$out"
  else
    echo "Already present: $out"
  fi
}

download_if_missing "$URL_STT" "$DEST/stt/ggml-base.en.bin"
download_if_missing "$URL_RKLLM" "$DEST/llm/chatglm.rkllm"
download_if_missing "$URL_TTS_ENC" "$DEST/tts/encoder.onnx"
download_if_missing "$URL_TTS_DEC" "$DEST/tts/decoder.onnx"
download_if_missing "$URL_TTS_CFG" "$DEST/tts/config.json"

exit 0

