
all: build

.PHONY: build
build:
	zig build --global-cache-dir ./vendor

.PHONY: build-release
build-release:
	zig build --global-cache-dir ./vendor --release=safe

.PHONY: random-config
random-config:
	$(eval CONFIG_NAME = $(shell mktemp -u XXXXXX))
	./zig-out/bin/i3_news -a $(CONFIG_NAME)
