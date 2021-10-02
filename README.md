# `ddns-cloudflare-powershell`

A simple Powershell script for DDNS with Cloudflare API.

## ✨ Features

- Ease of use: Automatically create new DNS records or reuse existing records.
- Dual-stack support: Enable A and/or AAAA record updates on demand.
- Low overhead: Send API requests only when IP changes.
- Logging: Print to stdout or log file.

## 🔌 Usage

- Copy `settings.jsonc.example` to `settings.jsonc` and fill in your hostname, OAuth token, and DNS zone ID.
- For Linux, place the systemd unit file to a proper location. Enable and start the service.
- For Windows, import `ddns-cloudflare-powershell.xml` to Task Scheduler. Start the task.

## ⚖ License

- This project is licensed under [GPLv3](LICENSE).

© 2021 database64128
