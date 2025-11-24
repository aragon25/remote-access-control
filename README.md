# remote-access-control

Small administration helper to enable/disable common remote access services and network manager choices on Raspberry Pi systems. Provides commands to control SSH, RealVNC, web‑VNC, Cockpit, Wi‑Fi power‑save behavior and to switch between `dhcpcd` and `NetworkManager`.

---

## 📌 Features

- Enable/disable SSH server (installs keys when enabling)
- Enable/disable RealVNC server and vnc-web helper
- Enable/disable Cockpit web admin socket
- Toggle Wi‑Fi power‑save in a reboot‑resistant way (systemd per‑interface service)
- Switch default network manager between `dhcpcd` and `NetworkManager` (converts WPA config when switching)

---

## 🧰 Dependencies

Required on the host/target system:

- `bash`
- `dhcpcd5` and `NetworkManager` (both of them)
- `ssh` (OpenSSH server) when enabling SSH
- `realvnc-vnc-server` if using RealVNC
- `cockpit` if enabling Cockpit

The script checks these packages before attempting actions and prints instructions if they are missing.

---

## 📂 Installation

### Option 1 — Install via `.deb` (recommended)

Build or download the release package and install on the device:

```bash
wget https://github.com/aragon25/remote-access-control/releases/download/v1.3-2/remote-access-control_1.3-2_all.deb
sudo apt install ./remote-access-control_1.3-2_all.deb
```

The package places the helper script and any packaging-provided files into system locations; inspect `deploy/config/build_deb.conf` for details.

---

### Option 2 — From source

Copy the script to a system path and make it executable:

```bash
sudo cp remote-access-control.sh /usr/local/bin/remote-access-control
sudo chmod +x /usr/local/bin/remote-access-control
```

Run the script as root to perform the configured actions.

---

## ⚙️ Usage

Run the script as `root`. Only one option may be used at a time.

```bash
sudo remote-access-control.sh --help
```

Options (examples):

- `--enable_ssh` / `--disable_ssh` — enable or disable SSH server
- `--enable_vnc` / `--disable_vnc` — enable or disable RealVNC server
- `--enable_vnc-web` / `--disable_vnc-web` — enable/disable vnc-web helper
- `--enable_cockpit` / `--disable_cockpit` — enable or disable Cockpit
- `--enable_wlan_pwrsave` / `--disable_wlan_pwrsave` — toggle Wi‑Fi power‑save behavior
- `--use_networkmanager` / `--use_dhcpcd` — switch between NetworkManager and dhcpcd
- `-v, --version` — print version
- `-h, --help` — show help

---

## 📁 Files of interest

- `src/remote-access-control.sh` — main script with all control commands.
- `deploy/build_deb.sh`, `deploy/build_test_deb.sh` — packaging helpers to create `.deb` artifacts placed into `packages/`.
- `deploy/config/*.sh` — packaging hooks executed by the package (review before installing).

---

## ⚠️ Safety & recommendations

- The script requires `root` privileges and manipulates system services; test on a disposable device or VM before applying to production devices.
- Review `deploy/config/preinst.sh` / `postinst.sh` before running any generated installers.
- Switching network managers may modify network configuration files; keep backups of `/etc/wpa_supplicant/wpa_supplicant.conf`, `/etc/NetworkManager/system-connections/` and related files.

---

## Examples

Enable SSH and RealVNC, then reboot to apply changes if needed:

```bash
# Enable SSH and start service
sudo remote-access-control --enable_ssh

# Switch to NetworkManager (will try to convert wpa_supplicant.conf)
sudo remote-access-control --use_networkmanager

# Disable RealVNC server
sudo remote-access-control --disable_vnc
```
