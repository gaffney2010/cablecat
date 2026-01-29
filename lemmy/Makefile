PACKAGE_NAME := cablecat-lemmy
CONDA_ENV := cablecat-lemmy
BUILD_DIR := dist
SPEC_FILE := $(PACKAGE_NAME).spec

# Use bash for shell commands
SHELL := /bin/bash

.PHONY: all build install uninstall reinstall clean

all: build

build:
	@echo "Building $(PACKAGE_NAME) with pyinstaller..."
	source $$(conda info --base)/etc/profile.d/conda.sh && \
		conda activate $(CONDA_ENV) && \
		uv sync && \
		uv run pyinstaller --onefile --name $(PACKAGE_NAME) \
			--collect-data rich \
			--collect-submodules rich._unicode_data \
			lemmy_tui.py && \
		conda deactivate

install: build
	@echo "Installing $(PACKAGE_NAME)..."
	sudo install -m 755 $(BUILD_DIR)/$(PACKAGE_NAME) /usr/bin/$(PACKAGE_NAME)
	@echo "Installation complete!"

uninstall:
	@echo "Uninstalling $(PACKAGE_NAME)..."
	sudo rm -f /usr/bin/$(PACKAGE_NAME)
	@echo "Uninstallation complete!"

reinstall: uninstall install

clean:
	@echo "Cleaning $(PACKAGE_NAME)..."
	rm -rf $(BUILD_DIR) build $(SPEC_FILE)
