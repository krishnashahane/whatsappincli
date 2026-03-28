BINARY    := whatsappincli
BUILD_DIR := dist
INSTALL   := /usr/local/bin
VERSION   := 0.5.0
GOFLAGS   := -tags sqlite_fts5
LDFLAGS   := -ldflags "-s -w -X main.version=$(VERSION)"

.PHONY: build install uninstall test lint clean

build:
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=1 go build $(GOFLAGS) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY) ./cmd/whatsappincli
	@echo "Built $(BUILD_DIR)/$(BINARY)"

install: build
	@cp $(BUILD_DIR)/$(BINARY) $(INSTALL)/$(BINARY)
	@chmod +x $(INSTALL)/$(BINARY)
	@echo "Installed to $(INSTALL)/$(BINARY)"
	@echo "Run: whatsappincli --help"

uninstall:
	@rm -f $(INSTALL)/$(BINARY)
	@echo "Removed $(INSTALL)/$(BINARY)"

test:
	go test $(GOFLAGS) ./...

lint:
	go vet ./...
	@gofmt -l . | read && echo "gofmt needed" && exit 1 || true

clean:
	rm -rf $(BUILD_DIR)