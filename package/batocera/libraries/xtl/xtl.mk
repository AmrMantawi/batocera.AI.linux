################################################################################
#
# xtl
#
################################################################################

XTL_VERSION = 0.8.0
XTL_SOURCE = xtl-$(XTL_VERSION).tar.gz
XTL_SITE = $(call github,xtensor-stack,xtl,$(XTL_VERSION))
XTL_LICENSE = BSD-3-Clause
XTL_LICENSE_FILES = LICENSE
XTL_INSTALL_STAGING = YES

# xtl is a header-only library
XTL_INSTALL_TARGET = NO

# Use CMake for installation but we just need headers
XTL_CONF_OPTS = -DBUILD_TESTS=OFF -DDOWNLOAD_GTEST=OFF

$(eval $(cmake-package))
