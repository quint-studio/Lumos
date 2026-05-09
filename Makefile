APP_PATH := $(shell xcodebuild -project Lumos.xcodeproj -scheme Lumos -configuration Debug -showBuildSettings 2>/dev/null | grep '^\s*BUILT_PRODUCTS_DIR' | head -1 | sed 's/.*= //')

.PHONY: setup generate build run open clean

setup:
	@which xcodegen > /dev/null || brew install xcodegen
	$(MAKE) generate

generate:
	xcodegen generate

build: generate
	xcodebuild -project Lumos.xcodeproj -scheme Lumos -configuration Debug build | xcpretty || xcodebuild -project Lumos.xcodeproj -scheme Lumos -configuration Debug build

run: build
	open "$(APP_PATH)/Lumos.app"

open: generate
	open Lumos.xcodeproj

clean:
	rm -rf Lumos.xcodeproj
	xcodebuild clean -project Lumos.xcodeproj -scheme Lumos 2>/dev/null || true
