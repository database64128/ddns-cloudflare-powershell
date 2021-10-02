# `ddns-cloudflare-powershell`

[![AUR version](https://img.shields.io/aur/version/ddns-cloudflare-powershell-git?label=ddns-cloudflare-powershell-git)](https://aur.archlinux.org/packages/ddns-cloudflare-powershell-git/)

A simple Powershell script for DDNS with Cloudflare API.

## ✨ Features

- Ease of use: Automatically create new DNS records or reuse existing records.
- Dual-stack support: Enable A and/or AAAA record updates on demand.
- Low overhead: Send API requests only when IP changes.
- Logging: Print to stdout or log file.

## 🔌 Usage

### Arch Linux

- Install [ddns-cloudflare-powershell-git](https://aur.archlinux.org/packages/ddns-cloudflare-powershell-git/) from AUR.
- Edit `/etc/ddns-cloudflare-powershell/settings.jsonc` to change settings and fill in your hostname, OAuth token, and DNS zone ID.
- Enable and start `ddns-cloudflare-powershell.service`.

## ⚖ License

- This project is licensed under [GPLv3](LICENSE).

© 2021 database64128
