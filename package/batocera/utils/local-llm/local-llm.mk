################################################################################
#
# local-llm
#
################################################################################

LOCAL_LLM_VERSION = 0e8aac8febeaa02303fa004141ddaecbd969f58e
LOCAL_LLM_SITE = https://github.com/AmrMantawi/local-llm.git
LOCAL_LLM_SITE_METHOD = git
LOCAL_LLM_GIT_SUBMODULES = YES
LOCAL_LLM_LICENSE = MIT
LOCAL_LLM_LICENSE_FILE = LICENSE

LOCAL_LLM_OVERRIDE_SRCDIR = /sources/local-llm

LOCAL_LLM_DEPENDENCIES = sdl2 alsa-lib json-for-modern-cpp portaudio xtensor opus libopusenc libsoxr host-pkgconf

LOCAL_LLM_SUPPORTS_IN_SOURCE_BUILD = NO

# Enable the required modules: paroli, rkllm, and sherpa
LOCAL_LLM_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
LOCAL_LLM_CONF_OPTS += -DUSE_PAROLI=ON
LOCAL_LLM_CONF_OPTS += -DUSE_RKLLM=ON
LOCAL_LLM_CONF_OPTS += -DUSE_SHERPA=ON
LOCAL_LLM_CONF_OPTS += -DUSE_WHISPER=OFF
LOCAL_LLM_CONF_OPTS += -DUSE_LLAMA=OFF

# Build fully static to avoid missing shared libs (e.g., libwhisper.so.1)
LOCAL_LLM_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
LOCAL_LLM_CONF_OPTS += -DWHISPER_BUILD_SHARED=OFF -DLLAMA_BUILD_SHARED=OFF

# Ensure nested CMake projects (like paroli-daemon) can find xtensor
# host-pkgconf helps CMake's find_package() locate dependencies
# Set CMAKE_SYSROOT so nested projects can find headers in staging directory
LOCAL_LLM_CONF_OPTS += -DCMAKE_SYSROOT="$(STAGING_DIR)"
# Set CMAKE_PREFIX_PATH to help find_package() locate xtensor config files
LOCAL_LLM_CONF_OPTS += -DCMAKE_PREFIX_PATH="$(STAGING_DIR)/usr"
# Also add staging include directory to compiler flags as fallback
LOCAL_LLM_CONF_OPTS += -DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS) -I$(STAGING_DIR)/usr/include"

# Set AARCH64_MCPU for optimization on rk3588 (cortex-a76)
ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_RK3588),y)
	LOCAL_LLM_CONF_OPTS += -DAARCH64_MCPU=cortex-a76+crc
endif

# Set runtime espeak-ng data path (overrides piper_phonemize build-dir default)
LOCAL_LLM_CONF_OPTS += -DESPEAK_NG_DATA_DIR=/usr/share/espeak-ng-data

# Configure downloads sherpa-onnx deps (kaldifst, kaldi-native-fbank, etc.) from GitHub.
# HTTP 502 from GitHub is transient; just re-run the build.

# First run CMake install to install onnxruntime and other dependencies
define LOCAL_LLM_INSTALL_TARGET_CMDS
	# Run CMake install first to install onnxruntime and other libraries
	$(TARGET_MAKE_ENV) DESTDIR=$(TARGET_DIR) $(BR2_CMAKE) --install $(@D)/buildroot-build
	# Now install our custom files
	mkdir -p $(TARGET_DIR)/usr/bin
	mkdir -p $(TARGET_DIR)/usr/libexec
	mkdir -p $(TARGET_DIR)/usr/lib
	mkdir -p $(TARGET_DIR)/usr/share/local-llm/config
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/local-llm $(TARGET_DIR)/usr/libexec/local-llm
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/local-llm/local-llm $(TARGET_DIR)/usr/bin/local-llm
	# Install RKLLM runtime library
	if [ ! -f "$(@D)/third_party/rknn-llm/rkllm-runtime/Linux/librkllm_api/aarch64/librkllmrt.so" ]; then \
		echo "ERROR: librkllmrt.so not found at $(@D)/third_party/rknn-llm/rkllm-runtime/Linux/librkllm_api/aarch64/librkllmrt.so"; \
		exit 1; \
	fi
	$(INSTALL) -D -m 0644 $(@D)/third_party/rknn-llm/rkllm-runtime/Linux/librkllm_api/aarch64/librkllmrt.so $(TARGET_DIR)/usr/lib/librkllmrt.so
	# Install ONNX Runtime shared library from piper-phonemize (needed even when BUILD_SHARED_LIBS=OFF)
	# The correct version (1.14.1) with VERS_1.14.1 symbol is bundled with piper-phonemize
	if [ ! -d "$(@D)/deps/piper_phonemize/lib" ]; then \
		echo "ERROR: piper-phonemize lib directory not found at $(@D)/deps/piper_phonemize/lib"; \
		exit 1; \
	fi; \
	if [ -f "$(@D)/deps/piper_phonemize/lib/libonnxruntime.so.1.14.1" ]; then \
		$(INSTALL) -D -m 0644 $(@D)/deps/piper_phonemize/lib/libonnxruntime.so* $(TARGET_DIR)/usr/lib/; \
	else \
		echo "ERROR: libonnxruntime.so.1.14.1 not found in $(@D)/deps/piper_phonemize/lib"; \
		exit 1; \
	fi; \
	# Install piper-phonemize libraries (downloaded to deps/piper_phonemize during build)
	$(INSTALL) -D -m 0644 $(@D)/deps/piper_phonemize/lib/libpiper_phonemize.so* $(TARGET_DIR)/usr/lib/; \
	# Install espeak-ng library (dependency of piper-phonemize)
	if [ -f "$(@D)/deps/piper_phonemize/lib/libespeak-ng.so.1.52.0.1" ]; then \
		$(INSTALL) -D -m 0644 $(@D)/deps/piper_phonemize/lib/libespeak-ng.so* $(TARGET_DIR)/usr/lib/; \
	fi
	cp -f $(@D)/config/models.json $(TARGET_DIR)/usr/share/local-llm/config/models.json
	# Install espeak-ng-data (required for piper-phonemize)
	mkdir -p $(TARGET_DIR)/usr/share/espeak-ng-data
	cp -r $(@D)/deps/piper_phonemize/share/espeak-ng-data/* $(TARGET_DIR)/usr/share/espeak-ng-data/
	# phontab is generated at build time; copy from build dir if missing from share
	if [ ! -f "$(TARGET_DIR)/usr/share/espeak-ng-data/phontab" ]; then \
		for try in "$(@D)/buildroot-build/_deps/espeak_ng-build/espeak-ng-data/phontab" \
		          "$(@D)/deps/piper_phonemize/build/espeak-ng/espeak-ng-data/phontab" \
		          "$(@D)/deps/piper_phonemize/build/espeak-ng-data/phontab" \
		          "$(@D)/buildroot-build/deps/piper_phonemize/build/espeak-ng/espeak-ng-data/phontab" \
		          "$(TARGET_DIR)/usr/share/espeak-data/phontab"; do \
			if [ -f "$$try" ]; then cp "$$try" $(TARGET_DIR)/usr/share/espeak-ng-data/; break; fi; \
		done; \
	fi
endef

# Install Batocera setup script last so it overwrites any upstream script (uses /userdata)
define LOCAL_LLM_INSTALL_SETUP_SCRIPT
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/local-llm/setup-models.sh $(TARGET_DIR)/usr/bin/local-llm-setup-models
endef
LOCAL_LLM_POST_INSTALL_TARGET_HOOKS += LOCAL_LLM_INSTALL_SETUP_SCRIPT

$(eval $(cmake-package))
