# Subdirectories with their own Makefiles
SUBDIRS := wiki lemmy

.PHONY: all build install uninstall reinstall clean $(SUBDIRS)

all: build

build:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir build; \
	done

install:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir install; \
	done
	@sudo cp apps.json /usr/lib/cablecat/
	@sudo cp cablecat /usr/bin

uninstall:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir uninstall; \
	done

reinstall:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir reinstall; \
	done

clean:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
