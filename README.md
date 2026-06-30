# OSWA Kali VM Setup

One `git clone` + one script = exam-ready Kali VM.

## Usage

```bash
# On a fresh Kali VM
git clone <repo-url> oswa-setup
cd oswa-setup
./bootstrap.sh
```

## What it does

- Installs tools: feroxbuster, ffuf, whatweb, jq, seclists, tmux
- Installs Rust + rustscan
- Imports your Xfce keyboard shortcuts from `shortcuts.txt`
- Copies `split_findings.py` to `~/oswa/`

## Files

| File | Purpose |
|---|---|
| `bootstrap.sh` | Run once on fresh VM — full setup |
| `shortcuts.txt` | Xfce keyboard shortcuts (exported via xfconf-query) |
| `split_findings.py` | Splits exam notes into per-finding markdown files for SysReptor |
| `oswa-battle-rhythm.md` | Exam strategy: timeline, rotation rule, panic checkpoints |
| `oswa-exam-notes.md` | Live exam notes template (mdfindings2reptor format) |
| `oswa-sysreptor-guide.md` | Step-by-step SysReptor reporting workflow |
| `oswa-commands-reference.md` | Ponytail-trimmed commands/payloads reference (1,289 lines) |
| `oswa-vm-setup.md` | Kali VM setup on NixOS host (QEMU/KVM) |
| `references/oswa-methodologies.md` | Study/prep reference: per-vuln methodology checklists |

## Customizing

### Update keyboard shortcuts

On your configured VM:
```bash
xfconf-query -c xfce4-keyboard-shortcuts -lv > shortcuts.txt
git add shortcuts.txt && git commit -m "update shortcuts"
```

### Add notes template

During the exam, write findings in `oswa-exam-notes.md` using mdfindings2reptor headers:
```
# Title
## SQL Injection in /login.php

# Summary
...

# Impact
...

# Recommendation
...

# Affected components
...

# References
...

# Description
...
```
