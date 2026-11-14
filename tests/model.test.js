// Run: node tests/model.test.js
const assert = require("assert")
const M = require("../Model.js")

const healthy = [
  "tunnel=up", "uptime=200000", "load=0.02", "cpus=1", "mem=14", "disk=15",
  "failed_units=0", "ssh_fails=120", "firewall=active", "password_login=no",
  "fail2ban=missing", "updates=0", "sec_updates=0", "reboot=no"
].join("\n")

// Healthy server: parsed, no problems. Login noise and no fail2ban are fine.
let s = M.parse(healthy)
assert(s.tunnel && s.reachable && s.firewall && !s.passwordLogin && !s.reboot)
assert.strictEqual(s.sshFails, 120)
assert.strictEqual(s.fail2ban, "not installed")
assert.deepStrictEqual(M.problems(s), [])

// Each bad value raises its own problem.
s = M.parse(healthy.replace("disk=15", "disk=93").replace("firewall=active", "firewall=inactive")
  .replace("password_login=no", "password_login=yes").replace("sec_updates=0", "sec_updates=1")
  .replace("reboot=no", "reboot=yes").replace("failed_units=0", "failed_units=2")
  .replace("load=0.02", "load=3.5").replace("mem=14", "mem=95"))
assert.deepStrictEqual(M.problems(s), [
  "Disk is 93% full", "Memory is 95% used", "CPU load is high (3.5)", "2 services have failed",
  "Firewall is off", "SSH password login is on", "1 security update waiting",
  "Reboot needed to finish updates"
])

// Tunnel off: not a problem, just off. SSH failure: one clear problem.
s = M.parse("tunnel=down")
assert(!s.tunnel && !s.reachable)
assert.deepStrictEqual(M.problems(s), [])
assert.deepStrictEqual(M.problems(M.parse("tunnel=up\nssh=fail")), ["Can't reach the VPS over SSH"])
assert.deepStrictEqual(M.problems(M.parse("")), [])

// Missing answers fail safe: unknown firewall or password setting is flagged.
s = M.parse("tunnel=up\nuptime=10")
assert(M.problems(s).includes("Firewall is off") && M.problems(s).includes("SSH password login is on"))

// Hostile output: markup, huge or negative numbers, and junk are dropped.
s = M.parse('tunnel=up\nuptime=5\ndisk=<img src="https://example.invalid/x">\nmem=999\nload=-1\n' +
  "fail2ban=<b>on</b>\ncpus=1e9\nssh_fails=12345678901234567890")
assert.strictEqual(s.disk, null)
assert.strictEqual(s.mem, null)
assert.strictEqual(s.load, null)
assert.strictEqual(s.cpus, null)
assert.strictEqual(s.sshFails, null)
assert.strictEqual(s.fail2ban, "off")
assert(!JSON.stringify(s).includes("<"))

// Uptime
assert.strictEqual(M.uptimeText(200000), "2d 7h")
assert.strictEqual(M.uptimeText(3700), "1h 1m")
assert.strictEqual(M.uptimeText(59), "0m")
assert.strictEqual(M.uptimeText(null), "?")

console.log("ok")
