################################################################################
#
# pcsx2
#
################################################################################
# Version: Commits on May 17, 2026
ifeq ($(BR2_aarch64),y)
# ARMSX2: PCSX2 fork with a native ARM64 JIT (mainline PCSX2 is interpreter-only on ARM)
# https://github.com/ARMSX2/ARMSX2 - pinned to the linuxv0.0.1 tag (first validated Linux build)
PCSX2_VERSION = 47229e4ff386abd13c6b7ac0e56fb925be3f88e9
PCSX2_SITE = https://github.com/ARMSX2/ARMSX2.git
else
PCSX2_VERSION = e18d5b71832fc96f3ba5dd90113567f5284ee6dd
PCSX2_SITE = https://github.com/pcsx2/pcsx2.git
endif
PCSX2_SITE_METHOD = git
PCSX2_GIT_SUBMODULES = YES
PCSX2_LICENSE = GPLv3
PCSX2_LICENSE_FILE = COPYING.GPLv3
PCSX2_EMULATOR_INFO = pcsx2.emulator.yml

PCSX2_SUPPORTS_IN_SOURCE_BUILD = NO

PCSX2_DEPENDENCIES += alsa-lib ecm fmt freetype host-clang host-libcurl kddockwidgets
PCSX2_DEPENDENCIES += libaio libbacktrace libcurl libgtk3 libpcap libpng libsamplerate
PCSX2_DEPENDENCIES += libsoundtouch plutosvg portaudio qt6base qt6svg qt6tools
PCSX2_DEPENDENCIES += rapidyaml shaderc sdl3 webp wxwidgets xorgproto yaml-cpp zlib

# Use clang for performance
PCSX2_CONF_OPTS += -DCMAKE_C_COMPILER=$(HOST_DIR)/bin/clang
PCSX2_CONF_OPTS += -DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/clang++
PCSX2_CONF_OPTS += -DCMAKE_EXE_LINKER_FLAGS="-lm -lstdc++"

PCSX2_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
PCSX2_CONF_OPTS += -DBUILD_SHARED_LIBS=OFF
PCSX2_CONF_OPTS += -DENABLE_TESTS=OFF
PCSX2_CONF_OPTS += -DUSE_SYSTEM_LIBS=AUTO

ifeq ($(BR2_x86_64),y)
# The following flag is misleading and *needed* ON to avoid doing -march=native
PCSX2_CONF_OPTS += -DDISABLE_ADVANCE_SIMD=ON
endif

ifeq ($(BR2_aarch64),y)
# same flags ARMSX2's own CI uses for its 4K-page-size Linux aarch64 build
PCSX2_CONF_OPTS += -DHOST_PAGE_SIZE=4096
PCSX2_CONF_OPTS += -DHOST_CACHE_LINE_SIZE=64
# kddockwidgets' installed CMake target only exports include/kddockwidgets-qt6 as an
# include dir, not the nested .../kddockwidgets subdir some of its own headers need
# for quote-form includes (eg. core/indicators/ClassicDropIndicatorOverlay.h).
#
# We point CMAKE_CXX_COMPILER at the raw clang binary (not Buildroot's toolchain
# wrapper), which is what normally injects the board's BR2_TARGET_OPTIMIZATION
# flags (-mcpu=cortex-a76+crc etc) into every compile. Explicitly setting
# CMAKE_CXX_FLAGS here also stops Buildroot's own CMake toolchain file from
# filling it in itself (it only does so `if(NOT DEFINED CMAKE_CXX_FLAGS)`), so
# prepend $(TARGET_CXXFLAGS) same as upstream's pcsx2.mk does, to not silently
# lose the board's normal optimization flags for this one package.
PCSX2_CONF_OPTS += -DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS) -Wno-c++11-narrowing -Wno-narrowing -I$(STAGING_DIR)/usr/include/kddockwidgets-qt6/kddockwidgets"
endif

# below may not be needed for newer versions
define PCSX2_FIX_WHOLE_ARCHIVE
	find $(@D) -name "CMakeLists.txt" -exec sed -i 's|.[<]LINK_LIBRARY:WHOLE_ARCHIVE,\([^>]*\)>|-Wl,--whole-archive \1 -Wl,--no-whole-archive|g' {} +
endef
PCSX2_PRE_CONFIGURE_HOOKS += PCSX2_FIX_WHOLE_ARCHIVE

ifeq ($(BR2_PACKAGE_XORG7),y)
    PCSX2_CONF_OPTS += -DX11_API=ON
else
    PCSX2_CONF_OPTS += -DX11_API=OFF
endif

ifeq ($(BR2_PACKAGE_BATOCERA_WAYLAND),y)
    PCSX2_CONF_OPTS += -DWAYLAND_API=ON
else
    PCSX2_CONF_OPTS += -DWAYLAND_API=OFF
endif

ifeq ($(BR2_PACKAGE_HAS_LIBGL),y)
    PCSX2_CONF_OPTS += -DUSE_OPENGL=ON
else
    PCSX2_CONF_OPTS += -DUSE_OPENGL=OFF
endif

ifeq ($(BR2_PACKAGE_BATOCERA_VULKAN),y)
    PCSX2_CONF_OPTS += -DUSE_VULKAN=ON
else
    PCSX2_CONF_OPTS += -DUSE_VULKAN=OFF
endif

ifeq ($(BR2_aarch64),y)
# ARMSX2 renames the built binary to armsx2-qt on Linux (see pcsx2-qt/CMakeLists.txt)
PCSX2_BUILT_BINARY_NAME = armsx2-qt
else
PCSX2_BUILT_BINARY_NAME = pcsx2-qt
endif

define PCSX2_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0755 -D $(@D)/buildroot-build/bin/$(PCSX2_BUILT_BINARY_NAME) \
        $(TARGET_DIR)/usr/pcsx2/bin/pcsx2-qt
	cp -pr  $(@D)/bin/resources $(TARGET_DIR)/usr/pcsx2/bin/
    cp -pr  $(@D)/buildroot-build/bin/translations $(TARGET_DIR)/usr/pcsx2/bin/
    # use our SDL config
    rm $(TARGET_DIR)/usr/pcsx2/bin/resources/game_controller_db.txt
endef

define PCSX2_TEXTURES
	mkdir -p $(TARGET_DIR)/usr/pcsx2/bin/resources/textures
	cp -pr $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/pcsx2/textures/ \
        $(TARGET_DIR)/usr/pcsx2/bin/resources/
endef

# Download and copy PCSX2 patches.zip to BIOS folder
define PCSX2_PATCHES
    mkdir -p $(TARGET_DIR)/usr/share/batocera/datainit/bios/ps2
    $(HOST_DIR)/bin/curl -L \
        https://github.com/PCSX2/pcsx2_patches/releases/download/latest/patches.zip -o \
        $(TARGET_DIR)/usr/share/batocera/datainit/bios/ps2/patches.zip
endef

PCSX2_POST_INSTALL_TARGET_HOOKS += PCSX2_TEXTURES
PCSX2_POST_INSTALL_TARGET_HOOKS += PCSX2_PATCHES

define PCSX2_CROSSHAIRS
	mkdir -p $(TARGET_DIR)/usr/pcsx2/bin/resources/crosshairs
	cp -pr $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/pcsx2/crosshairs/ \
        $(TARGET_DIR)/usr/pcsx2/bin/resources/
endef

PCSX2_POST_INSTALL_TARGET_HOOKS += PCSX2_CROSSHAIRS

$(eval $(cmake-package))
$(eval $(emulator-info-package))
