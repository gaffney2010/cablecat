PACKAGE_NAME := cablecat-wiki
DEB_NAME := $(PACKAGE_NAME).deb
SRC_DIR := wiki
DEBIAN_DIR := $(SRC_DIR)/debian

.PHONY: all build install uninstall clean

all: build

build:
	@echo "Building package..."
	@cp $(SRC_DIR)/wiki.sh $(DEBIAN_DIR)/usr/bin/$(PACKAGE_NAME)
	@chmod +x $(DEBIAN_DIR)/usr/bin/$(PACKAGE_NAME)
	@dpkg-deb --build $(DEBIAN_DIR) $(DEB_NAME)

install: build
	@echo "Installing dependencies..."
	@sudo apt-get update
	@sudo apt-get install -y pandoc w3m curl jq dpkg
	@echo "Creating cache directory..."
	@sudo mkdir -p /var/cache/cablecat-wiki
	@sudo chmod 777 /var/cache/cablecat-wiki
	@echo "Installing package..."
	@sudo apt-get install -y ./$(DEB_NAME)
	@echo "Installation complete!"

uninstall:
	@echo "Uninstalling package..."
	@sudo apt-get remove -y $(PACKAGE_NAME)
	@echo "Removing cache directory..."
	@sudo rm -rf /var/cache/cablecat-wiki
	@echo "Uninstallation complete."

clean:
	@rm -f $(DEB_NAME)
