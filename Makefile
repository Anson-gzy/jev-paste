APP_NAME = jev-paste
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources

SWIFT_SOURCES = \
	Sources/Core/Models.swift \
	Sources/Core/KeychainHelper.swift \
	Sources/Core/LocalizationManager.swift \
	Sources/Core/SmartPasteBridge.swift \
	Sources/Core/LocalHeuristicEngine.swift \
	Sources/Core/TypeSafeClient.swift \
	Sources/Services/ClipboardHistoryManager.swift \
	Sources/Services/ClipboardMonitor.swift \
	Sources/Services/PasteSimulator.swift \
	Sources/Services/GlobalHotkeyManager.swift \
	Sources/Services/AXFocusMonitor.swift \
	Sources/Services/TabKeyInterceptor.swift \
	Sources/Services/SmartPasteCoordinator.swift \
	Sources/Services/UpdateChecker.swift \
	Sources/UI/GhostOverlayController.swift \
	Sources/UI/MainWindowView.swift \
	Sources/UI/MainWindowController.swift \
	Sources/UI/SmartPasteHUDView.swift \
	Sources/UI/SettingsView.swift \
	Sources/UI/HUDWindowController.swift \
	Sources/UI/AppDelegate.swift \
	Sources/main.swift

TEST_SOURCES = \
	Sources/Core/Models.swift \
	Sources/Core/KeychainHelper.swift \
	Sources/Core/LocalizationManager.swift \
	Sources/Core/SmartPasteBridge.swift \
	Sources/Core/LocalHeuristicEngine.swift \
	Sources/Core/TypeSafeClient.swift \
	Sources/Services/ClipboardHistoryManager.swift \
	Sources/Services/ClipboardMonitor.swift \
	Sources/Services/PasteSimulator.swift \
	Sources/Services/GlobalHotkeyManager.swift \
	Sources/Services/AXFocusMonitor.swift \
	Sources/Services/TabKeyInterceptor.swift \
	Sources/Services/SmartPasteCoordinator.swift \
	Sources/UI/GhostOverlayController.swift \
	Tests/CoreTests.swift

SWIFTC_FLAGS = -O -parse-as-library -framework Cocoa -framework SwiftUI -framework Carbon -framework JavaScriptCore -framework Security

.PHONY: all build test cli run clean

all: build

test:
	@mkdir -p $(BUILD_DIR)
	@echo "==> Compiling CoreTests..."
	@swiftc $(SWIFTC_FLAGS) -I Sources/Core $(TEST_SOURCES) -o $(BUILD_DIR)/CoreTests
	@echo "==> Running CoreTests..."
	@$(BUILD_DIR)/CoreTests

cli:
	@mkdir -p $(BUILD_DIR)
	@echo "==> Compiling $(APP_NAME) CLI..."
	@swiftc $(SWIFTC_FLAGS) $(SWIFT_SOURCES) -o $(BUILD_DIR)/$(APP_NAME)CLI
	@echo "==> Running CLI Inspection..."
	@$(BUILD_DIR)/$(APP_NAME)CLI --test

build:
	@echo "==> Building $(APP_NAME).app..."
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(MACOS) $(RESOURCES)
	@swiftc $(SWIFTC_FLAGS) $(SWIFT_SOURCES) -o $(MACOS)/$(APP_NAME)
	@cp Resources/Info.plist $(CONTENTS)/Info.plist
	@cp Resources/core.js $(RESOURCES)/core.js
	@if [ -d demo ]; then cp -r demo $(RESOURCES)/demo; fi
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(RESOURCES)/AppIcon.icns; fi
	@echo "==> Ad-hoc signing $(APP_BUNDLE) with stable designated requirement..."
	@codesign --force --deep --sign - --requirements '=designated => identifier "ai.typesafe.jev-paste"' $(APP_BUNDLE)
	@echo "✅ Successfully built $(APP_BUNDLE)"

run: build
	@echo "==> Launching $(APP_BUNDLE)..."
	@open $(APP_BUNDLE)

install: build
	@echo "==> Installing $(APP_NAME).app to /Applications/..."
	@killall $(APP_NAME) 2>/dev/null || true
	@rm -rf /Applications/$(APP_NAME).app
	@cp -R $(APP_BUNDLE) /Applications/$(APP_NAME).app
	@echo "==> Launching /Applications/$(APP_NAME).app..."
	@open /Applications/$(APP_NAME).app
	@echo "✅ Successfully installed and launched /Applications/$(APP_NAME).app"

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory."
