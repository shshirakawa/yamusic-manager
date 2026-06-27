# YAMusic Manager

Simple Yandex Music installer and manager for Arch-based Linux distributions.

Built for people who don't want to manually unpack `.deb` packages, fix permissions, repair Electron sandbox issues, or clean leftovers after updates.

YAMusic Manager handles everything automatically.

---

## About

Yandex officially ships only a Debian package for Linux.

That works fine on Debian/Ubuntu, but on Arch Linux, CachyOS and similar systems it requires manual extraction and installation.

This project automates that process.

It downloads the latest package directly from Yandex, extracts it, installs everything into the correct paths, applies permissions, updates desktop entries and icons, and cleans temporary files after itself.

No `dpkg`.
No `apt`.
No manual extraction.

Just one command.

---

## Features

* Install Yandex Music from official Yandex servers
* Update to the latest version
* Full uninstall without leftovers
* Repair broken permissions and Electron sandbox
* Launch directly from terminal
* Clean application cache
* Check installation status
* Reset the manager itself

---

## Supported systems

Works on:

* Arch Linux
* CachyOS
* EndeavourOS
* Manjaro
* Any Arch-based distribution

Architecture:

* x86_64 only

---

## Installation

Clone repository:

```bash
git clone https://github.com/shshirakawa/yamusic-manager.git
cd yamusic-manager
```

Make executable:

```bash
chmod +x yamusic.bash
```

Install globally:

```bash
sudo install -m755 yamusic.bash /usr/local/bin/yamusic
```

Done.

---

## Usage

Install:

```bash
yamusic install
```

Update:

```bash
yamusic update
```

Delete app:

```bash
yamusic delete
```

Repair installation:

```bash
yamusic repair
```

Launch app:

```bash
yamusic launch
```

Clean cache:

```bash
yamusic clean
```

Check status:

```bash
yamusic status
```

Reset manager:

```bash
yamusic reset
```

Show help:

```bash
yamusic help
```

---

## Screenshot

Add your screenshot here:

```text
assets/screenshot.png
```

Example:

```md
![YAMusic Manager](assets/screenshot.png)
```

---

## Author

Created by **Sh. Shirakawa**

Telegram:
https://t.me/veliona_channel

---

## License

YAMusic Manager is distributed under the **Personal Use License (PUL) v1.0**

Allowed:

* personal use
* local modifications
* private builds

Not allowed:

* forks
* redistribution
* republishing
* rebranding
* commercial usage
* removing author watermark

Read the full license in the `LICENSE` file.
