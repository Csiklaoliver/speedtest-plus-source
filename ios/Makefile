ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:12.0
INSTALL_TARGET_PROCESSES = SpeedTest

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SpeedtestPlus
SpeedtestPlus_FILES = \
	Sources/Tweak.xm \
	Sources/SPState.m \
	Sources/SPCurve.m \
	Sources/SPTheme.m \
	Sources/SPControlsViewController.m \
	Sources/SPShareBuilder.m \
	Sources/SPUpdater.m
SpeedtestPlus_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter
SpeedtestPlus_FRAMEWORKS = UIKit Foundation QuartzCore Security

include $(THEOS_MAKE_PATH)/tweak.mk
