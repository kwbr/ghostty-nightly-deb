IMAGE_NAME = ghostty-deb-gen
SOURCE_DIR = $(CURDIR)/source
OUT_DIR    = $(CURDIR)/out
SCRIPT     = build-deb.sh

.PHONY: all build image clean help

all: build

# Podman handles the caching; running this is fast if Dockerfile hasn't changed
image:
	podman build -t $(IMAGE_NAME) .

build: image
	mkdir -p $(SOURCE_DIR) $(OUT_DIR)
	podman run --rm -it \
		-v $(CURDIR)/$(SCRIPT):/usr/local/bin/$(SCRIPT):Z \
		-v $(SOURCE_DIR):/build/source:Z \
		-v $(OUT_DIR):/dist:Z \
		$(IMAGE_NAME) /usr/local/bin/$(SCRIPT)

clean:
	rm -rf $(SOURCE_DIR)

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
