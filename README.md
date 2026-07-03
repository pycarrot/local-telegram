# Local Telegram Notifier

Local Telegram Notifier is a Windows PowerShell tool that watches local or network camera folders and sends new `.jpg` images to a Telegram chat.

It is designed for non-technical Windows users: run setup once, then manage it with simple commands.

## Features

- One-command interactive setup
- Windows-first PowerShell scripts
- No Node.js, Python, Docker, npm, pip, or external dependencies
- Telegram `sendPhoto` with `sendDocument` fallback for image processing failures
- Folder watcher plus polling fallback
- Persistent sent-file state to reduce duplicate sends
- Retry and failed-send tracking
- Scheduled Task auto-start
- Clear logs and status output

## Requirements

- Windows
- Windows PowerShell 5.1 or newer
- Telegram bot token
- Telegram chat, group, or channel where the bot can send messages

## Download / Clone

### Option A: Git

```powershell
git clone https://github.com/pycarrot/local-telegram.git
cd local-telegram
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

### Option B: Download ZIP

1. Click **Code** > **Download ZIP** on GitHub.
2. Extract the ZIP file.
3. Open PowerShell in the extracted folder.
4. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

## Quick Start

From inside the project folder, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

After setup:

```powershell
.\start.ps1
.\status.ps1
.\stop.ps1
.\uninstall.ps1
```

If Windows blocks direct script execution, use the `powershell -ExecutionPolicy Bypass -File ...` form shown in the sections below.

## One-Command Setup

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

Setup will ask for your Telegram bot token, chat ID, watch folders, file filter, polling interval, and whether to install auto-start or send a test photo.

## Manual Setup

Copy the example config:

```powershell
Copy-Item .\config.example.json .\config.json
notepad .\config.json
```

Then test:

Simple form:

```powershell
.\send-test.ps1 -PhotoPath "C:\path\test.jpg"
```

Reliable form:

```powershell
powershell -ExecutionPolicy Bypass -File .\send-test.ps1 -PhotoPath "C:\path\test.jpg"
```

## Telegram Bot Token

1. Open Telegram.
2. Chat with `@BotFather`.
3. Run `/newbot`.
4. Follow the prompts.
5. Copy the bot token into `config.json`.

## Telegram Chat ID

For a group:

1. Add the bot to the group.
2. Send a message in the group.
3. Open this URL in a browser, replacing the token:

```text
https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/getUpdates
```

4. Find `chat.id` and put it in `config.json`.

Group chat IDs are often negative numbers.

## Watched Folders

Add one or more folders to `watch.folders`:

```json
"folders": [
  "C:\\Cameras\\FrontDoor",
  "\\\\server\\share\\Camera1"
]
```

Local paths and network folders are supported. For production use, prefer UNC paths such as `\\server\share\folder`. Mapped drives like `F:\Camera` may not be available immediately after reboot.

## Send Test Photo

Simple form:

```powershell
.\send-test.ps1 -PhotoPath "C:\path\test.jpg"
```

Reliable form:

```powershell
powershell -ExecutionPolicy Bypass -File .\send-test.ps1 -PhotoPath "C:\path\test.jpg"
```

## Install Auto-Start

Simple form:

```powershell
.\install.ps1
```

Reliable form:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

If run as Administrator, it installs an AtStartup Scheduled Task. Otherwise, it installs an AtLogOn task for the current user.

## Start, Stop, Status

Simple form:

```powershell
.\start.ps1
.\stop.ps1
.\status.ps1
```

Reliable form:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
powershell -ExecutionPolicy Bypass -File .\stop.ps1
powershell -ExecutionPolicy Bypass -File .\status.ps1
```

If the Scheduled Task is not installed, `start.ps1` will ask before running `watch.ps1` in the current PowerShell window.

## Uninstall

Simple form:

```powershell
.\uninstall.ps1
```

Reliable form:

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Uninstall removes the Scheduled Task and asks whether to delete `config.json`, `logs`, and `data`.

## Configuration Reference

| Field | Default | Description |
| --- | --- | --- |
| `telegram.bot_token` | required | Telegram bot token from BotFather. |
| `telegram.chat_id` | required | Telegram chat, group, or channel ID. |
| `watch.folders` | required | Folders watched recursively. |
| `watch.file_filter` | `*.jpg` | File pattern to watch and poll. |
| `watch.poll_minutes` | `2` | Polling fallback interval. |
| `watch.send_existing_files_from_last_minutes` | `0` | Send recent existing files on startup. `0` disables this. |
| `message.caption_template` | see example | Supports `{camera}`, `{date}`, `{time}`, `{folder}`, `{filename}`, `{fullpath}`. |
| `message.send_as_document_on_photo_fail` | `true` | Use `sendDocument` if Telegram cannot process the image as a photo. |
| `reliability.retry_count` | `3` | Send attempts per file. |
| `reliability.retry_delay_seconds` | `10` | Delay between retries. |
| `reliability.max_file_ready_wait_seconds` | `30` | Wait for a file to finish writing. |
| `reliability.log_retention_days` | `14` | Delete old log files after this many days. |
| `reliability.state_retention_days` | `30` | Remove old sent-file state entries. |

## Troubleshooting

- Invalid token: run setup again or edit `config.json`; verify the token with BotFather.
- Invalid chat ID: make sure the bot is in the chat and allowed to send messages.
- Watch folder not found: run `.\status.ps1`; the watcher logs a warning and retries.
- Mapped drive unavailable after reboot: use a UNC path like `\\server\share\folder`.
- Files detected but not sent: check `logs\watcher.log` and `data\failed.jsonl`.
- Duplicate sends: the app tracks path, size, and last write time in `data\state.json`; deleting `data` resets that memory.
- `IMAGE_PROCESS_FAILED`: keep `message.send_as_document_on_photo_fail` enabled.
- Log location: `logs\watcher.log`.

## Security

- Never commit `config.json`.
- Never share Telegram bot tokens, chat IDs, private camera paths, logs, or generated state files.
- If a token leaks, revoke it in BotFather and generate a new token.
- Use a private Telegram group or channel and control who can see sent images.

## Limitations

- The app runs under the Windows user or task account that installed it.
- Network folders depend on Windows credentials and network availability.
- Very high-volume folders may require shorter polling intervals or operational monitoring.

## Roadmap

- Release zip packaging
- Optional health-check notifications
- Optional Windows Event Log output
- More detailed Telegram rate-limit handling

## License

MIT. See [LICENSE](LICENSE).
