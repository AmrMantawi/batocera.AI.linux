################################################################################
#
# theforceengine
#
################################################################################

THEFORCEENGINE_VERSION = v1.22.300
THEFORCEENGINE_SITE = https://github.com/luciusDXL/TheForceEngine.git
THEFORCEENGINE_SITE_METHOD=git
THEFORCEENGINE_GIT_SUBMODULES=YES
THEFORCEENGINE_LICENSE = GPLv2
THEFORCEENGINE_LICENSE_FILE = LICENSE

# be sure to update configgen if the patch version changes
THEFORCEENGINE_PATCH_VERSION = v3
THEFORCEENGINE_PATCH_SOURCE = $(THEFORCEENGINE_PATCH_VERSION).zip
# THEFORCEENGINE_EXTRA_DOWNLOADS = \
#     $(addprefix \
#     https://df-21.net/downloads/patches/$(THEFORCEENGINE_PATCH_VERSION)/,\
#     $(THEFORCEENGINE_PATCH_SOURCE))
# Note: Patch download disabled as the original source is no longer available

THEFORCEENGINE_DEPENDENCIES = libglew sdl2 sdl2_image

THEFORCEENGINE_SUPPORTS_IN_SOURCE_BUILD = NO

THEFORCEENGINE_CONF_OPTS += -DCMAKE_BUILD_TYPE=Release
THEFORCEENGINE_CONF_OPTS += -DBUILD_SHARED_LIBS=FALSE
THEFORCEENGINE_CONF_OPTS += -DDISABLE_SYSMIDI=ON
THEFORCEENGINE_CONF_OPTS += -DENABLE_EDITOR=ON

ifeq ($(BR2_PACKAGE_RTMIDI),y)
    THEFORCEENGINE_DEPENDENCIES += rtmidi
    THEFORCEENGINE_CONF_OPTS += -DDISABLE_SYSMIDI=OFF
endif

THEFORCEENGINE_CONF_INIT = $(TARGET_DIR)/usr/share/batocera/datainit/system/configs/theforceengine/

define THEFORCEENGINE_INSTALL_TARGET_CMDS
    mkdir -p $(THEFORCEENGINE_CONF_INIT)
    $(INSTALL) -m 0755 -D $(@D)/buildroot-build/theforceengine \
        $(TARGET_DIR)/usr/bin/theforceengine
    rsync -arv $(@D)/TheForceEngine/Captions $(THEFORCEENGINE_CONF_INIT)
    rsync -arv $(@D)/TheForceEngine/Documentation $(THEFORCEENGINE_CONF_INIT)
    rsync -arv $(@D)/TheForceEngine/Fonts $(THEFORCEENGINE_CONF_INIT)
    rsync -arv $(@D)/TheForceEngine/ExternalData $(THEFORCEENGINE_CONF_INIT)
    rsync -arv --exclude 'CMakeLists.txt' $(@D)/TheForceEngine/Mods $(THEFORCEENGINE_CONF_INIT)
    rsync -arv $(@D)/TheForceEngine/Shaders $(THEFORCEENGINE_CONF_INIT)
    rsync -arv $(@D)/TheForceEngine/SoundFonts $(THEFORCEENGINE_CONF_INIT)
    rsync -arv $(@D)/TheForceEngine/UI_Text $(THEFORCEENGINE_CONF_INIT)
    rsync -arv $(@D)/TheForceEngine/UI_Images $(THEFORCEENGINE_CONF_INIT)
endef

define THEFORCEENGINE_PATCH_ZIP
    mkdir -p $(THEFORCEENGINE_CONF_INIT)/Mods
    # Create a dummy patch file since the original v3.zip is no longer available
    # The patch was likely a game mod that is no longer maintained
    echo "# Dummy patch file - original v3.zip no longer available" > $(THEFORCEENGINE_CONF_INIT)/Mods/v3.zip
endef

define THEFORCEENGINE_EVMAPY
    mkdir -p $(TARGET_DIR)/usr/share/evmapy
    cp $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/ports/theforceengine/theforceengine.keys \
        $(TARGET_DIR)/usr/share/evmapy
endef

THEFORCEENGINE_POST_INSTALL_TARGET_HOOKS += THEFORCEENGINE_PATCH_ZIP
THEFORCEENGINE_POST_INSTALL_TARGET_HOOKS += THEFORCEENGINE_EVMAPY

$(eval $(cmake-package))
