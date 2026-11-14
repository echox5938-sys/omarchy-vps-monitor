# VPS Monitor

An Omarchy bar widget for one VPS.

- Bar icon: server = fine, server with a cross = needs attention, struck-out and dim = tunnel off.
- Click it for a card with health stats (uptime, CPU load, memory, disk, failed services)
  and security stats (firewall, SSH password login, fail2ban, failed SSH logins in 24h,
  pending updates, reboot needed).
- **Connect / Disconnect** turns the WireGuard tunnel on or off.
- **Monitor** opens a terminal with an SSH shell on the VPS.
- Keys in the card: `C` connect, `M` monitor, `R` refresh, `Esc` close. Middle-click the icon to refresh.

## What it needs

- A NetworkManager WireGuard connection (default name `wg0`).
- An SSH alias (default `vps`) in `~/.ssh/config` that logs in with a key (no password prompt).
- A Debian or Ubuntu server (it reads `ufw` and `apt`).

Change either name in the widget settings, or in `~/.config/omarchy/shell.json`:

```json
{ "id": "sahils.vps-monitor", "tunnel": "my-wireguard", "sshHost": "myserver" }
```

## Install and remove

```bash
omarchy plugin add https://github.com/echox5938-sys/omarchy-vps-monitor.git --enable
omarchy plugin remove sahils.vps-monitor
```

## What it does on the network

- Every 5 minutes, and when the card opens, it runs `poll.sh`.
- `poll.sh` only contacts the VPS while the tunnel is up, with one SSH command that runs `remote.sh`.
- `remote.sh` only reads. It installs nothing and changes nothing on the server.
- To stop the checks: `omarchy plugin disable sahils.vps-monitor`.

"Updates waiting" uses the package lists the server last downloaded. It does not run `apt update`.

## Working on it

- Test the rules: `node tests/model.test.js`
- Test the check by hand: `sh poll.sh <connection> <ssh-host>`
- After editing `Panel.qml`, run `omarchy restart shell`. Hot reload kept running the old copy here.
- Open the card from a keybind: `omarchy-shell sahils.vps-monitor toggle`
