# OSWA Kali VM Setup

One `git clone` + one script = exam-ready Kali VM.

## Usage

```bash
# On a fresh Kali VM
git clone https://github.com/vanmanhacks/oswa-kali-setup.git
cd oswa-kali-setup
./bootstrap.sh
```

## What it does

- Installs preferred exam tools via apt, cargo, and uv
- Imports Xfce keyboard shortcuts from `shortcuts.txt`
- Copies notes and scripts into `~/OSWA/`

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

## Customizing

### Update keyboard shortcuts

On your configured VM:
```bash
xfconf-query -c xfce4-keyboard-shortcuts -lv > shortcuts.txt
git add shortcuts.txt && git commit -m "update shortcuts"
```
