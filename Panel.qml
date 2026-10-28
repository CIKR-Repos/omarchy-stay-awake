import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Stay Awake: keep the system awake (lid closed included) and move the mouse
// now and then. The `stay-awake` script next to this file does the work and
// owns the settings; this panel shows them and changes them.
Panel {
  id: root
  moduleName: "cikr-repos.stay-awake"
  ipcTarget: "stay-awake"

  readonly property string script: Qt.resolvedUrl("stay-awake").toString().replace("file://", "")
  // Last `stay-awake get` result.
  property var st: ({ active: false, until: 0, settings: {} })
  readonly property var s: st.settings || ({})
  readonly property bool awake: !!st.active

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var intervalStops: [10, 15, 30, 45, 60, 90, 120, 180, 300, 600]
  readonly property var autoOffOptions: [
    { value: "0", label: "Never" }, { value: "30", label: "30m" }, { value: "60", label: "1h" },
    { value: "120", label: "2h" }, { value: "240", label: "4h" }, { value: "480", label: "8h" }
  ]
  readonly property var batteryOptions: [
    { value: "0", label: "Never" }, { value: "10", label: "10%" },
    { value: "20", label: "20%" }, { value: "30", label: "30%" }
  ]

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!getProc.running) getProc.running = true
  }

  // Commands run one at a time, in order, then the state is re-read.
  property var queue: []
  function run(args) {
    queue = queue.concat([[script].concat(args)])
    pump()
  }
  function pump() {
    if (runProc.running || queue.length === 0) return
    runProc.command = queue[0]
    queue = queue.slice(1)
    runProc.running = true
  }

  // Shown at once; the script confirms on the next refresh.
  function setSetting(key, value) {
    var next = Object.assign({}, s)
    next[key] = value
    st = Object.assign({}, st, { settings: next })
    run(["set", key, String(value)])
  }

  function setAwake(on) {
    st = Object.assign({}, st, { active: on })
    run([on ? "on" : "off"])
  }

  function formatSeconds(sec) {
    if (sec < 60) return sec + "s"
    if (sec % 60 === 0) return (sec / 60) + " min"
    return Math.floor(sec / 60) + "m " + (sec % 60) + "s"
  }

  function nearestStop(sec) {
    var best = 0
    for (var i = 0; i < intervalStops.length; i++)
      if (Math.abs(intervalStops[i] - sec) < Math.abs(intervalStops[best] - sec)) best = i
    return best
  }

  readonly property string statusText: {
    if (!awake) return "OFF · NORMAL SLEEP"
    if (st.until > 0) {
      var d = new Date(st.until * 1000)
      return "ON · UNTIL " + Qt.formatTime(d, "hh:mm")
    }
    return "ON · UNTIL YOU TURN IT OFF"
  }

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  // Picks up changes made from the terminal and the auto-off timer.
  Timer {
    interval: root.opened ? 2000 : 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: getProc
    command: [root.script, "get"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          // Don't overwrite an optimistic change still waiting to run.
          if (!runProc.running && root.queue.length === 0) root.st = parsed
        } catch (e) {}
      }
    }
  }

  Process {
    id: runProc
    onExited: {
      if (root.queue.length > 0) root.pump()
      else root.refresh()
    }
  }

  // ---------- Bar button ----------
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.awake ? "󰅶" : "󰛊"
    active: root.awake
    tooltipText: root.awake
      ? "Staying awake. Click for settings, right-click to turn off"
      : "Stay Awake is off. Click for settings, right-click to turn on"
    onPressed: function(b) {
      if (b === Qt.RightButton || b === Qt.MiddleButton) root.setAwake(!root.awake)
      else root.toggle()
    }
  }

  // ---------- Reusable rows ----------
  component SectionTitle: Item {
    property string text: ""
    property string value: ""
    width: parent ? parent.width : 0
    implicitHeight: Math.max(header.implicitHeight, valueText.implicitHeight)

    PanelSectionHeader {
      id: header
      text: parent.text
      foreground: root.foreground
      fontFamily: root.fontFamily
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: valueText
      textFormat: Text.PlainText
      text: parent.value
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  component SettingToggle: Toggle {
    property string key: ""
    width: parent ? parent.width : 0
    foreground: root.foreground
    fontFamily: root.fontFamily
    checked: !!root.s[key]
    onClicked: root.setSetting(key, !checked)
  }

  component SubLabel: Text {
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  // ---------- Popup ----------
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // ---------- Hero: icon · title/status · master switch ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, master.implicitHeight)

            Text {
              id: heroIcon
              textFormat: Text.PlainText
              text: root.awake ? "󰅶" : "󰛊"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: master.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Stay Awake"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: root.statusText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }

            ToggleSwitch {
              id: master
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              foreground: root.foreground
              checked: root.awake
              onToggled: root.setAwake(!root.awake)
            }
          }

          // ---------- Keep awake ----------
          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            SectionTitle { text: "KEEP AWAKE" }

            SettingToggle {
              key: "screen"
              label: "Keep screen on"
              description: "No screensaver, screen-off or idle lock."
            }
            SettingToggle {
              key: "sleep"
              label: "Block sleep"
              description: "The system won't suspend on its own."
            }
            SettingToggle {
              key: "lid"
              label: "Keep running with lid closed"
              description: "Closing the lid won't suspend the laptop."
            }
            SettingToggle {
              key: "lidLock"
              label: "Lock when lid closes"
              description: "Off keeps the session unlocked so apps stay active."
            }
          }

          // ---------- Mouse ----------
          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            SectionTitle { text: "MOUSE MOVEMENT" }

            SettingToggle {
              key: "mouse"
              label: "Move the mouse"
              description: "Nudge the cursor so apps don't show you as away."
            }

            Column {
              width: parent.width
              spacing: Style.space(8)
              enabled: !!root.s.mouse
              opacity: enabled ? 1 : 0.45

              SectionTitle {
                text: "EVERY"
                value: root.formatSeconds(intervalSlider.dragging
                  ? root.intervalStops[Math.round(intervalSlider.liveValue)]
                  : (root.s.interval || 60))
              }
              PanelSlider {
                id: intervalSlider
                bar: root.bar
                width: parent.width - Style.space(12)
                x: Style.space(6)
                minimum: 0
                maximum: root.intervalStops.length - 1
                step: 1
                integer: true
                tickCount: root.intervalStops.length
                value: root.nearestStop(root.s.interval || 60)
                onReleased: function(v) { root.setSetting("interval", root.intervalStops[Math.round(v)]) }
              }

              SectionTitle {
                text: "DISTANCE"
                value: Math.round(distanceSlider.dragging ? distanceSlider.liveValue : (root.s.distance || 1)) + " px"
              }
              PanelSlider {
                id: distanceSlider
                bar: root.bar
                width: parent.width - Style.space(12)
                x: Style.space(6)
                minimum: 1
                maximum: 50
                step: 1
                integer: true
                value: root.s.distance || 1
                onReleased: function(v) { root.setSetting("distance", Math.round(v)) }
              }

              SectionTitle { text: "SPEED" }
              ButtonGroup {
                options: [
                  { value: "instant", label: "Instant", tooltip: "Jump there and back" },
                  { value: "smooth", label: "Smooth", tooltip: "Short glide" },
                  { value: "slow", label: "Slow", tooltip: "Slow, visible glide" }
                ]
                value: root.s.speed || "instant"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: function(v) { root.setSetting("speed", v) }
              }

              SectionTitle { text: "PATTERN" }
              ButtonGroup {
                options: [
                  { value: "nudge", label: "Nudge", tooltip: "Right and back" },
                  { value: "random", label: "Random", tooltip: "A random direction and back" },
                  { value: "circle", label: "Square", tooltip: "A small square ending where it started" }
                ]
                value: root.s.pattern || "nudge"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: function(v) { root.setSetting("pattern", v) }
              }

              Button {
                text: "Test movement now"
                iconText: "󰍽"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.run(["test"])
              }
            }
          }

          // ---------- Auto off ----------
          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            SectionTitle { text: "TURN OFF AFTER" }
            ButtonGroup {
              options: root.autoOffOptions
              value: String(root.s.autoOff || 0)
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onChanged: function(v) { root.setSetting("autoOff", Number(v)) }
            }

            SectionTitle { text: "TURN OFF ON BATTERY BELOW" }
            ButtonGroup {
              options: root.batteryOptions
              value: String(root.s.minBattery || 0)
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onChanged: function(v) { root.setSetting("minBattery", Number(v)) }
            }
            SubLabel {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Protects the battery when the lid is closed in a bag."
            }
          }

          // ---------- Other ----------
          PanelSeparator { foreground: root.foreground }

          SettingToggle {
            key: "notify"
            label: "Notifications"
            description: "Show a notification when Stay Awake turns on or off."
          }
        }
      }
    }
  }
}
