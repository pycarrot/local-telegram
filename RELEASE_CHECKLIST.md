# Release Checklist

## Pre-release audit

- [ ] Run parser check on all `.ps1` files.
- [ ] Confirm no `config.json` is committed.
- [ ] Confirm no logs or generated state files are committed.
- [ ] Confirm `config.example.json` contains placeholders only.
- [ ] Confirm README quick start works.
- [ ] Confirm LICENSE, CHANGELOG, and SECURITY files exist.

## Manual Windows smoke test

- [ ] Clone or download the repo on a Windows machine.
- [ ] Run `powershell -ExecutionPolicy Bypass -File .\setup.ps1`.
- [ ] Send a test photo.
- [ ] Install Scheduled Task.
- [ ] Start the watcher.
- [ ] Check status.
- [ ] Stop the watcher.
- [ ] Uninstall and confirm cleanup prompts.

## Release package

- [ ] Create a zip package.
- [ ] Confirm the zip does not include `config.json`, logs, or data files.
- [ ] Upload the zip to GitHub Releases.

## GitHub release

- [ ] Create tag `v0.1.0-beta`.
- [ ] Create release title `v0.1.0-beta`.
- [ ] Paste release notes from `CHANGELOG.md`.
