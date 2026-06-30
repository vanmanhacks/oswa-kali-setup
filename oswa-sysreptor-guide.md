# OSWA Exam: SysReptor Reporting Guide

## Pre-Exam Setup (do this NOW, not during exam)

### 1. SysReptor Account

Sign up at https://offsec.sysreptor.com/oscp/signup/ — free, zero setup.

### 2. Install Tools

```bash
# reptor CLI (push findings to SysReptor)
pip3 install reptor

# mdfindings2reptor (markdown findings → SysReptor JSON)
git clone https://github.com/tiagomanunes/mdfindings2reptor.git ~/tools/mdfindings2reptor

# Configure reptor (get token from SysReptor UI → Settings → API)
reptor conf
```

### 3. Pre-Stage Folder Structure

```bash
mkdir -p ~/oswa/{exam-connection,target-01,target-02,target-03,target-04,target-05,findings}
cp oswa-exam-notes.md ~/oswa/
```

### 4. Pre-Write Finding Templates

Create stub markdown files per vuln type in `~/oswa/findings/` with empty mdfindings2reptor headers. During the exam: fill in the blanks. After the exam: bulk-import.

### 5. Practice Once

Create a test project, write one finding in markdown, convert with mdfindings2reptor, push with reptor. Verify the PDF renders correctly. One practice run prevents exam-day panic.

## During Exam: Hacking Phase

**Do not touch SysReptor web UI.** Write everything in `oswa-exam-notes.md`.

- Findings section uses mdfindings2reptor headers (`# Title`, `# Summary`, `# Impact`, `# Recommendation`, `# Affected components`, `# References`, `# Description`)
- The `# Description` section is where your detailed walkthrough goes — screenshots, command output, step-by-step exploitation narrative
- Screenshot everything: flag contents + command that got you there

## During Exam: Reporting Phase (24h)

### Step 1: Create SysReptor Project

1. Log into offsec.sysreptor.com
2. New Project → select "OffSec OSWA Exam Report" design
3. Set project ID: `export REPTOR_PROJECT_ID=<uuid-from-url>`

### Step 2: Split Notes into Findings

Keep findings in `oswa-exam-notes.md` during hacking. After:

```bash
cd ~/oswa
python3 split_findings.py oswa-exam-notes.md    # → findings/f01.md, f02.md, ...
```

### Step 3: Convert to JSON

```bash
python3 ~/tools/mdfindings2reptor/mdfindings2reptor.py findings/ --aggregate-only --recurse --overwrite
```

### Step 4: Push to SysReptor

```bash
cat aggregated_findings.json | reptor finding
```

### Step 5: Fill Report Sections

In SysReptor web UI:
- Executive Summary — 2-3 paragraphs about exam approach
- Methodology — recon, exploitation, post-exploitation steps used
- Per-machine sections — SysReptor auto-populates from findings
- Add screenshots inline (paste from clipboard)

### Step 6: Render & Submit

1. Click "Render PDF"
2. Verify all flags appear, all screenshots readable
3. Download PDF, archive as `.7z`: `7z a OSWA-OS-XXXXX-Exam-Report.7z OSWA-OS-XXXXX-Exam-Report.pdf`
4. Upload to OffSec exam portal

## Key Facts

- **SysReptor finding fields:** title, cvss, summary, description, impact, recommendation, affected_components, references
- **mdfindings2reptor** maps markdown headers (`# Title`, `# Summary`, etc.) to these fields
- **`reptor finding`** pushes JSON to SysReptor API — creates new findings, never overwrites
- **Cloud is free.** No self-hosting needed for exam. Self-hosting available but adds complexity.
- **Notes vs Report:** SysReptor has two spaces — Notes (scratchpad, never in PDF) and Report (sections + findings, renders to PDF). You're using markdown files as scratchpad instead of SysReptor Notes. Either works.
- **Practice the workflow before exam day.** One dry run with a test finding catches all setup issues.

## References

- https://docs.sysreptor.com/offsec-reporting-with-sysreptor
- https://github.com/Syslifters/OffSec-Reporting (928 stars, OSWA template included)
- https://github.com/tiagomanunes/mdfindings2reptor
- https://docs.sysreptor.com/cli/getting-started (reptor CLI docs)
