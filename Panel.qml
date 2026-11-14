import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// shortcut: English strings only, add i18n/ catalogs if other languages are wanted.
Panel {
  id: root
  moduleName: "sahils.vps-monitor"
  // Lets a keybind open the card: omarchy-shell sahils.vps-monitor toggle
  ipcTarget: "sahils.vps-monitor"

  // Widget settings. Both end up as command arguments, so anything that is not
  // a plain name (or starts with "-", which would read as an option) is ignored.
  function safeName(value, fallback) {
    var v = String(value)
    return /^[A-Za-z0-9_.@][A-Za-z0-9_.@-]{0,63}$/.test(v) ? v : fallback
  }
  readonly property string tunnelName: safeName(setting("tunnel", "wg0"), "wg0") // NetworkManager connection
  readonly property string sshHost: safeName(setting("sshHost", "vps"), "vps")   // alias in ~/.ssh/config
  readonly property int refreshMs: 5 * 60 * 1000

  property var stats: Model.parse("")
  property bool checked: false
  property string checkedAt: ""
  readonly property var problems: Model.problems(stats)
  readonly property bool online: stats.tunnel && stats.reachable

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Built only from fixed words and checked numbers, never from server text.
  readonly property string summary: !checked ? "Checking…"
    : !stats.tunnel ? "Tunnel is off"
    : problems.length === 0 ? "All good"
    : problems.length === 1 ? "1 problem" : problems.length + " problems"

  function show(value, suffix) { return value === null ? "?" : value + (suffix || "") }

  // --- Checking the VPS ------------------------------------------------
  // One read-only SSH command, and only while the tunnel is up (see poll.sh).
  // A request during a running check is kept, not dropped: that check may
  // have started before the tunnel changed and would report the old state.
  property bool refreshAgain: false
  function refresh() {
    if (poll.running) refreshAgain = true
    else poll.running = true
  }

  Process {
    id: poll
    // Next tick, so the finished run has let go before the new one starts.
    onExited: if (root.refreshAgain) { root.refreshAgain = false; Qt.callLater(root.refresh) }
    // Decoded, so an install path with spaces still works.
    command: ["sh", decodeURIComponent(String(Qt.resolvedUrl("poll.sh")).replace(/^file:\/\//, "")),
      root.tunnelName, root.sshHost]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.stats = Model.parse(text)
        root.checked = true
        root.checkedAt = new Date().toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale), "HH:mm")
      }
    }
  }
  Timer { interval: root.refreshMs; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  onOpenedChanged: if (opened) refresh()

  // --- Buttons ---------------------------------------------------------
  Process { id: tunnelToggle; onExited: root.refresh() }
  function toggleTunnel() {
    if (tunnelToggle.running) return
    tunnelToggle.command = ["nmcli", "connection", stats.tunnel ? "down" : "up", tunnelName]
    tunnelToggle.running = true
  }
  function openTerminal() {
    if (!stats.tunnel) return
    Quickshell.execDetached(["omarchy-launch-tui", "ssh", "--", sshHost])
    close()
  }

  // --- Bar icon --------------------------------------------------------
  // The icon changes shape, not only color: some themes have a grey "urgent".
  // Server = fine, server with a cross = needs attention, struck-out and dim = tunnel off.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.checked && !root.stats.tunnel ? "󰒏" : root.problems.length > 0 ? "󰒑" : "󰒋"
    active: root.problems.length > 0
    dimmed: root.checked && !root.stats.tunnel
    tooltipText: "VPS: " + root.summary
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  // --- Drop-down card --------------------------------------------------
  component Plain: Text {
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }

  component Stat: Item {
    id: stat
    property string label: ""
    property string value: ""
    property bool bad: false
    width: parent ? parent.width : 0
    implicitHeight: valueText.implicitHeight
    Plain { anchors.left: parent.left; text: stat.label; opacity: 0.7 }
    Plain { id: valueText; anchors.right: parent.right; text: stat.value; font.bold: stat.bad }
  }

  KeyboardPanel {
    id: card
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    // Both sizes include the card's padding and border; the helpers add them.
    contentWidth: card.fittedContentWidth(Style.space(280))
    contentHeight: card.fittedContentHeight(cardColumn.implicitHeight)
    focusTarget: keys

    // Esc closes. C = connect/disconnect, M = monitor, R = refresh.
    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        var key = text.toLowerCase()
        if (key === "c") root.toggleTunnel()
        else if (key === "m") root.openTerminal()
        else if (key === "r") root.refresh()
      }
    }

    Column {
      id: cardColumn
      width: parent.width
      spacing: Style.space(8)

      Item {
        width: parent.width
        implicitHeight: title.implicitHeight
        Plain { id: title; anchors.left: parent.left; text: "VPS"; font.pixelSize: Style.font.title; font.bold: true }
        Plain {
          anchors.right: parent.right
          anchors.verticalCenter: title.verticalCenter
          text: root.summary
          font.bold: root.problems.length > 0
        }
      }

      Repeater {
        model: root.problems
        Plain {
          required property string modelData
          width: cardColumn.width
          text: "󰀦 " + modelData
          font.bold: true
          wrapMode: Text.WordWrap
          elide: Text.ElideNone
        }
      }

      Column {
        visible: root.online
        width: parent.width
        spacing: Style.space(4)

        PanelSeparator { foreground: root.foreground }
        PanelSectionHeader { text: "Health"; foreground: root.foreground; fontFamily: root.fontFamily }
        Stat { label: "Uptime"; value: Model.uptimeText(root.stats.uptime) }
        Stat { label: "CPU load"; value: root.show(root.stats.load) }
        Stat { label: "Memory"; value: root.show(root.stats.mem, "%"); bad: root.stats.mem >= 90 }
        Stat { label: "Disk"; value: root.show(root.stats.disk, "%"); bad: root.stats.disk >= 90 }
        Stat { label: "Failed services"; value: root.show(root.stats.failedUnits); bad: root.stats.failedUnits > 0 }

        PanelSeparator { foreground: root.foreground }
        PanelSectionHeader { text: "Security"; foreground: root.foreground; fontFamily: root.fontFamily }
        Stat { label: "Firewall"; value: root.stats.firewall ? "on" : "off"; bad: !root.stats.firewall }
        Stat { label: "SSH password login"; value: root.stats.passwordLogin ? "on" : "off"; bad: root.stats.passwordLogin }
        Stat { label: "fail2ban"; value: root.stats.fail2ban }
        Stat { label: "Failed SSH logins (24h)"; value: root.show(root.stats.sshFails) }
        Stat {
          label: "Updates waiting"
          value: root.show(root.stats.updates) + (root.stats.secUpdates ? " (" + root.stats.secUpdates + " security)" : "")
          bad: root.stats.secUpdates > 0
        }
        Stat { label: "Reboot needed"; value: root.stats.reboot ? "yes" : "no"; bad: root.stats.reboot }
      }

      PanelSeparator { foreground: root.foreground }

      Row {
        id: buttons
        width: parent.width
        spacing: Style.space(8)
        Button {
          width: (buttons.width - buttons.spacing) / 2
          bordered: true
          foreground: root.foreground
          text: tunnelToggle.running ? "Working…" : root.stats.tunnel ? "Disconnect" : "Connect"
          iconText: root.stats.tunnel ? "󰌙" : "󰌘"
          tooltipText: "Turn the WireGuard tunnel to the VPS on or off (C)"
          onClicked: root.toggleTunnel()
        }
        Button {
          width: (buttons.width - buttons.spacing) / 2
          bordered: true
          foreground: root.foreground
          enabled: root.stats.tunnel
          opacity: enabled ? 1 : 0.45
          text: "Monitor"
          iconText: "󰆍"
          tooltipText: "Open a terminal on the VPS (M)"
          onClicked: root.openTerminal()
        }
      }

      Plain {
        visible: root.checkedAt !== ""
        text: (poll.running ? "Checking… last check " : "Checked ") + root.checkedAt
        font.pixelSize: Style.font.caption
        opacity: 0.5
      }
    }
  }
}
