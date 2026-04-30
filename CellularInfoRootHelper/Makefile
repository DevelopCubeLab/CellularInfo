TARGET := iphone:clang:latest:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = CellularInfoRootHelper

CellularInfoRootHelper_FILES = main.m
CellularInfoRootHelper_CFLAGS = -fobjc-arc
CellularInfoRootHelper_CODESIGN_FLAGS = -Sentitlements.plist
CellularInfoRootHelper_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk

after-stage::
	@echo "Copying file to parent directory..."
	cp $(THEOS_STAGING_DIR)/usr/local/bin/$(TOOL_NAME) ../$(TOOL_NAME)/
	@echo "Copy completed."
