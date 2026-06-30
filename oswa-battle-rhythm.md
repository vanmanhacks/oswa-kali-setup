# OSWA Battle Rhythm v2

> **5 machines × 2 flags (local.txt + proof.txt) = 100 pts. 70 to pass = 7 flags.**
> 24h hacking → 24h reporting. Proctored.

## Exam Facts

- **local.txt** — in the web app admin section. Exploit the app, reach admin, grab flag.
- **proof.txt** — in server filesystem (`/`, `C:\`, or home dir). Requires RCE or file read.
- **10 pts/flag.** Each machine: 10 local + 10 proof = 20 pts. Pass threshold: 70 pts (7 of 10 flags).
- **No privesc.** WEB-200 doesn't test privilege escalation. Get RCE, grab proof.txt, done.
- **SQLMap allowed** but often fails on the exam boxes. Manual SQLi is expected.

**Vulnerability types — all confirmed in exam:**
XSS, CSRF, SQLi, SSRF, XXE, CORS, SSTI, Command Injection, IDOR, Directory Traversal/LFI, File Upload.

**Report format (OffSec template):** Per machine: flag contents, vulnerability walkthrough + screenshots, reproducible steps, sample code. Submit as `.7z` under 200MB with filename `OSWA-OS-XXXXX-Exam-Report.7z`.

## Strategy: Two-Pass Horizontal

**Hit all `local.txt` first. Then all `proof.txt`.** local.txt flags are app-layer exploitation — faster. proof.txt needs RCE — save for after sleep when your brain is sharp.

```
PASS 1 (Hrs 1-6):  local.txt  on ALL machines — shallow, fast rotation
               ↓
            SLEEP (Hrs 6-10)
               ↓
PASS 2 (Hrs 10-22): proof.txt on proven machines + local.txt on machines that resisted Pass 1
```

## Timeline

| Block | Hours | What | Target |
|-------|:-----:|------|--------|
| Recon | 0–1 | Browse all 5 apps. Map every endpoint. robots.txt, .git, .env, JS sources, default creds, wappalyzer. Run gobuster on all 5 in parallel. | Surface map |
| Pass 1 | 1–6 | Top 3 vuln hypotheses per machine. Rotate **every 60 min** max. Find low-hanging fruit. | 2+ local.txt |
| **SLEEP** | **6–10** | **4 hours. Do not negotiate.** | Fresh brain |
| Pass 2 | 10–16 | RCE/privilege-escalation equivalent on proven machines. Deeper enum (feroxbuster, param fuzzing, API probing) on resistant machines. | proof.txt + remaining local.txt |
| System | 16–22 | Hardest flags. Chain exploits. | proof.txt on 3+ |
| Wrap | 22–24 | Screenshot everything. Verify flags entered in control panel. Save every Caido request. | Ready to report |

## Rotation Rule

**60 minutes per machine without a flag. Then move.** ~3.5h per machine across 20 active hours. Burning 2h on a dead end leaves 3 other machines untouched. Fresh eyes post-sleep find what tired eyes miss.

## Panic Checkpoints

| Time | Flags | Status |
|------|:-----:|--------|
| **Hour 6** (pre-sleep) | ≥2 | Comfortable — sleep easy |
| | 1 | Nervous — sleep anyway, fresh brain finds more |
| | 0 | Trouble — re-run recon on all after sleep |
| **Hour 14** (post-sleep+4) | ≥4 (local on 3+) | Confident |
| | 2–3 | Push hard — focus 2 most promising |
| | ≤1 | Critical — abandon hardest 2, max 3 easiest |
| **Hour 20** | ≥7 | Strong — polish and screenshot |
| | 5–6 | Tight — 4h on 1 machine at a time |
| | <5 | Damage control — document perfectly what you have |
| **Hour 23** | all screenshots done | Ready for reporting |

## Flag Tracking

| Machine | local.txt | proof.txt | Total |
|:-------:|:---------:|:---------:|:-----:|
| M-01 | [ ] | [ ] | /2 |
| M-02 | [ ] | [ ] | /2 |
| M-03 | [ ] | [ ] | /2 |
| M-04 | [ ] | [ ] | /2 |
| M-05 | [ ] | [ ] | /2 |
| **Live** | **/5** | **/5** | **/10** |

## Exam Rules

1. **Screenshot the flag + the command.** No screenshot = no points.
2. **Save every Caido/Burp request.** You'll need them for the report.
3. **No report writing during hacking.** Exploit now. Write later. The phases exist for a reason.
4. **Sleep is tactical.** Hour 6 after initial exploitation pass. Post-sleep you attack RCE with a sharp mind.
5. **Rotate at 60 min.** With ~3.5h/machine, burning past 60 min on a dead end is a tactical error.
6. **Parallelize.** Gobuster runs while you manually browse. wfuzz runs while you analyze source.

## Prep Must-Dos (from exam-takers who passed)

- Complete every course module, exercise, challenge lab, and extra mile — twice
- Solve all lab machines **independently** (no Discord hints — you'll pay for it on exam day)
- Build a copy/paste command sheet organized by vulnerability type
- Install SecLists: `sudo apt-get install seclists`
- Install PayloadsAllTheThings: `sudo apt-get install payloadsallthethings`
- Pre-stage the folder structure: `~/oswa/exam/{exam-connection,filehosting,target-01..05}`
- Pre-write malicious payload files (xss.js, cookies.js) in `filehosting/`
- Export `$URL` and `$IP` per target so your wfuzz commands work instantly
