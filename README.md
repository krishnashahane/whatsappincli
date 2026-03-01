# whatsappincli

A WhatsApp client that runs entirely in your terminal. Sync messages locally, search them offline with full-text search, send messages, manage groups and contacts — all from the command line.

## Features

- **QR-based authentication** — scan once from your phone, stays logged in
- **Local message sync** — messages stored in SQLite, accessible offline
- **Full-text search** — FTS5-powered instant message search across all chats
- **Send text & files** — send messages and media from your terminal
- **Contact management** — view contacts, set local aliases and tags
- **Group management** — list, inspect, rename, invite, join/leave groups
- **History backfill** — request older messages from your phone (best-effort)
- **Media download** — download images, videos, documents on demand
- **JSON output** — pipe-friendly `--json` flag for scripting

## Requirements

- Go 1.23+ (for building from source)
- A WhatsApp account with an active phone

## Install

```bash
git clone <your-repo-url>
cd whatsappincli
make build
```

Or with Go directly:

```bash
go build -tags sqlite_fts5 -o whatsappincli ./cmd/whatsappincli
```

To install system-wide:

```bash
make install
```

## Quick Start

### 1. Authenticate

```bash
./whatsappincli auth
```

This shows a QR code in your terminal. Scan it with WhatsApp on your phone (Settings > Linked Devices > Link a Device). After pairing, it automatically starts syncing your messages.

### 2. Sync messages

```bash
# One-time sync
./whatsappincli sync --once

# Keep running and sync continuously
./whatsappincli sync --follow
```

### 3. Search messages

```bash
./whatsappincli messages search "meeting tomorrow"
./whatsappincli messages search "project" --chat 1234567890@s.whatsapp.net --limit 20
```

### 4. Send a message

```bash
./whatsappincli send text --to 1234567890 --message "Hello from the terminal!"
./whatsappincli send file --to 1234567890 --file ./photo.jpg --caption "Check this out"
```

## All Commands

| Command | Description |
|---------|-------------|
| `auth` | Authenticate via QR code and bootstrap initial sync |
| `auth status` | Check authentication status |
| `auth logout` | Log out and clear session |
| `sync` | Sync messages (non-interactive, no QR) |
| `messages list` | List messages with filters |
| `messages search <query>` | Full-text search across messages |
| `messages show` | Show a specific message |
| `messages context` | Show messages around a specific message |
| `send text` | Send a text message |
| `send file` | Send a file/image/video/document |
| `contacts search <query>` | Search contacts |
| `contacts show` | Show contact details |
| `contacts refresh` | Refresh contacts from WhatsApp |
| `contacts alias set/rm` | Set or remove a local alias |
| `contacts tags add/rm` | Add or remove tags on contacts |
| `chats list` | List all chats |
| `chats show` | Show chat details |
| `groups list` | List joined groups |
| `groups info` | Show group details |
| `groups rename` | Rename a group |
| `groups refresh` | Refresh group list from WhatsApp |
| `groups participants add/remove/promote/demote` | Manage group members |
| `groups invite link get/revoke` | Get or revoke invite link |
| `groups join` | Join a group via invite code |
| `groups leave` | Leave a group |
| `history backfill` | Request older messages from phone |
| `media download` | Download media from messages |
| `doctor` | Run diagnostics on store/auth/search |
| `version` | Print version |

## Global Flags

```
--store DIR       Store directory (default: ~/.whatsappincli)
--json            Output JSON instead of human-readable text
--timeout 5m      Command timeout for non-sync commands
```

## How It Works

1. **Authentication**: `whatsappincli auth` connects to WhatsApp Web servers and shows a QR code. Your phone links this as a companion device.

2. **Message storage**: Messages are stored in a local SQLite database at `~/.whatsappincli/whatsappincli.db`. The WhatsApp session lives in `~/.whatsappincli/session.db`.

3. **Search**: Uses SQLite FTS5 for fast full-text search. Falls back to LIKE queries if FTS5 is not available (slower but still works).

4. **Sync**: Captures messages via WhatsApp Web protocol event handlers — both real-time messages and history sync batches.

5. **Locking**: Only one instance can access the store at a time (file lock prevents session conflicts that cause "device replaced" errors).

## Environment Variables

| Variable | Description |
|----------|-------------|
| `WHATSAPPINCLI_DEVICE_LABEL` | Custom device label shown in WhatsApp linked devices |
| `WHATSAPPINCLI_DEVICE_PLATFORM` | Platform type (e.g., `CHROME`, `FIREFOX`, `SAFARI`) |

## Data Storage

All data is stored in `~/.whatsappincli/` by default:

```
~/.whatsappincli/
  session.db         # WhatsApp session (encryption keys, device identity)
  whatsappincli.db   # Messages, chats, contacts, groups (+ FTS index)
  media/             # Downloaded media files
  LOCK               # Prevents concurrent access
```

## License

MIT
