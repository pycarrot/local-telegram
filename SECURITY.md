# Security Policy

Do not commit `config.json`. It contains your Telegram bot token, chat ID, and local folder paths.

## If a Telegram Bot Token Leaks

1. Open Telegram and chat with `@BotFather`.
2. Select the affected bot.
3. Revoke the leaked token.
4. Generate a new token.
5. Update `config.json`.
6. Restart the watcher with `.\stop.ps1` and `.\start.ps1`.

## Reporting a Vulnerability

Please report security issues through GitHub private vulnerability reporting if available, or contact the maintainer directly. Do not include real tokens, chat IDs, private paths, logs, or camera images in public issues.

## Telegram Chat Privacy

Use a private Telegram group or channel for camera images. Review who has access before enabling automatic sending.
