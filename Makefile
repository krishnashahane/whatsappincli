BINARY    := whatsappincli
BUILD_DIR := dist
INSTALL   := /usr/local/bin
VERSION   := 0.5.0
GOFLAGS   := -tags sqlite_fts5
LDFLAGS   := -ldflags "-s -w -X main.version=$(VERSION)"

.PHONY: build install uninstall test test-fts lint fmt-check tidy clean

build:
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=1 go build $(GOFLAGS) -trimpath $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY) ./cmd/whatsappincli
	@echo "Built $(BUILD_DIR)/$(BINARY)"

install: build
	@install -m 0755 $(BUILD_DIR)/$(BINARY) $(INSTALL)/$(BINARY)
	@echo "Installed to $(INSTALL)/$(BINARY)"
	@echo "Run: whatsappincli --help"

uninstall:
	@rm -f $(INSTALL)/$(BINARY)
	@echo "Removed $(INSTALL)/$(BINARY)"

tidy:
	go mod tidy

test:
	go test ./...

test-fts:
	go test $(GOFLAGS) ./...

fmt-check:
	@test -z "$$(gofmt -l .)"

lint: fmt-check
	go vet $(GOFLAGS) ./...

clean:
	rm -rf $(BUILD_DIR)
