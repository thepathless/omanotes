import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick 6.11
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool settingsOpen: false

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string pluginDir: homeDir + "/.config/omarchy/plugins/omanotes"
  readonly property string stateDir: homeDir + "/.local/state/omarchy/omanotes"
  readonly property string notesPath: stateDir + "/notes.txt"
  readonly property string settingsPath: stateDir + "/settings.json"

  property int fontSize: 14
  property string position: "top-left"
  property string keybind: "SUPER + R"
  property bool stayOnTop: false
  property bool settingsLoaded: false

  property string barPosition: "top"

  property bool recording: false
  property string pendingCombo: ""
  property string recordError: ""
  property string applyStatus: ""
  property string applyError: ""

  property color noteBackground: Color.menu.background
  property int _startWidth: 0
  property int _startHeight: 0
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int cardWidth: Style.space(340)
  property int cardHeight: Style.space(420)
  readonly property int gap: Style.gapsOut

  function open(payloadJson) {
    root.opened = true
    root.settingsOpen = false
    root.stayOnTop = false
    Qt.callLater(function() { textArea.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.recording = false
  }

  function dismiss() {
    root.opened = false
    root.recording = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "omanotes")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  FileView {
    id: notesFile
    path: root.notesPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: textArea.text = text()
  }

  Timer {
    id: saveTimer
    interval: 400
    repeat: false
    onTriggered: notesFile.setText(textArea.text)
  }

  Process {
    id: ensureDirsProc
    command: ["mkdir", "-p", root.stateDir]
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
  }

  FileView {
    id: barConfigFile
    path: root.homeDir + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadBarPosition(text())
    onFileChanged: reload()
  }

  function loadBarPosition(json) {
    try {
      var parsed = JSON.parse(json || "{}")
      var pos = parsed.bar && parsed.bar.position
      if (pos === "top" || pos === "bottom" || pos === "left" || pos === "right")
        root.barPosition = pos
    } catch (e) {
    }
  }

  Timer {
    id: settingsSaveTimer
    interval: 200
    repeat: false
    onTriggered: root.flushSettings()
  }

  function loadSettings(json) {
    var parsed = {}
    try { parsed = JSON.parse(json || "{}") } catch (e) { parsed = {} }
    if (typeof parsed.fontSize === "number") root.fontSize = parsed.fontSize
    if (typeof parsed.position === "string") root.position = parsed.position
    if (typeof parsed.keybind === "string") root.keybind = parsed.keybind
    if (typeof parsed.cardWidth === "number") root.cardWidth = parsed.cardWidth
    if (typeof parsed.cardHeight === "number") root.cardHeight = parsed.cardHeight
    if (typeof parsed.noteBackground === "string") root.noteBackground = parsed.noteBackground
    root.settingsLoaded = true
  }

  function scheduleSettingsSave() {
    if (root.settingsLoaded) settingsSaveTimer.restart()
  }

  function flushSettings() {
    settingsFile.setText(JSON.stringify({
      fontSize: root.fontSize,
      position: root.position,
      keybind: root.keybind,
      cardWidth: root.cardWidth,
      cardHeight: root.cardHeight,
      noteBackground: root.noteBackground.toString()
    }, null, 2) + "\n")
  }

  onFontSizeChanged: scheduleSettingsSave()
  onPositionChanged: scheduleSettingsSave()
  onKeybindChanged: scheduleSettingsSave()
  onCardWidthChanged: scheduleSettingsSave()
  onCardHeightChanged: scheduleSettingsSave()
  onNoteBackgroundChanged: scheduleSettingsSave()

  Component.onCompleted: {
    ensureDirsProc.running = true
    Qt.callLater(function() { settingsFile.reload() })
  }

  function setFontSize(size) {
    root.fontSize = Math.max(10, Math.min(28, size))
  }

  function setCardWidth(width) {
    root.cardWidth = Math.max(220, Math.min(900, width))
  }

  function setCardHeight(height) {
    root.cardHeight = Math.max(200, Math.min(900, height))
  }

  function setPosition(pos) {
    root.position = pos
  }

  function setNoteBackground(color) {
    root.noteBackground = color
  }

  function toggleBold() {
    var f = textArea.cursorSelection.font
    f.bold = !f.bold
    textArea.cursorSelection.font = f
  }

  function toggleItalic() {
    var f = textArea.cursorSelection.font
    f.italic = !f.italic
    textArea.cursorSelection.font = f
  }

  function toggleUnderline() {
    var f = textArea.cursorSelection.font
    f.underline = !f.underline
    textArea.cursorSelection.font = f
  }

  function changeSelectionSize(delta) {
    var f = textArea.cursorSelection.font
    f.pixelSize = Math.max(8, Math.min(40, f.pixelSize + delta))
    textArea.cursorSelection.font = f
  }

  function isNoteBackground(value) {
    var a = root.noteBackground
    var b = (typeof value === "string") ? value : value.toString()
    // Compare ignoring alpha prefix differences (#aarrggbb vs #rrggbb).
    var sa = a.toString().toLowerCase()
    var sb = b.toLowerCase()
    if (sa === sb) return true
    if (sa.length === 9 && sb.length === 7 && sa.substring(3) === sb.substring(1)) return true
    if (sb.length === 9 && sa.length === 7 && sb.substring(3) === sa.substring(1)) return true
    return false
  }

  function beginRecording() {
    root.recording = true
    root.recordError = ""
    root.pendingCombo = ""
    root.applyStatus = ""
    Qt.callLater(function() { recorder.forceActiveFocus() })
  }

  function cancelRecording() {
    root.recording = false
    root.recordError = ""
    root.pendingCombo = ""
  }

  function isBareModifier(key) {
    return key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Meta
      || key === Qt.Key_Control || key === Qt.Key_Shift || key === Qt.Key_Alt || key === Qt.Key_AltGr
  }

  function hyprKeyName(key) {
    if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
    if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
    if (key >= Qt.Key_F1 && key <= Qt.Key_F12) return "F" + (key - Qt.Key_F1 + 1)
    var names = {}
    names[Qt.Key_Space] = "SPACE"
    names[Qt.Key_Return] = "RETURN"
    names[Qt.Key_Enter] = "RETURN"
    names[Qt.Key_Escape] = "ESCAPE"
    names[Qt.Key_Tab] = "TAB"
    names[Qt.Key_Backspace] = "BACKSPACE"
    names[Qt.Key_Delete] = "Delete"
    names[Qt.Key_Home] = "Home"
    names[Qt.Key_End] = "End"
    names[Qt.Key_PageUp] = "PageUp"
    names[Qt.Key_PageDown] = "PageDown"
    names[Qt.Key_Left] = "left"
    names[Qt.Key_Right] = "right"
    names[Qt.Key_Up] = "up"
    names[Qt.Key_Down] = "down"
    names[Qt.Key_Comma] = "comma"
    names[Qt.Key_Period] = "period"
    names[Qt.Key_Minus] = "minus"
    names[Qt.Key_Equal] = "equal"
    names[Qt.Key_Slash] = "slash"
    names[Qt.Key_Backslash] = "backslash"
    names[Qt.Key_Semicolon] = "semicolon"
    names[Qt.Key_Apostrophe] = "apostrophe"
    names[Qt.Key_BracketLeft] = "bracketleft"
    names[Qt.Key_BracketRight] = "bracketright"
    names[Qt.Key_QuoteLeft] = "grave"
    return names[key] || ""
  }

  function handleRecordKey(event) {
    if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
      root.cancelRecording()
      event.accepted = true
      return
    }
    if (root.isBareModifier(event.key)) {
      event.accepted = true
      return
    }

    var mods = []
    if (event.modifiers & Qt.MetaModifier) mods.push("SUPER")
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
    if (event.modifiers & Qt.AltModifier) mods.push("ALT")
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")

    var keyStr = root.hyprKeyName(event.key)
    if (keyStr === "") {
      root.recordError = "Unsupported key — try a letter, digit, F-key, arrow, or punctuation key."
      event.accepted = true
      return
    }
    if (mods.length === 0) {
      root.recordError = "Add a modifier (Super/Ctrl/Alt/Shift) — a bare key would break typing everywhere."
      event.accepted = true
      return
    }
    if (mods.length > 1) {
      root.recordError = "Use exactly one modifier — combos with two or more fail to apply on this system."
      event.accepted = true
      return
    }

    root.recordError = ""
    root.pendingCombo = mods.join(" ") + " + " + keyStr
    event.accepted = true
  }

  function confirmRecording() {
    if (root.pendingCombo === "") return
    root.applyStatus = "applying"
    root.applyError = ""
    keybindProc.command = ["bash", root.pluginDir + "/set-keybind.sh", root.pendingCombo]
    keybindProc.running = true
  }

  Process {
    id: keybindProc
    stdout: StdioCollector { id: keybindStdout; waitForEnd: true }
    stderr: StdioCollector { id: keybindStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.keybind = root.pendingCombo
        root.applyStatus = ""
        root.recording = false
        root.pendingCombo = ""
      } else {
        root.applyStatus = "error"
        root.applyError = (keybindStderr.text || "").trim() || "Failed to apply keybind"
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors {
      top: root.position === "top-left" || root.position === "top-right"
      bottom: root.position === "bottom-left" || root.position === "bottom-right"
      left: root.position === "top-left" || root.position === "bottom-left"
      right: root.position === "top-right" || root.position === "bottom-right"
    }
    readonly property bool dockedTop: root.position === "top-left" || root.position === "top-right"
    readonly property bool dockedBottom: root.position === "bottom-left" || root.position === "bottom-right"
    readonly property bool dockedLeft: root.position === "top-left" || root.position === "bottom-left"
    readonly property bool dockedRight: root.position === "top-right" || root.position === "bottom-right"
    margins.top: (dockedTop && root.barPosition === "top") ? Style.bar.sizeHorizontal + root.gap : root.gap
    margins.bottom: (dockedBottom && root.barPosition === "bottom") ? Style.bar.sizeHorizontal + root.gap : root.gap
    margins.left: (dockedLeft && root.barPosition === "left") ? Style.bar.sizeVertical + root.gap : root.gap
    margins.right: (dockedRight && root.barPosition === "right") ? Style.bar.sizeVertical + root.gap : root.gap
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight
    color: "transparent"
    WlrLayershell.namespace: "omanotes"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    HyprlandFocusGrab {
      active: root.opened && !root.stayOnTop
      windows: [panel]
      onCleared: root.dismiss()
    }

    BorderSurface {
      id: card
      anchors.fill: parent
      radius: root.cornerRadius
      color: root.noteBackground
      borderSpec: root.borderSpec
      padding: root.contentMargin

      Item {
        id: content
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Row {
          id: toolbarRow
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: headerRow.left
          anchors.rightMargin: Style.spacing.sm
          spacing: Style.spacing.xs
          z: 2

          PanelActionButton {
            iconText: "B"
            foreground: root.foreground
            tooltipText: "Bold"
            onClicked: root.toggleBold()
          }
          PanelActionButton {
            iconText: "I"
            foreground: root.foreground
            tooltipText: "Italic"
            onClicked: root.toggleItalic()
          }
          PanelActionButton {
            iconText: "U"
            foreground: root.foreground
            tooltipText: "Underline"
            onClicked: root.toggleUnderline()
          }
          PanelActionButton {
            iconText: "A-"
            foreground: root.foreground
            tooltipText: "Decrease selection font size"
            onClicked: root.changeSelectionSize(-1)
          }
          PanelActionButton {
            iconText: "A+"
            foreground: root.foreground
            tooltipText: "Increase selection font size"
            onClicked: root.changeSelectionSize(1)
          }
        }

        ScrollView {
          visible: !root.settingsOpen
          anchors.fill: parent
          anchors.topMargin: toolbarRow.height + Style.spacing.sm
          anchors.rightMargin: headerRow.width + Style.spacing.sm
          clip: true

          TextArea {
            id: textArea
            textFormat: TextEdit.RichText
            wrapMode: TextArea.Wrap
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            color: root.foreground
            selectionColor: Style.selectionFillFor(root.foreground, Color.accent)
            selectedTextColor: root.foreground
            placeholderText: "Scratchpad…"
            placeholderTextColor: Qt.darker(root.foreground, 1.6)
            background: Item {}

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.dismiss()
                event.accepted = true
              }
            }

            onTextChanged: saveTimer.restart()
          }
        }

        Flickable {
          visible: root.settingsOpen
          anchors.fill: parent
          anchors.rightMargin: headerRow.width + Style.spacing.sm
          contentWidth: width
          contentHeight: settingsColumn.implicitHeight
          clip: true

          Column {
            id: settingsColumn
            width: parent.width
            spacing: Style.spacing.lg

            Column {
              width: parent.width
              spacing: Style.spacing.xs

              Text {
                textFormat: Text.PlainText
                text: "Font size"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Row {
                spacing: Style.spacing.sm

                PanelActionButton {
                  iconText: "−"
                  foreground: root.foreground
                  onClicked: root.setFontSize(root.fontSize - 1)
                }

                Text {
                  textFormat: Text.PlainText
                  text: root.fontSize + "px"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                PanelActionButton {
                  iconText: "+"
                  foreground: root.foreground
                  onClicked: root.setFontSize(root.fontSize + 1)
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.spacing.xs

              Text {
                textFormat: Text.PlainText
                text: "Size"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Row {
                spacing: Style.spacing.sm

                PanelActionButton {
                  iconText: "−"
                  foreground: root.foreground
                  onClicked: root.setCardWidth(root.cardWidth - 20)
                }

                Text {
                  textFormat: Text.PlainText
                  text: "W " + root.cardWidth
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                PanelActionButton {
                  iconText: "+"
                  foreground: root.foreground
                  onClicked: root.setCardWidth(root.cardWidth + 20)
                }
              }

              Row {
                spacing: Style.spacing.sm

                PanelActionButton {
                  iconText: "−"
                  foreground: root.foreground
                  onClicked: root.setCardHeight(root.cardHeight - 20)
                }

                Text {
                  textFormat: Text.PlainText
                  text: "H " + root.cardHeight
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                PanelActionButton {
                  iconText: "+"
                  foreground: root.foreground
                  onClicked: root.setCardHeight(root.cardHeight + 20)
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.spacing.xs

            Column {
              width: parent.width
              spacing: Style.spacing.xs

              Text {
                textFormat: Text.PlainText
                text: "Note background"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Row {
                spacing: Style.spacing.sm

                Repeater {
                  model: [Color.menu.background, "#fff7d6", "#ffe4e6", "#dbeafe", "#dcfce7", "#1f2937"]
                  delegate: Rectangle {
                    width: Style.space(22)
                    height: Style.space(22)
                    radius: Style.cornerRadius
                    color: modelData
                    border.width: 2
                    border.color: root.isNoteBackground(modelData) ? Color.accent : "transparent"
                    MouseArea {
                      anchors.fill: parent
                      onClicked: root.setNoteBackground(modelData)
                    }
                  }
                }
              }
            }

              Text {
                textFormat: Text.PlainText
                text: "Position"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Grid {
                columns: 2
                spacing: Style.spacing.sm

                Button {
                  text: "Top-left"
                  bordered: true
                  selected: root.position === "top-left"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.setPosition("top-left")
                }
                Button {
                  text: "Top-right"
                  bordered: true
                  selected: root.position === "top-right"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.setPosition("top-right")
                }
                Button {
                  text: "Bottom-left"
                  bordered: true
                  selected: root.position === "bottom-left"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.setPosition("bottom-left")
                }
                Button {
                  text: "Bottom-right"
                  bordered: true
                  selected: root.position === "bottom-right"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.setPosition("bottom-right")
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.spacing.xs

              Text {
                textFormat: Text.PlainText
                text: "Keybind"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Button {
                text: root.recording ? (root.pendingCombo !== "" ? root.pendingCombo : "Press keys…") : root.keybind
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.recording ? root.cancelRecording() : root.beginRecording()
              }

              Item {
                id: recorder
                width: 1
                height: 1
                focus: root.recording
                Keys.onPressed: function(event) { root.handleRecordKey(event) }
              }

              Text {
                textFormat: Text.PlainText
                visible: root.recording
                text: "Press a shortcut with one modifier (e.g. Super+T). Esc to cancel."
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                visible: root.recordError !== ""
                text: root.recordError
                color: Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
                width: parent.width
              }

              Row {
                visible: root.recording && root.pendingCombo !== ""
                spacing: Style.spacing.sm

                Button {
                  text: "Apply"
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.confirmRecording()
                }
                Button {
                  text: "Cancel"
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.cancelRecording()
                }
              }

              Text {
                textFormat: Text.PlainText
                visible: root.applyStatus === "applying"
                text: "Applying…"
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                textFormat: Text.PlainText
                visible: root.applyStatus === "error"
                text: "Failed: " + root.applyError
                color: Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
                width: parent.width
              }
            }
          }
        }

        Row {
          id: headerRow
          anchors.top: parent.top
          anchors.right: parent.right
          spacing: Style.spacing.xs

          Button {
            id: pinButton
            text: "Pin"
            bordered: true
            selected: root.stayOnTop
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            verticalPadding: Style.spacing.xs
            tooltipText: root.stayOnTop
              ? "Pinned — clicking elsewhere won't close it"
              : "Pin to stay open while using other windows"
            onClicked: root.stayOnTop = !root.stayOnTop
          }

          PanelActionButton {
            id: gearButton
            iconText: root.settingsOpen ? "✕" : "󰒓"
            tooltipText: root.settingsOpen ? "Back to notes" : "Settings"
            foreground: root.foreground
            onClicked: root.settingsOpen = !root.settingsOpen
          }
        }
      }

      Rectangle {
        id: resizeHandle
        width: Style.space(14)
        height: Style.space(14)
        z: 5
        color: "transparent"
        anchors.right: panel.dockedLeft ? parent.right : undefined
        anchors.left: panel.dockedRight ? parent.left : undefined
        anchors.bottom: panel.dockedTop ? parent.bottom : undefined
        anchors.top: panel.dockedBottom ? parent.top : undefined

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: "◢"
          color: Qt.darker(root.foreground, 1.6)
          font.pixelSize: Style.font.bodySmall
          rotation: (panel.dockedRight ? 180 : 0) + (panel.dockedBottom ? 180 : 0)
        }

        DragHandler {
          id: resizeDrag
          target: null
          onActiveChanged: {
            if (active) {
              root._startWidth = root.cardWidth
              root._startHeight = root.cardHeight
            }
          }
          onTranslationChanged: {
            var dx = translation.x
            var dy = translation.y
            if (panel.dockedRight) dx = -dx
            if (panel.dockedBottom) dy = -dy
            root.setCardWidth(root._startWidth + dx)
            root.setCardHeight(root._startHeight + dy)
          }
        }
      }
    }
  }
}
