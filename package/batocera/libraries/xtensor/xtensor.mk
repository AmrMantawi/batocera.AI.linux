################################################################################
#
# xtensor
#
################################################################################

XTENSOR_VERSION = 0.27.1
XTENSOR_SOURCE = xtensor-$(XTENSOR_VERSION).tar.gz
XTENSOR_SITE = $(call github,xtensor-stack,xtensor,$(XTENSOR_VERSION))
XTENSOR_LICENSE = BSD-3-Clause
XTENSOR_LICENSE_FILES = LICENSE
XTENSOR_INSTALL_STAGING = YES
XTENSOR_DEPENDENCIES = xtl

# xtensor is a header-only library
XTENSOR_INSTALL_TARGET = NO

# Use CMake for installation but we just need headers
XTENSOR_CONF_OPTS = -DBUILD_TESTS=OFF -DDOWNLOAD_GTEST=OFF

$(eval $(cmake-package))
