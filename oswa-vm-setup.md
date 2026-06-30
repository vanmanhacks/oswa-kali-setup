# OSWA Exam VM: Kali on NixOS via QEMU/KVM

## NixOS Host Setup

Add to `/etc/nixos/configuration.nix`:

```nix
virtualisation.libvirtd.enable = true;
users.users.vanmanhacks.extraGroups = ["libvirtd"];
```

Rebuild, reboot, verify:

```bash
sudo nixos-rebuild switch && sudo reboot
# After reboot:
groups | grep libvirtd   # must show libvirtd
ls /dev/kvm               # must exist
```

## Install Kali VM

```bash
# Download Kali installer ISO
mkdir -p ~/VMs/kali
cd ~/VMs/kali
curl -LO https://cdimage.kali.org/kali-2026.1/kali-linux-2026.1-installer-amd64.iso

# Launch virt-manager
virt-manager
```

In virt-manager:
1. **File → New Virtual Machine**
2. **Local install media** → browse to the ISO
3. Uncheck "Detect OS", type "Debian 11"
4. **RAM:** 4096 MB | **CPUs:** 4
5. **Disk:** 40 GB (20GB minimum, 40GB for tools + notes)
6. **Name:** `kali-oswa`
7. Check "Customize before install" → **Finish**

### VM Hardware Tweaks (before first boot)

In the VM details window:
- **Video:** QXL → **Virtio** (better performance, Xorg-compatible)
- **Display:** Spice → change to Spice with **Xorg/X11** guest config
- **Add Hardware → USB Host Device** → select your webcam
- **CPU:** set topology: 1 socket, 4 cores
- **NIC:** use virtio

Click **Begin Installation**. Follow Kali installer (graphical install, default partitioning).

### Post-Install Config

Boot into Kali. CRITICAL: at login screen, click gear icon → select **"GNOME on Xorg"** (not Wayland). Screen sharing for proctoring doesn't work on Wayland.

```bash
# Update + base tools
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y spice-vdagent qemu-guest-agent chromium
sudo systemctl enable --now spice-vdagentd

git clone https://github.com/Dewalt-arch/pimpmykali.git; cd pimpmykali; sudo ./pimpmykali.sh

# Install Chrome (proctoring browser — more reliable than Chromium for screen sharing)
wget -qO- https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb | sudo tee /tmp/chrome.deb > /dev/null
sudo dpkg -i /tmp/chrome.deb && rm /tmp/chrome.deb

# Exam tools
sudo apt install -y seclists payloadsallthethings gobuster feroxbuster sqlmap caido nmap uv obsidian

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh   
echo "export PATH='$HOME/.cargo/bin:$PATH'" >> ~/.zshrc
source ~/.zshrc
cargo install rustscan x8

mkdir -p ~/OSWA/{exam-connection,findings,notes,targets}
mkdir ~/OSWA/targets/{host1,host2,host3,host4,host5}

# SysReptor tools
uv pip install reptor
git clone https://github.com/tiagomanunes/mdfindings2reptor.git ~/Clones/mdfindings2reptor.git
```

### Copy Notes & Scripts

From host (outside VM):

```bash
# On NixOS host
cd ~/Operations/AI-Agents/agent-workspace
tar -czf /tmp/oswa-files.tar.gz \
  oswa-exam-notes.md \
  oswa-sysreptor-guide.md \
  split_findings.py \
  "Battle Rhythm v2.md"

# Use virt-manager: VM details → Add Hardware → Filesystem
# Or use scp into the VM's IP
```

Inside VM:

```bash
mkdir -p ~/oswa/findings
cd ~/oswa
tar -xzf /path/to/oswa-files.tar.gz
```

### USB Webcam Passthrough

```bash
# On host, find webcam USB ID
lsusb
# Example: Bus 001 Device 003: ID 046d:0825 Logitech Webcam C270

# In virt-manager: VM details → Add Hardware → USB Host Device
# Select the webcam by vendor:product ID
# Check "Shareable" if you want host to also use it

# In Kali guest, verify:
ls /dev/video*
# Should show /dev/video0
```

## Test Proctoring

Before exam day (at least one week prior):

1. **Request a test session** — submit ticket at help.offsec.com
2. Launch Chrome in Kali, log into https://proctoring.offsec.com/student/login
3. Allow camera + screen share permissions
4. Proctor will verify: webcam feed, screen sharing works, identity visible
5. Run their `troubleshooting.sh` script when asked

**If screen sharing fails:** You're on Wayland. Log out, click gear → GNOME on Xorg, retry.

## Exam Day Checklist

- [ ] Boot `kali-oswa` VM
- [ ] GNOME on Xorg session (gear icon at login)
- [ ] Webcam detected: `ls /dev/video0`
- [ ] Chrome installed + screen sharing tested
- [ ] Notes + scripts in `~/oswa/`
- [ ] `seclists` + `payloadsallthethings` installed
- [ ] `reptor` configured: `reptor conf`
- [ ] VM has full screen on one monitor, Chrome on another
- [ ] Phone/electronics removed from desk area
- [ ] Government ID ready (English, non-expired)
- [ ] Log into proctoring 15 min before start

## Troubleshooting

| Problem | Fix |
|---|---|
| Webcam not showing in VM | `lsusb` in host, verify USB device ID, re-add in virt-manager |
| Screen share black screen | Switch to Xorg. Check `echo $XDG_SESSION_TYPE` = x11 |
| Chrome won't install | `sudo apt --fix-broken install` |
| Slow VM | Bump to 6GB RAM, enable KVM: `virt-manager` → CPU → Copy host config |
| Clipboard not shared | `sudo systemctl start spice-vdagentd` |
