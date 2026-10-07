TARGET := iphone:clang:latest:12.0
ARCHS := arm64

INSTALL_TARGET_PROCESSES = ZTech

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = ZTech
ZTech_FILES = $(wildcard Sources/*.m)
ZTech_FRAMEWORKS = UIKit Foundation CoreGraphics Security
ZTech_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ZTech_CODESIGN_FLAGS = -Sentitlements.xml

TWEAK_NAME = ZTechHook
ZTechHook_FILES = Tweak/ZTechHook.m
ZTechHook_FRAMEWORKS = UIKit Foundation
ZTechHook_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ZTechHook_USE_SUBSTRATE = 0

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tweak.mk
