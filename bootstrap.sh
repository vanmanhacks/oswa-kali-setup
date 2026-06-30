#!/bin/bash
# OSWA Exam: Kali VM bootstrap
# Usage: git clone <repo> && cd oswa-kali-setup && ./bootstrap.sh
set -e

echo "==> Updating system..."
sudo apt update && sudo apt full-upgrade -y

echo "==> Installing VM guest tools..."
sudo apt install -y spice-vdagent qemu-guest-agent chromium
sudo systemctl enable --now spice-vdagentd

echo "==> Hardening Kali (pimpmykali)..."
if [ ! -d /tmp/pimpmykali ]; then
  git clone https://github.com/Dewalt-arch/pimpmykali.git /tmp/pimpmykali
fi
cd /tmp/pimpmykali && sudo ./pimpmykali.sh
cd "$OLDPWD"

echo "==> Installing Chrome (proctoring browser)..."
wget -qO /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i /tmp/chrome.deb && rm /tmp/chrome.deb

echo "==> Installing exam tools..."
sudo apt install -y \
  seclists \
  payloadsallthethings \
  gobuster \
  feroxbuster \
  sqlmap \
  caido \
  nmap \
  obsidian

echo "==> Installing pip tools (uv)..."
if ! command -v uv &>/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

echo "==> Installing Rust + tools..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
cargo install rustscan x8

echo "==> Setting up OSWA directory structure..."
mkdir -p ~/OSWA/{exam-connection,findings,notes,targets}
mkdir -p ~/OSWA/targets/{host1,host2,host3,host4,host5}

echo "==> Installing SysReptor tools..."
uv pip install reptor
mkdir -p ~/Clones
git clone https://github.com/tiagomanunes/mdfindings2reptor.git ~/Clones/mdfindings2reptor

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
echo "Directories: ~/OSWA/{exam-connection,findings,notes,targets}"
echo "Report workflow: ~/OSWA/split_findings.py → mdfindings2reptor → reptor push"
echo ""
echo "Next: log into Caido (license key), set up Chrome, export shortcuts to shortcuts.txt"
