# whatsappincli

A terminal-first WhatsApp client built in Go with local SQLite storage, offline search, message/media sending, contact and group management, and history sync.

> Use only with a WhatsApp account you are authorized to link and operate. This project uses the open-source [WhatsMeow](https://github.com/tulir/whatsmeow) library for the WhatsApp Web multi-device protocol.

## What it does

- QR-code authentication and persistent linked-device sessions
- Local message, chat, contact, and group storage
- SQLite FTS5 message search with a LIKE fallback
- Send text messages and common media/document types
- Download received media on demand
- Search contacts and maintain local aliases/tags
- Inspect, rename, join, leave, and manage groups
- Best-effort on-demand history backfill
- Human-readable output or machine-readable JSON
- Single-writer locking to prevent concurrent session/store use

## Requirements

- Go 1.26 or newer
- CGO-enabled build environment
- An active WhatsApp account with a phone capable of linking a companion device

On macOS, install Xcode Command Line Tools. On Linux, install a C compiler such as GCC or Clang.

## Build

Clone the repository and build with the Makefile:

```bash
git clone https://github.com/krishnashahane/whatsappincli.git
cd whatsappincli

go mod tidy
make build
```

The binary is written to `dist/whatsappincli`.

Direct build:

```bash
CGO_ENABLED=1 go build -tags sqlite_fts5 -trimpath -o dist/whatsappincli ./cmd/whatsappincli
```

## First run

Authenticate and bootstrap the local store:

```bash
./dist/whatsappincli auth
```

WhatsApp will display a QR code in the terminal. On your phone, open **Linked Devices** and link the device.

For continuous synchronization:

```bash
./dist/whatsappincli sync --follow
```

Check the installation and local state:

```bash
./dist/whatsappincli doctor
./dist/whatsappincli version
```

## Messages

List recent messages:

```bash
./dist/whatsappincli messages list --limit 50
```

Search locally:

```bash
./dist/whatsappincli messages search "meeting tomorrow"
./dist/whatsappincli messages search "project" --chat 1234567890@s.whatsapp.net --limit 20
```

Inspect one message or its surrounding context:

```bash
./dist/whatsappincli messages show --chat 1234567890@s.whatsapp.net --id MESSAGE_ID
./dist/whatsappincli messages context --chat 1234567890@s.whatsapp.net --id MESSAGE_ID --before 5 --after 5
```

## Sending

Send text:

```bash
./dist/whatsappincli send text \
  --to 1234567890 \
  --message "Hello from the terminal"
```

Send a file:

```bash
./dist/whatsappincli send file \
  --to 1234567890 \
  --file ./photo.jpg \
  --caption "Check this out"
```

The recipient can be a phone number or a full WhatsApp JID such as `1234567890@s.whatsapp.net`.

## Media

Download media stored in the local message index:

```bash
./dist/whatsappincli media download \
  --chat 1234567890@s.whatsapp.net \
  --id MESSAGE_ID
```

Choose a destination file or directory with `--output`.

## Contacts and chats

```bash
./dist/whatsappincli contacts search "alice"
./dist/whatsappincli contacts show --jid 1234567890@s.whatsapp.net
./dist/whatsappincli contacts refresh

./dist/whatsappincli contacts alias set --jid 1234567890@s.whatsapp.net --alias "Alice"
./dist/whatsappincli contacts alias rm --jid 1234567890@s.whatsapp.net

./dist/whatsappincli contacts tags add --jid 1234567890@s.whatsapp.net --tag work
./dist/whatsappincli contacts tags rm --jid 1234567890@s.whatsapp.net --tag work

./dist/whatsappincli chats list
./dist/whatsappincli chats show --jid 1234567890@s.whatsapp.net
```

## Groups

Refresh and list groups:

```bash
./dist/whatsappincli groups refresh
./dist/whatsappincli groups list
```

Manage group information and participants:

```bash
./dist/whatsappincli groups info --jid GROUP_JID
./dist/whatsappincli groups rename --jid GROUP_JID --name "New name"

./dist/whatsappincli groups participants add --jid GROUP_JID --user 1234567890
./dist/whatsappincli groups participants remove --jid GROUP_JID --user 1234567890
./dist/whatsappincli groups participants promote --jid GROUP_JID --user 1234567890
./dist/whatsappincli groups participants demote --jid GROUP_JID --user 1234567890
```

Invite links:

```bash
./dist/whatsappincli groups invite link get --jid GROUP_JID
./dist/whatsappincli groups invite link revoke --jid GROUP_JID
./dist/whatsappincli groups join --code INVITE_CODE
./dist/whatsappincli groups leave --jid GROUP_JID
```

## History backfill

History backfill depends on data already present in the local database:

```bash
./dist/whatsappincli history backfill \
  --chat 1234567890@s.whatsapp.net \
  --count 50 \
  --requests 1
```

It is best-effort because availability and behavior of on-demand history sync depend on WhatsApp and the linked devices.

## Global options

```
--store DIR       Store directory (default: ~/.whatsappincli)
--json            Output JSON
--timeout 5m      Timeout for non-following commands
```

JSON mode is intended for scripts:

```bash
./dist/whatsappincli --json chats list
./dist/whatsappincli --json messages search "release" --limit 10
```

## Data and privacy

By default, whatsappincli stores data under:

```
~/.whatsappincli/
├── session.db         # WhatsApp linked-device session
├── whatsappincli.db   # local message/contact/group index
├── media/             # downloaded media
└── LOCK               # single-writer lock
```

The store directory is created with owner-only permissions. Session and index databases are treated as private local data; back them up carefully and do not commit them to source control.

Logging is intentionally kept low-noise. QR codes and diagnostics are written to the terminal, while JSON results are written to stdout so they can be piped safely.

## Device identity

Optional environment variables:

```bash
export WHATSAPPINCLI_DEVICE_LABEL="whatsappincli"
export WHATSAPPINCLI_DEVICE_PLATFORM="CHROME"
```

The platform value is mapped to the WhatsMeow device platform enum. Unknown values fall back to the default platform.

## Development

Run the complete local checks:

```bash
go mod tidy
make test
make lint
make build
```

The GitHub Actions workflow runs formatting, module consistency, unit tests with and without FTS5, `go vet`, a release-style build, and a CLI smoke test.

## Project layout

```
app/          application and synchronization logic
cmd/          CLI commands
config/       default configuration
lock/         single-writer process lock
out/          JSON output helpers
pathutil/     safe filename/path helpers
store/        SQLite schema and persistence
wa/           WhatsMeow integration
docs/         protocol and release notes
```

## License

MIT
