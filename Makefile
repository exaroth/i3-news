
all: build

.PHONY: build
build:
	zig build --global-cache-dir ./vendor

# TODO: --release=safe  seems to break sqlite
.PHONY: build-release
build-release:
	zig build --global-cache-dir ./vendor -Dtarget=x86_64-linux-musl


.PHONY: random-config
random-config:
	$(eval CONFIG_NAME = $(shell mktemp -u XXXXXX))
	./zig-out/bin/i3_news -a $(CONFIG_NAME)

.PHONY: build-appimage
build-appimage:
	./scripts/buildappimage.sh


