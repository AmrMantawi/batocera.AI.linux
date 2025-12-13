################################################################################
#
# rknpu-driver
#
################################################################################

RKNPU_DRIVER_VERSION = 0.9.8_20241009
RKNPU_DRIVER_SOURCE = rknpu_driver_$(RKNPU_DRIVER_VERSION).tar.bz2
RKNPU_DRIVER_SITE = https://github.com/airockchip/rknn-llm/raw/main/rknpu-driver

RKNPU_DRIVER_LICENSE = GPL-2.0
RKNPU_DRIVER_LICENSE_FILES = COPYING

RKNPU_DRIVER_DEPENDENCIES = linux

# The source archive contains kernel driver source code
RKNPU_DRIVER_MODULE_SUBDIRS = rknpu

RKNPU_DRIVER_MODULE_MAKE_OPTS = \
	USER_EXTRA_CFLAGS="-DCONFIG_$(call qstrip,$(BR2_ENDIAN))_ENDIAN \
		-Wno-error"

$(eval $(kernel-module))
$(eval $(generic-package))
