# whatsappincli specification (plan)

This document defines the v1 plan for `whatsappincli`: a WhatsApp CLI that syncs messages locally, supports fast search, sending, and contact/group management.

## Goals

- **Explicit authentication step**: `whatsappincli auth` shows a QR code and completes login.
- **Auth starts syncing immediately**: after successful QR pairing, `whatsappincli auth` begins initial sync (history + metadata).
- **Non-interactive sync**: `whatsappincli sync` never displays a QR code; it fails with a clear error if not authenticated.
- **Fast offline message search**: local SQLite + FTS5 index.
- **Human-first output**: readable tables by default, `--json` opt-in for scripting.
- **Single-instance safety**: store locking to avoid multi-instance session conflicts (device/session replacement issues).
- **Group management**: list groups, inspect, rename, manage participants, invites.

## Non-goals (v1)

- Guaranteed full-history export (WhatsApp/WhatsApp Web history is best-effort).
- End-to-end “contact creation” in WhatsApp (we can manage local aliases/notes; WhatsApp contacts are sourced from the account/device).
- Full message-type parity (polls, reactions, ephemeral nuances, etc.) in v1.

## Terminology

- **JID**: WhatsApp Jabber ID, e.g. `1234567890@s.whatsapp.net` (user) or `123456789@g.us` (group).
- **Store directory**: directory containing all local state, default `~/.whatsappincli`.

## Storage layout

Default store: `~/.whatsappincli` (override with `--store DIR`).

Proposed files:

- `~/.whatsappincli/session.db` — WhatsApp session store (device identity, keys, app-state).
- `~/.whatsappincli/whatsappincli.db` — our SQLite DB (messages/chats, FTS, local metadata).
- `~/.whatsappincli/media/...` — downloaded media (optional, on-demand or background).
- `~/.whatsappincli/LOCK` — store lock to prevent concurrent access.

Rationale for two SQLite files: reduce coupling and keep the session schema separate from `whatsappincli`’s local schema. It’s still “one store directory” for the user.

## Concurrency + locking

Every command that accesses the WhatsApp session must acquire an exclusive lock in the store dir.

Behavior:

- If lock is held: fail fast with a clear message (include PID and start time if available).
- This prevents running multiple `whatsappincli` instances against the same WhatsApp device identity, which can cause disconnects or “device replaced” style failures.

## Authentication model

### Commands

- `whatsappincli auth` (interactive)
  - If not authenticated: connect, show QR code, wait for success.
  - After success: start initial sync (bootstrap) immediately.
  - Exits after initial sync “goes idle” (configurable), unless `--follow` is set.

- `whatsappincli sync` (non-interactive)
  - Requires an existing authenticated session in `session.db`.
  - Never displays QR; if not authenticated, prints “run `whatsappincli auth`”.
  - `--once` performs a bounded sync and exits.
  - Default (or `--follow`) stays connected and continues capturing messages.

### UX principle

Only `whatsappincli auth` is expected to show a QR code. `whatsappincli sync` should be safe to run in scripts/daemons without surprising interactivity.

## Sync model (best-effort)

`whatsappincli` captures messages via WhatsApp Web protocol event handlers:

- `events.HistorySync`: initial/batch history sync delivered by WhatsApp Web.
- `events.Message`: new incoming/outgoing messages while connected.
- Connection lifecycle events (`Connected`, `Disconnected`) for logging/reconnect.

### Bootstrap sync (after auth)

Immediately after QR pairing success, `whatsappincli auth` runs a bootstrap sync:

- Processes history sync events and stores message metadata.
- Updates chats, names, and contact-derived names as available.
- Optionally starts media download worker (off by default, behind a flag).
- Exits once “idle for N seconds” (no new history events) unless `--follow`.

### Continuous sync

`whatsappincli sync --follow` keeps running:

- persists new messages as they arrive
- performs safe reconnect with backoff on disconnect
- continues best-effort history catch-up when WhatsApp emits it

## Database schema (whatsappincli.db)

### Tables (proposed)

- `chats`
  - `jid` (PK), `name`, `kind` (`dm|group|broadcast`), `last_message_ts`, …
- `contacts`
  - `jid` (PK), `push_name`, `full_name`, `business_name`, `phone`, …
- `groups`
  - `jid` (PK), `name`, `owner_jid`, `created_ts`, …
- `messages`
  - `rowid` (PK), `chat_jid`, `msg_id`, `sender_jid`, `ts`, `from_me`, `text`, `media_type`, `media_caption`, `filename`, `mime_type`, `direct_path`, hashes/keys, …
  - unique constraint: (`chat_jid`, `msg_id`)
- `contact_aliases` (local management)
  - `jid` (PK/FK), `alias`, `notes`, `tags` (or join table)

### Message search (FTS5)

Use SQLite **FTS5** for fast full-text search.

Approach:

- Maintain canonical data in `messages`.
- Maintain an FTS5 virtual table `messages_fts` (external content) indexing:
  - message body text
  - media caption
  - document filename
  - (optionally) denormalized sender/chat names for convenience

Query behavior:

- Default: `MATCH` queries (FTS syntax) with ranking via `bm25`.
- Filters implemented in SQL: `--chat`, `--from`, `--after`, `--before`, `--has-media`, `--type`.
- Human output includes snippets/highlights; `--json` returns structured matches + offsets/snippet string.

Fallback:

- If FTS5 is unavailable, fall back to `LIKE` with an explicit warning (slower).

## CLI command surface (v1)

Global flags:

- `--store DIR` (default `~/.whatsappincli`)
- `--json` (default: human text)
- `--timeout DURATION` (non-sync commands; e.g. `5m`)
- `--version` (prints version and exits)

### Doctor

- `whatsappincli doctor [--connect]`

### Auth

- `whatsappincli auth [--follow] [--idle-exit 30s]`
- `whatsappincli auth status`
- `whatsappincli auth logout`

### Sync

- `whatsappincli sync [--once] [--follow] [--download-media]`

Notes:

- `sync` errors if not authenticated (never prints QR).
- `--download-media` runs a bounded/concurrent media downloader for messages that contain downloadable media metadata.

### History backfill (best-effort)

WhatsApp Web history is best-effort. If you want to try fetching *older* messages for a specific chat, `whatsappincli` can send an on-demand history request to your primary device:

- `whatsappincli history backfill --chat JID [--count 50] [--requests N]`

### Messages

- `whatsappincli messages list [--chat JID] [--limit N] [--before TS] [--after TS]`
- `whatsappincli messages search <query> [--chat JID] [--from JID] [--limit N] [--before TS] [--after TS] [--type text|image|video|audio|document]`
- `whatsappincli messages show --chat JID --id MSG_ID`
- `whatsappincli messages context --chat JID --id MSG_ID [--before N] [--after N]`

### Send

- `whatsappincli send text --to PHONE_OR_JID --message TEXT`
- `whatsappincli send file --to PHONE_OR_JID --file PATH [--caption TEXT] [--mime TYPE]`

### Contacts (read + local management)

- `whatsappincli contacts search <query>`
- `whatsappincli contacts show --jid JID`
- `whatsappincli contacts refresh`
- `whatsappincli contacts alias set --jid JID --alias "Name"`
- `whatsappincli contacts alias rm --jid JID`
- `whatsappincli contacts tags add|rm --jid JID --tag TAG`

### Chats

- `whatsappincli chats list [--query TEXT]`
- `whatsappincli chats show --jid JID`

### Groups

- `whatsappincli groups list [--query TEXT]`
- `whatsappincli groups refresh`
- `whatsappincli groups info --jid GROUP_JID`
- `whatsappincli groups rename --jid GROUP_JID --name "New Name"`
- `whatsappincli groups participants add|remove --jid GROUP_JID --user PHONE_OR_JID [--user ...]`
- `whatsappincli groups participants promote|demote --jid GROUP_JID --user PHONE_OR_JID [--user ...]`
- `whatsappincli groups invite link get|revoke --jid GROUP_JID`
- `whatsappincli groups join --code INVITE_CODE`
- `whatsappincli groups leave --jid GROUP_JID`

## Output formats

Default: human-readable text (tables / aligned columns; TTY-aware wrapping).

Optional:

- `--json` prints `{"success":true,"data":...,"error":null}`-style responses.

Recommendation:

- Write logs/progress (sync counters, reconnect notices) to stderr.
- Write primary command output to stdout.

## Reliability considerations

- **Session conflicts**: running multiple instances can cause disconnects or “device replaced” behavior; locking is mandatory.
- **Reconnect**: on disconnect, retry with exponential backoff and respect context cancellation.
- **Idempotency**: message inserts are upserts keyed by (`chat_jid`, `msg_id`) so replays/history sync don’t duplicate data.

## Security considerations

- Store contains encryption keys/session data; protect permissions:
  - store dir `0700`
  - DB files `0600`
- Avoid printing sensitive identifiers in logs unless needed for debugging (`--verbose`).

## Implementation milestones

### v0.1 (MVP)

- `auth` (QR + bootstrap sync)
- `sync` (non-interactive, follow mode)
- `messages list/search` with FTS5
- `send text`
- store locking, default `~/.whatsappincli`

### v0.2

- contacts: show + local alias/notes/tags
- chats list/show with better naming resolution
- groups list/info/rename/participants

### v0.3

- media download command + optional background downloader
- `messages show/context` polish

