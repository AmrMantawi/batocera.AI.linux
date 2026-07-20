################################################################################
#
# fex-emu
#
################################################################################

FEX_EMU_VERSION = FEX-2604
FEX_EMU_SITE = https://github.com/FEX-Emu/FEX
FEX_EMU_SITE_METHOD = git
FEX_EMU_GIT_SUBMODULES = YES
FEX_EMU_LICENSE = MIT
FEX_EMU_LICENSE_FILES = LICENSE
FEX_EMU_DEPENDENCIES = host-clang host-python3

# FEX rejects GCC outright, it requires Clang (>= 13) to build.
FEX_EMU_CONF_OPTS += -DCMAKE_C_COMPILER=$(HOST_DIR)/bin/clang
FEX_EMU_CONF_OPTS += -DCMAKE_CXX_COMPILER=$(HOST_DIR)/bin/clang++
FEX_EMU_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
FEX_EMU_CONF_OPTS += -DBUILD_TESTING=False
FEX_EMU_CONF_OPTS += -DBUILD_THUNKS=False
FEX_EMU_CONF_OPTS += -DENABLE_LTO=False

define FEX_EMU_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/Bin/FEXInterpreter $(TARGET_DIR)/usr/bin/FEXInterpreter
	$(INSTALL) -D -m 0755 $(@D)/Bin/FEXServer $(TARGET_DIR)/usr/bin/FEXServer
	$(INSTALL) -D -m 0755 $(@D)/Bin/FEXBash $(TARGET_DIR)/usr/bin/FEXBash
	$(INSTALL) -D -m 0755 $(@D)/Bin/FEXConfig $(TARGET_DIR)/usr/bin/FEXConfig
	$(INSTALL) -D -m 0755 $(@D)/Bin/FEXGetConfig $(TARGET_DIR)/usr/bin/FEXGetConfig
	$(INSTALL) -D -m 0755 $(@D)/Bin/FEXRootFSFetcher $(TARGET_DIR)/usr/bin/FEXRootFSFetcher
	mkdir -p $(TARGET_DIR)/etc/init.d
	$(INSTALL) -m 0755 $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/utils/fex-emu/fex-binfmt.init \
	    $(TARGET_DIR)/etc/init.d/S28fex-emu
endef

$(eval $(cmake-package))
