
all: build run
.PHONY: build
build:
	zig build --global-cache-dir ./vendor

.PHONY: random-config
random-config:
	$(eval CONFIG_NAME = $(shell mktemp -u XXXXXX))
	./zig-out/bin/i3_news -a $(CONFIG_NAME)

