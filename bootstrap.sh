#!/bin/bash
# OSWA Exam: Kali VM bootstrap
# Usage: git clone <repo> && cd oswa-kali-setup && ./bootstrap.sh
set -e

echo "==> Updating package lists..."
sudo apt update -qq

echo "==> Installing core tools..."
sudo apt install -y --no-install-recommends \
  feroxbuster \
  ffuf \
  whatweb \
  jq \
  seclists \
  tmux \
  python3-pip \
  curl \
  wget

echo "==> Installing Caido..."
# Download latest Caido desktop from https://caido.io/
# wget -q https://caido.download/releases/... -O /tmp/caido.deb
# sudo dpkg -i /tmp/caido.deb
echo "  (manual: download from https://caido.io/)"

echo "==> Installing Rust tools..."
if ! command -v cargo &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
fi
cargo install rustscan

echo "==> Importing keyboard shortcuts..."
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  prop=$(echo "$line" | awk '{print $1}')
  val=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
  xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" -s "$val" --create -t string 2>/dev/null || true
done < "$(dirname "$0")/shortcuts.txt"
echo "  Shortcuts imported."

echo "==> Installing split_findings.py..."
cp "$(dirname "$0")/split_findings.py" ~/oswa/

echo ""
echo "Done. VM is OSWA-ready."
echo "Notes template: copy from pentest-exam-prep skill"
echo "Report workflow: ~/oswa/split_findings.py + mdfindings2reptor"
