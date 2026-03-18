.PHONY: build install clean

BUILD_DIR := .build/release
BINARY := $(BUILD_DIR)/cute-hud
INSTALL_DIR := /usr/local/bin

build:
	swift build -c release

install: build
	cp $(BINARY) $(INSTALL_DIR)/cute-hud

clean:
	swift package clean
