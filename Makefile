PWD := $(shell pwd)
UID := $(shell id -u)
GID := $(shell id -g)

OPENWRT_VERSION ?= v25.12.4
OPENWRT_REPO ?= https://github.com/openwrt/openwrt.git

IMAGE := p1-build-system:latest
CONTAINER := p1-build
OPENWRT_DIR := /home/builder/openwrt
CACHE_DIR := $(PWD)/.cache

CONFIGS ?= configs/mt7981.config
MAKE_JOBS ?= $(shell nproc)
MAKE_OPTS ?= V=s

.PHONY: build-system firmware shell clean

build-system:
	docker buildx build \
		-t $(IMAGE) \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		. --load

openwrt-src/.git:
	git clone $(OPENWRT_REPO) --branch $(OPENWRT_VERSION) openwrt-src

firmware: openwrt-src/.git
	mkdir -p $(CACHE_DIR)/dl $(CACHE_DIR)/build_dir $(CACHE_DIR)/staging_dir $(CACHE_DIR)/feeds $(CACHE_DIR)/logs $(CACHE_DIR)/ccache output custom
	docker run --rm \
		--name $(CONTAINER) \
		-v $(PWD)/openwrt-src:/opt/openwrt-src:ro \
		-v $(PWD)/build.sh:/home/builder/build.sh:ro \
		-v $(PWD)/configs:/opt/configs:ro \
		-v $(PWD)/custom:/opt/custom:ro \
		-v $(PWD)/output:/home/builder/output \
		-v $(CACHE_DIR)/dl:$(OPENWRT_DIR)/dl \
		-v $(CACHE_DIR)/feeds:$(OPENWRT_DIR)/feeds \
		-v $(CACHE_DIR)/logs:$(OPENWRT_DIR)/logs \
		-v $(CACHE_DIR)/build_dir:$(OPENWRT_DIR)/build_dir \
		-v $(CACHE_DIR)/staging_dir:$(OPENWRT_DIR)/staging_dir \
		-v $(CACHE_DIR)/ccache:/home/builder/.ccache \
		-e MAKE_JOBS=$(MAKE_JOBS) \
		-e MAKE_OPTS="$(MAKE_OPTS)" \
		-e CCACHE_DIR=/home/builder/.ccache \
		$(IMAGE) \
		./build.sh build $(CONFIGS)

shell: openwrt-src/.git
	mkdir -p $(CACHE_DIR)/dl $(CACHE_DIR)/build_dir $(CACHE_DIR)/staging_dir $(CACHE_DIR)/feeds $(CACHE_DIR)/logs $(CACHE_DIR)/ccache output custom
	docker run --rm -it \
		--name $(CONTAINER)-shell \
		-v $(PWD)/openwrt-src:/opt/openwrt-src:ro \
		-v $(PWD)/build.sh:/home/builder/build.sh:ro \
		-v $(PWD)/configs:/opt/configs:ro \
		-v $(PWD)/custom:/opt/custom:ro \
		-v $(PWD)/output:/home/builder/output \
		-v $(CACHE_DIR)/dl:$(OPENWRT_DIR)/dl \
		-v $(CACHE_DIR)/feeds:$(OPENWRT_DIR)/feeds \
		-v $(CACHE_DIR)/logs:$(OPENWRT_DIR)/logs \
		-v $(CACHE_DIR)/build_dir:$(OPENWRT_DIR)/build_dir \
		-v $(CACHE_DIR)/staging_dir:$(OPENWRT_DIR)/staging_dir \
		-v $(CACHE_DIR)/ccache:/home/builder/.ccache \
		-e CCACHE_DIR=/home/builder/.ccache \
		$(IMAGE) \
		bash

clean:
	rm -rf $(CACHE_DIR)/build_dir $(CACHE_DIR)/staging_dir