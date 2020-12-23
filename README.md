# `ddns-cloudflare-powershell`

A simple Powershell script for DDNS with Cloudflare API.

## ✨ Features

- Dual-stack support: IPv4 + IPv6.
- Log file support.
- Resolve the hostname and compare with current IP to decide whether to send an update request.

## 🔌 Usage

- Edit `ddns-cloudflare-config.ps1`. Fill in your hostname, OAuth token, DNS zone ID and target record ID.
- For Linux, place the systemd unit files to the proper location. Enable and start the timer.
- For Windows, import `ddns-cloudflare-powershell.xml` to Task Scheduler. Start the task.

## ⚖ License

- This project is licensed under [GPLv3](LICENSE).

© 2020 database64128
