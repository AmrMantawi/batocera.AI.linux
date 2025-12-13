################################################################################
#
# local-llm
#
################################################################################

LOCAL_LLM_VERSION = 868f7b2c4067d05326d2fb09266f16c282834620
LOCAL_LLM_SITE = https://github.com/AmrMantawi/local-llm.git
LOCAL_LLM_SITE_METHOD = git
LOCAL_LLM_GIT_SUBMODULES = YES

# Use a local working tree instead of fetching
# LOCAL_LLM_OVERRIDE_SRCDIR = /sources/local-llm
LOCAL_LLM_LICENSE = MIT
LOCAL_LLM_LICENSE_FILES = LICENSE

# Dependencies
LOCAL_LLM_DEPENDENCIES = sdl2 alsa-lib opus libopusenc libsoxr host-pkgconf xtensor

# Model sources (fetched at build time and installed into /usr/share)
LOCAL_LLM_MODEL_URL_STT_WHISPER := https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
LOCAL_LLM_MODEL_URL_LLM_RKLLM   := https://huggingface.co/amrmantawi/chatglm3-6b-rkllm/resolve/main/chatglm3-6b.rkllm
LOCAL_LLM_MODEL_URL_TTS_ENCODER := https://huggingface.co/amrmantawi/paroli-models/resolve/main/encoder.onnx
LOCAL_LLM_MODEL_URL_TTS_DECODER := https://huggingface.co/amrmantawi/paroli-models/resolve/main/decoder.onnx
LOCAL_LLM_MODEL_URL_TTS_CONFIG  := https://huggingface.co/amrmantawi/paroli-models/resolve/main/config.json

# local-llm embeds whisper.cpp and llama.cpp; ensure toolchain has pthreads
LOCAL_LLM_CONF_OPTS += -DTHREADS_PREFER_PTHREAD_FLAG=ON

# local-llm is a CMake project
LOCAL_LLM_SUPPORTS_IN_SOURCE_BUILD = NO
LOCAL_LLM_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
LOCAL_LLM_CONF_OPTS += -DUSE_RKLLM=ON -DUSE_WHISPER=ON -DUSE_PAROLI=ON
# Build fully static to avoid missing shared libs (e.g., libwhisper.so.1)
LOCAL_LLM_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
LOCAL_LLM_CONF_OPTS += -DWHISPER_BUILD_SHARED=OFF -DLLAMA_BUILD_SHARED=OFF

define LOCAL_LLM_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/buildroot-build/local-llm \
        $(TARGET_DIR)/usr/bin/local-llm
    
    # Debug: Check binary has no shared deps (cross-safe)
    echo "=== Binary dependencies (cross readelf) ==="
    $(TARGET_READELF) -d $(TARGET_DIR)/usr/bin/local-llm | grep NEEDED || echo "No non-glibc deps"
    
    mkdir -p $(TARGET_DIR)/usr/share/local-llm
    mkdir -p $(TARGET_DIR)/usr/share/local-llm/config
    mkdir -p $(TARGET_DIR)/userdata/system/local-llm/models/stt
    mkdir -p $(TARGET_DIR)/userdata/system/local-llm/models/llm
    mkdir -p $(TARGET_DIR)/userdata/system/local-llm/models/tts

    # Ensure espeak-ng-data is available system-wide at runtime
    mkdir -p $(TARGET_DIR)/usr/share/espeak-ng-data
    [ -d $(@D)/deps/piper_phonemize/share/espeak-ng-data ] && \
        cp -a $(@D)/deps/piper_phonemize/share/espeak-ng-data/. $(TARGET_DIR)/usr/share/espeak-ng-data/ || true
    
    # Create configuration file pointing to preinstalled models under /usr/share
    printf '%s\n' \
      '{' \
      '  "models": {' \
      '    "stt": {' \
      '      "whisper": {' \
      '        "path": "/userdata/system/local-llm/models/stt/ggml-base.en.bin",' \
      '        "type": "whisper",' \
      '        "description": "Whisper base English model for speech-to-text"' \
      '      }' \
      '    },' \
      '    "llm": {' \
      '      "rkllm": {' \
      '        "path": "/userdata/system/local-llm/models/llm/chatglm.rkllm",' \
      '        "type": "rkllm",' \
      '        "description": "ChatGLM3-6B RKLLM model"' \
      '      }' \
      '    },' \
      '    "tts": {' \
      '      "paroli": {' \
      '        "encoder": {' \
      '          "path": "/userdata/system/local-llm/models/tts/encoder.onnx",' \
      '          "type": "paroli",' \
      '          "description": "Paroli encoder model (ONNX)"' \
      '        },' \
      '        "decoder": {' \
      '          "path": "/userdata/system/local-llm/models/tts/decoder.onnx",' \
      '          "type": "paroli",' \
      '          "description": "Paroli decoder model (ONNX)"' \
      '        },' \
      '        "config": {' \
      '          "path": "/userdata/system/local-llm/models/tts/config.json",' \
      '          "type": "paroli",' \
      '          "description": "Paroli model configuration JSON"' \
      '        }' \
      '      }' \
      '    }' \
      '  },' \
      '  "settings": {' \
      '    "audio": {' \
      '      "sample_rate": 16000,' \
      '      "buffer_ms": 30000,' \
      '      "vad_threshold": 0.6,' \
      '      "vad_capture_ms": 10000' \
      '    }' \
      '  }' \
      '}' > $(TARGET_DIR)/usr/share/local-llm/config/models.json
    
    # Install BusyBox init.d fallback script
    $(INSTALL) -D -m 0755 \
        $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/local-llm/S30local-llm \
        $(TARGET_DIR)/etc/init.d/S30local-llm

    # Install systemd service instead of legacy /etc/init.d/local-llm
    mkdir -p $(TARGET_DIR)/usr/lib/systemd/system
    echo "[Unit]"                                                        >  $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "Description=Local LLM assistant"                               >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "After=sound.target local-fs.target local-llm-models.service" >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "Wants=local-llm-models.service"                              >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    # Install model installer script
    $(INSTALL) -D -m 0755 \
        $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/local-llm/install-models.sh \
        $(TARGET_DIR)/usr/bin/local-llm-install-models

    # One-shot service to download models on first boot
    echo "[Unit]"                                                        >  $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo "Description=Download Local LLM models into /userdata"         >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo "After=network-online.target local-fs.target"                  >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo "Wants=network-online.target"                                  >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo "ConditionPathExists=!/userdata/system/local-llm/models/llm/chatglm3-6b.rkllm" >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo ""                                                             >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo "[Service]"                                                    >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo "Type=oneshot"                                                 >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo "ExecStart=/usr/bin/local-llm-install-models"                  >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo ""                                                             >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo "[Install]"                                                    >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service; \
    echo "WantedBy=multi-user.target"                                   >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm-models.service;

    # Enable the model preseed service
    mkdir -p $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants
    ln -sf /usr/lib/systemd/system/local-llm-models.service $(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/local-llm-models.service
    echo ""                                                             >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "[Service]"                                                    >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "Type=simple"                                                  >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "ExecStart=/usr/bin/local-llm --mode server --socket /run/local-llm.sock --config /usr/share/local-llm/config/models.json" >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "WorkingDirectory=/usr/share/local-llm"                        >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "Restart=on-failure"                                           >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "RuntimeDirectory=local-llm"                                   >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "RuntimeDirectoryMode=0755"                                    >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo ""                                                             >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "[Install]"                                                    >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service; \
    echo "WantedBy=multi-user.target"                                   >> $(TARGET_DIR)/usr/lib/systemd/system/local-llm.service;
    
    # Build and install a simple socket test utility (optional)
    $(TARGET_CXX) $(TARGET_CXXFLAGS) -O2 -s \
        -o $(TARGET_DIR)/usr/bin/local-llm-socket-test \
        $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/local-llm/socket-client.cpp \
        $(TARGET_LDFLAGS)

    # Install test script
    $(INSTALL) -D -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/local-llm/test-socket.sh \
        $(TARGET_DIR)/usr/share/local-llm/test-socket.sh
endef

$(eval $(cmake-package))


