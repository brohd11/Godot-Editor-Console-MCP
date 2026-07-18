BINARY    := godot-editor-console-mcp
BUILD     := build
DIST      := dist
VERSION   ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS   := -s -w -X main.version=$(VERSION)
PLATFORMS := darwin/arm64 darwin/amd64 linux/amd64 linux/arm64 windows/amd64

.PHONY: build all clean package $(PLATFORMS)

# Host build -> build/<host-os>-<host-arch>/godot-editor-console-mcp
build:
	go build -ldflags '$(LDFLAGS)' \
	  -o $(BUILD)/$(shell go env GOOS)-$(shell go env GOARCH)/$(BINARY) .

# Cross-compile every target in one shot
all: $(PLATFORMS)

$(PLATFORMS):
	@os=$(word 1,$(subst /, ,$@)); arch=$(word 2,$(subst /, ,$@)); \
	ext=$$( [ "$$os" = "windows" ] && echo .exe || echo ); \
	echo "building $$os/$$arch"; \
	GOOS=$$os GOARCH=$$arch CGO_ENABLED=0 \
	  go build -ldflags '$(LDFLAGS)' \
	  -o $(BUILD)/$$os-$$arch/$(BINARY)$$ext .

# Build all targets, then archive each into dist/ for a GitHub release. Keeping
# artifacts out of build/ leaves that holding only intermediates, and lets the
# release workflow upload a clean dist/* glob.
#
# Names are deliberately version-less so install.sh can use GitHub's
# /releases/latest/download/<name> redirect and skip the API (no JSON parsing,
# no unauthenticated rate limit). The release tag carries the version, and the
# binary reports its own via `godot-editor-console-mcp version`.
#
# zip on every platform, matching gdaddon and repoview -- one format across all
# three repos, so the shared installer body only ever exercises one path here.
# Archives are flat: a single bare executable at the root, which is what the
# installer's `[ -f "$$tmp/$$BINARY" ]` check expects.
package: all
	@mkdir -p $(DIST); \
	for p in $(PLATFORMS); do \
	  os=$${p%/*}; arch=$${p#*/}; \
	  ext=$$( [ "$$os" = "windows" ] && echo .exe || echo ); \
	  name=$(BINARY)-$$os-$$arch.zip; \
	  echo "packaging $$name"; \
	  rm -f $(DIST)/$$name; \
	  ( cd $(BUILD)/$$os-$$arch && zip -j -q ../../$(DIST)/$$name $(BINARY)$$ext ); \
	done; \
	echo "done -> $(DIST)/"

clean:
	rm -rf $(BUILD) $(DIST)
