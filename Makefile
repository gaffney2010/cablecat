PACKAGE_NAME := cablecat-wiki
DEB_NAME := $(PACKAGE_NAME).deb
SRC_DIR := wiki
BUILD_DIR := build
STAGE_DIR := $(BUILD_DIR)/stage
# The source directory for debian control files
DEBIAN_SRC_DIR := $(SRC_DIR)/debian

.PHONY: all build install uninstall reinstall clean

all: build

build:
	@echo "Building package..."
	# Clean previous build artifacts
	@rm -rf $(BUILD_DIR)
	
	# Create staging directory structure
	@mkdir -p $(STAGE_DIR)/DEBIAN
	@mkdir -p $(STAGE_DIR)/usr/bin
	@mkdir -p $(STAGE_DIR)/etc/cablecat
	@mkdir -p $(STAGE_DIR)/lib/systemd/system
	@mkdir -p $(STAGE_DIR)/usr/lib/cablecat-wiki
	@mkdir -p $(STAGE_DIR)/usr/lib/cgi-bin

	# Copy Debian control files
	@cp -r $(DEBIAN_SRC_DIR)/DEBIAN/* $(STAGE_DIR)/DEBIAN/
	
	# Copy Maintainer Scripts
	@cp $(SRC_DIR)/postinst $(STAGE_DIR)/DEBIAN/postinst
	@cp $(SRC_DIR)/prerm $(STAGE_DIR)/DEBIAN/prerm
	@chmod 755 $(STAGE_DIR)/DEBIAN/postinst $(STAGE_DIR)/DEBIAN/prerm
	
	# Copy Application Files
	@cp $(SRC_DIR)/wiki.sh $(STAGE_DIR)/usr/bin/$(PACKAGE_NAME)
	@cp $(SRC_DIR)/cablecat-cleanup.sh $(STAGE_DIR)/usr/bin/cablecat-cleanup
	@cp $(SRC_DIR)/cablecat.conf $(STAGE_DIR)/etc/cablecat/cablecat.conf
	@cp $(SRC_DIR)/cablecat-cleanup.service $(STAGE_DIR)/lib/systemd/system/
	@cp $(SRC_DIR)/cablecat-cleanup.timer $(STAGE_DIR)/lib/systemd/system/
	@cp $(SRC_DIR)/wikim.sh $(STAGE_DIR)/usr/bin/cablecat-wikim
	@cp $(SRC_DIR)/wikim_selector.sh $(STAGE_DIR)/usr/bin/cablecat-wikim-selector
	
	# Copy Helper Scripts and CGI
	@cp $(SRC_DIR)/rewrite_links.py $(STAGE_DIR)/usr/lib/cablecat-wiki/rewrite_links.py
	@cp $(SRC_DIR)/wiki-download.sh $(STAGE_DIR)/usr/lib/cablecat-wiki/wiki-download.sh
	@cp $(SRC_DIR)/cablecat_jump.cgi $(STAGE_DIR)/usr/lib/cgi-bin/cablecat_jump.cgi
	
	# Set executable permissions
	@chmod 755 $(STAGE_DIR)/usr/bin/$(PACKAGE_NAME)
	@chmod 755 $(STAGE_DIR)/usr/bin/cablecat-wikim
	@chmod 755 $(STAGE_DIR)/usr/bin/cablecat-wikim-selector
	@chmod 755 $(STAGE_DIR)/usr/bin/cablecat-cleanup
	@chmod 755 $(STAGE_DIR)/usr/lib/cablecat-wiki/rewrite_links.py
	@chmod 755 $(STAGE_DIR)/usr/lib/cablecat-wiki/wiki-download.sh
	@chmod 755 $(STAGE_DIR)/usr/lib/cgi-bin/cablecat_jump.cgi
	
	# Build the .deb package
	@dpkg-deb --build $(STAGE_DIR) $(DEB_NAME)

install: build
	@echo "Installing package..."
	# apt-get install ./package.deb resolves and installs dependencies listed in control file
	@sudo apt-get install -y ./$(DEB_NAME)
	
	@echo "Creating cache directory..."
	@sudo mkdir -p /var/cache/cablecat-wiki
	@sudo chmod 777 /var/cache/cablecat-wiki
	@echo "Installation complete!"

uninstall:
	@echo "Uninstalling package..."
	# Purge removes configuration files as well
	@sudo apt-get purge -y $(PACKAGE_NAME)
	
	@echo "Removing cache directory..."
	@sudo rm -rf /var/cache/cablecat-wiki
	
	@echo "Uninstallation complete. (Run 'sudo apt-get autoremove' to clean up unused dependencies)"

reinstall: uninstall install

clean:
	@echo "Cleaning up..."
	@rm -rf $(BUILD_DIR) $(DEB_NAME)
	# Clean up any legacy artifacts in the source tree
	@rm -rf $(DEBIAN_SRC_DIR)/usr $(DEBIAN_SRC_DIR)/etc $(DEBIAN_SRC_DIR)/lib
