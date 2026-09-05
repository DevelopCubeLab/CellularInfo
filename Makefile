ARCHS := arm64
TARGET := iphone:clang:latest:12.0

INSTALL_TARGET_PROCESSES = CellularInfo

include $(THEOS)/makefiles/common.mk

# 记录构建开始时间
before-all::
	@date +%s > $(CURDIR)/.build_start

# 使用 Xcode 项目构建
XCODEPROJ_NAME = CellularInfo
BUILD_VERSION = "1.1"
FILE_NAME = "com.developlab.cellularinfo"

# 指定 Theos 使用 xcodeproj 规则
include $(THEOS_MAKE_PATH)/xcodeproj.mk

# 编译RootHelper
SUBPROJECTS += CellularInfoRootHelper
include $(THEOS_MAKE_PATH)/aggregate.mk

# 保存dSYM用于闪退分析
after-stage::
	@echo -e "\033[32mCollecting dSYM...\033[0m"; \
	APP_PATH="$(THEOS_STAGING_DIR)/Applications/$(XCODEPROJ_NAME).app"; \
	DSYM_SRC="$$(find ~/Library/Developer/Xcode/DerivedData -name "$(XCODEPROJ_NAME).app.dSYM" | head -n 1)"; \
	if [ -d "$$DSYM_SRC" ]; then \
		mkdir -p $(CURDIR)/packages; \
		DSYM_DST="$(CURDIR)/packages/$(FILE_NAME)_$(BUILD_VERSION).dSYM"; \
		rm -rf "$$DSYM_DST"; \
		cp -R "$$DSYM_SRC" "$$DSYM_DST"; \
	    echo -e "\033[32mdSYM copied to ./packages as $$(basename "$$DSYM_DST") \033[0m"; \
	else \
		echo "No dSYM found in DerivedData"; \
	fi
	@echo -e "\033[32mRemoving *.bundle folder...解决ldid签名提示错误"
	@rm -rf $(THEOS_STAGING_DIR)/Applications/CellularInfo.app/*.bundle

# 在打包阶段用ldid签名赋予权力，顺便删除_CodeSignature
before-package::
	
	@if [ -f $(THEOS_STAGING_DIR)/Applications/$(XCODEPROJ_NAME).app/Info.plist ]; then \
		echo -e "\033[32mSigning with ldid...\033[0m"; \
		ldid -Sentitlements.plist $(THEOS_STAGING_DIR)/Applications/$(XCODEPROJ_NAME).app; \
	else \
		@echo -e "\033[31mNo Info.plist found. Skipping ldid signing.\033[0m"; \
	fi
	@echo -e "\033[32mRemoving _CodeSignature folder..."
	@rm -rf $(THEOS_STAGING_DIR)/Applications/$(XCODEPROJ_NAME).app/_CodeSignature
	@rm -rf $(THEOS_STAGING_DIR)/Applications/$(XCODEPROJ_NAME).app/PlugIns/TrollSIMSwitcherWidgetExtension.appex/_CodeSignature
#	@echo -e "\033[32mRemoving Frameworks folder..."
#	@rm -rf $(THEOS_STAGING_DIR)/Applications/$(XCODEPROJ_NAME).app/Frameworks
#	@echo -e "\033[32mCopy RootHelper to package..."
	# 这里必须要手动复制RootHelper到包内，不要放到Xcode工程目录下，不然就无法运行二进制文件
	@cp -f CellularInfoRootHelper/CellularInfoRootHelper $(THEOS_STAGING_DIR)/Applications/$(XCODEPROJ_NAME).app/
	
# 打包完成后重命名为 .tipa
after-package::
	@echo "Renaming .ipa to .tipa..."
	@if [ -f ./packages/$(FILE_NAME)_$(BUILD_VERSION)+debug.ipa ]; then \
		mv ./packages/$(FILE_NAME)_$(BUILD_VERSION)+debug.ipa ./packages/$(FILE_NAME)_$(BUILD_VERSION)+debug.tipa; \
		echo "Renamed debug ipa to tipa."; \
	elif [ -f ./packages/$(FILE_NAME)_$(BUILD_VERSION).ipa ]; then \
		mv ./packages/$(FILE_NAME)_$(BUILD_VERSION).ipa ./packages/$(FILE_NAME)_$(BUILD_VERSION).tipa; \
		echo "Renamed release ipa to tipa."; \
	else \
		echo "No .ipa file found."; \
	fi
	
	@START=$$(cat $(CURDIR)/.build_start 2>/dev/null || date +%s); \
	 END=$$(date +%s); \
	 DURATION=$$((END - START)); \
	 echo "构建+打包耗时：$$DURATION 秒"; \
	 rm -f $(CURDIR)/.build_start
