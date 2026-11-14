// Pure rules, kept free of QML so tests/model.test.js can check them with node.

// A plain non-negative number no bigger than max, else null.
function num(value, max) {
  if (!/^\d{1,12}(\.\d{1,6})?$/.test(String(value))) return null
  var n = Number(value)
  return n <= max ? n : null
}

// The output of poll.sh comes from another machine: keep only known keys,
// bounded numbers, and known words. Everything else is dropped.
function parse(text) {
  var kv = {}
  var lines = String(text).slice(0, 4000).split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = /^([a-z_0-9]{1,20})=([A-Za-z0-9.]{1,20})$/.exec(lines[i])
    if (m) kv[m[1]] = m[2]
  }
  var up = kv.tunnel === "up"
  return {
    tunnel: up,
    reachable: up && kv.ssh !== "fail" && num(kv.uptime, 1e10) !== null,
    uptime: num(kv.uptime, 1e10),
    load: num(kv.load, 1e5),
    cpus: num(kv.cpus, 4096),
    mem: num(kv.mem, 100),
    disk: num(kv.disk, 100),
    failedUnits: num(kv.failed_units, 1e5),
    sshFails: num(kv.ssh_fails, 1e9),
    firewall: kv.firewall === "active",
    passwordLogin: kv.password_login !== "no",
    fail2ban: kv.fail2ban === "active" ? "on" : kv.fail2ban === "missing" ? "not installed" : "off",
    updates: num(kv.updates, 1e5),
    secUpdates: num(kv.sec_updates, 1e5),
    reboot: kv.reboot === "yes"
  }
}

function count(n, one, many) { return n + " " + (n === 1 ? one : many) }

// Plain-English list of what needs attention. Empty means all good.
// Failed SSH logins and fail2ban are shown but never count as a problem:
// every public server gets login noise, and with password login off it is harmless.
function problems(s) {
  if (!s.tunnel) return []
  if (!s.reachable) return ["Can't reach the VPS over SSH"]
  var out = []
  if (s.disk !== null && s.disk >= 90) out.push("Disk is " + s.disk + "% full")
  if (s.mem !== null && s.mem >= 90) out.push("Memory is " + s.mem + "% used")
  if (s.load !== null && s.cpus && s.load / s.cpus >= 1.5) out.push("CPU load is high (" + s.load + ")")
  if (s.failedUnits) out.push(count(s.failedUnits, "service has", "services have") + " failed")
  if (!s.firewall) out.push("Firewall is off")
  if (s.passwordLogin) out.push("SSH password login is on")
  if (s.secUpdates) out.push(count(s.secUpdates, "security update", "security updates") + " waiting")
  if (s.reboot) out.push("Reboot needed to finish updates")
  return out
}

function uptimeText(seconds) {
  if (seconds === null) return "?"
  var d = Math.floor(seconds / 86400), h = Math.floor(seconds % 86400 / 3600), m = Math.floor(seconds % 3600 / 60)
  return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m"
}

if (typeof module !== "undefined") module.exports = {
  parse: parse, problems: problems, uptimeText: uptimeText
}
