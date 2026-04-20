TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = WeChat
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WeChatTagGroup

WeChatTagGroup_FILES = Tweak.xm
WeChatTagGroup_CFLAGS = -fobjc-arc -w
WeChatTagGroup_FRAMEWORKS = UIKit Foundation
LOGOS_FLAGS += -Wno-missing-end
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 WeChat"
