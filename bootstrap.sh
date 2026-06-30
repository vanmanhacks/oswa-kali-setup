#!/bin/bash
# OSWA Exam: Kali VM bootstrap
# Usage: git clone <repo> && cd oswa-kali-setup && ./bootstrap.sh
set -e

echo "==> Updating system..."
sudo apt update && sudo apt full-upgrade -y

echo "==> Installing VM guest tools..."
sudo apt install -y spice-vdagent qemu-guest-agent chromium

echo "==> Installing Chrome (proctoring browser)..."
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | sudo tee /usr/share/keyrings/google-chrome.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update

echo "==> Installing exam tools..."
sudo apt install -y seclists payloadsallthethings caido obsidian rustc google-chrome-stable ffuf sqlmap arjun

echo "==> Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "==> Installing Rust tools..."
cargo install rustscan

echo "==> Setting up OSWA directory structure..."
mkdir -p ~/OSWA/{exam-connection,findings,notes,sysreptor,targets}
mkdir -p ~/OSWA/targets/{host1,host2,host3,host4,host5}

echo "==> Installing SysReptor tools..."
cd ~/OSWA/sysreptor
uv venv
source .venv/bin/activate
uv pip install reptor[translate]
git clone https://github.com/tiagomanunes/mdfindings2reptor.git
cd "$OLDPWD"

echo "==> Verifying webcam..."
if ls /dev/video* 2>/dev/null; then
  echo "  Webcam detected: $(ls /dev/video* 2>/dev/null)"
else
  echo "  WARNING: No webcam detected. Check USB passthrough in virt-manager."
fi

echo "==> Importing notes from repo..."
cp "$(dirname "$0")"/oswa-battle-rhythm.md ~/OSWA/notes/
cp "$(dirname "$0")"/oswa-exam-notes.md ~/OSWA/notes/
cp "$(dirname "$0")"/oswa-sysreptor-guide.md ~/OSWA/notes/
cp "$(dirname "$0")"/oswa-commands-reference.md ~/OSWA/notes/
echo "  Notes imported to ~/OSWA/notes/"

echo "==> Importing keyboard shortcuts..."
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  prop=$(echo "$line" | awk '{print $1}')
  val=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
  xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -s "$val" --create -t string 2>/dev/null || true
done < "$(dirname "$0")/shortcuts.txt"
echo "  Shortcuts imported."

echo "==> Installing split_findings.py..."
cp "$(dirname "$0")/split_findings.py" ~/OSWA/

echo ""
echo "Done. VM is OSWA-ready."
echo "Directories: ~/OSWA/{exam-connection,findings,notes,sysreptor,targets}"
echo "Report workflow: ~/OSWA/split_findings.py → mdfindings2reptor → reptor push"
echo ""
echo "Next: log into Caido (license key), set up Chrome, export shortcuts to shortcuts.txt"
