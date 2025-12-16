# Auto Restart Zimbra Service + Discord Webhook Alert

A lightweight script to **monitor and automatically restart Zimbra services** when they stop.  
If a service is down, it will be restarted and an **alert will be sent to Discord via webhook**.

---

## Features
- Auto restart stopped Zimbra services
- Discord webhook alert
- Cron-based monitoring
- Simple & lightweight

---

## Requirements
- Zimbra server (root access)
- Zimbra installed
- curl
- Discord webhook URL

---

## Installation
```bash
git clone https://github.com/aldinowildhanku/alerting-auto-start-service-zimbra
cd auto-restart-zimbra
chmod +x monitor-zimbra.sh
