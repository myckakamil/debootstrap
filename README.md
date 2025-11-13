# Debootstrap installer
A minimal, automated Debian installation script using `debootstrap`.

This project provides a simple and efficient way to install a clean Debian system from any live environment.
It automates partitioning, base system installation, and initial configuration. Everything will fit on 2GB of disk space. 

## Features
- Installs a minimal Debian system using debootstrap
- Configurable hostname, timezone, locale, and local user account
- Can be executed from any Debian-based live system
- Supports multiple filesystems (ext4, Btrfs, ZFS (soon))
- Optional LUKS encryption and RAID setup (soon)

## Usage
```
git clone https://github.com/myckakamil/debootstrap
cd debootstrap
chmod +x install.sh
sudo ./install.sh
```
or with in one line
```
bash <(curl -fsSL https://raw.githubusercontent.com/myckakamil/debootstrap/refs/heads/main/install.sh)
```