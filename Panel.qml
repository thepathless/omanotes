import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick 6.11
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "NoteGeometry.js" as Geo
import "components" as NoteUi

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var bar: null
  property var anchorItem: null

  property bool opened: false
  property bool settingsOpen: false

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string pluginDir: homeDir + "/.config/omarchy/plugins/omanotes"
  readonly property string stateDir: homeDir + "/.local/state/omarchy/omanotes"
  readonly property string notesPath: stateDir + "/notes.txt"
  readonly property string settingsPath: stateDir + "/settings.json"

  property int fontSize: 14
  property string keybind: "SUPER + R"
  property bool stayOnTop: false
  property bool settingsLoaded: false

  readonly property int defaultCardWidth: Style.space(340)
  readonly property int defaultCardHeight: Style.space(420)
  readonly property int minCardWidth: Style.space(240)
  readonly property int minCardHeight: Style.space(220)
  property int cardWidth: defaultCardWidth
  property int cardHeight: defaultCardHeight
  property real freeX: 0
  property real freeY: 0
  property bool docked: true

  property string barPosition: "top"

  property bool recording: false
  property string pendingCombo: ""
  property string recordError: ""
  property string applyStatus: ""
  property string applyError: ""

  property color noteBackground: Color.menu.background
  readonly property bool lightBackground: Geo.isLightColor(root.noteBackground)
  readonly property color foreground: root.lightBackground ? "#20242c" : Color.menu.text
  readonly property color border: root.lightBackground ? Qt.rgba(0, 0, 0, 0.22) : Color.menu.border
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", root.border, Math.max(1, Style.space(2)))
  readonly property int cornerRadius: Style.cornerRadius
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int contentMargin: Style.spacing.panelPadding
  readonly property int gap: Style.gapsOut

  // Selection formatting state, mirrored from the TextArea so the toolbar
  // can show the same kind of active indicator as the Pin button.
  property bool selBold: false
  property bool selItalic: false
  property bool selUnderline: false

  property real _dragStartX: 0
  property real _dragStartY: 0
  property real _resizeStartX: 0
  property real _resizeStartY: 0
  property real _resizeStartW: 0
  property real _resizeStartH: 0
  property real _resizePressX: 0
  property real _resizePressY: 0
  property int _resizeEdgeX: 0
  property int _resizeEdgeY: 0

  readonly property var anchorWindow: (root.anchorItem && root.anchorItem.QsWindow) ? root.anchorItem.QsWindow.window : null
  readonly property var panelScreen: root.anchorWindow ? root.anchorWindow.screen : null
  readonly property real screenW: root.panelScreen ? root.panelScreen.width : 0
  readonly property real screenH: root.panelScreen ? root.panelScreen.height : 0
  readonly property string barPos: (root.bar && root.bar.position) ? root.bar.position : root.barPosition
  readonly property real barThickness: {
    if (!root.bar) return Style.bar.sizeHorizontal
    if (root.panelScreen && typeof root.bar.barSizeFor === "function") {
      var size = root.bar.barSizeFor(root.panelScreen.name)
      if (size > 0) return size
    }
    return Style.bar.sizeHorizontal
  }

  TransformWatcher {
    id: anchorWatcher
    a: root.anchorWindow ? root.anchorWindow.contentItem : null
    b: root.anchorItem
  }

  readonly property point anchorPoint: {
    anchorWatcher.transform
    if (!root.anchorItem || !root.anchorWindow) return Qt.point(0, 0)
    return root.anchorItem.mapToItem(root.anchorWindow.contentItem, 0, 0)
  }

  readonly property real windowX: root.docked ? root.dockedPos.x : root.freeX
  readonly property real windowY: root.docked ? root.dockedPos.y : root.freeY

  readonly property point dockedPos: Geo.dockedPosition({
    barPosition: root.barPos,
    barThickness: root.barThickness,
    screenWidth: root.screenW,
    screenHeight: root.screenH,
    gap: root.gap,
    hasAnchor: root.anchorItem !== null && root.anchorItem !== undefined,
    anchorX: root.anchorPoint.x,
    anchorY: root.anchorPoint.y,
    anchorWidth: root.anchorItem ? root.anchorItem.width : 0,
    anchorHeight: root.anchorItem ? root.anchorItem.height : 0,
    cardWidth: root.cardWidth,
    cardHeight: root.cardHeight
  })

  function open(payloadJson) {
    root.opened = true
    root.settingsOpen = false
    Qt.callLater(function() {
      textArea.forceActiveFocus()
      root.syncSelectionFormat()
    })
  }

  function close() {
    root.opened = false
    root.recording = false
    root.scheduleSettingsSave()
  }

  function closeForPopoutSwitch() {
    root.close()
  }

  function dismiss() {
    root.opened = false
    root.recording = false
    root.scheduleSettingsSave()
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
    if (typeof parsed.keybind === "string") root.keybind = parsed.keybind
    if (typeof parsed.cardWidth === "number") root.cardWidth = parsed.cardWidth
    if (typeof parsed.cardHeight === "number") root.cardHeight = parsed.cardHeight
    if (typeof parsed.noteBackground === "string") root.noteBackground = parsed.noteBackground
    if (typeof parsed.docked === "boolean") root.docked = parsed.docked
    if (typeof parsed.freeX === "number") root.freeX = parsed.freeX
    if (typeof parsed.freeY === "number") root.freeY = parsed.freeY
    root.settingsLoaded = true
  }

  function scheduleSettingsSave() {
    if (root.settingsLoaded) settingsSaveTimer.restart()
  }

  function flushSettings() {
    settingsFile.setText(JSON.stringify({
      fontSize: root.fontSize,
      keybind: root.keybind,
      cardWidth: root.cardWidth,
      cardHeight: root.cardHeight,
      noteBackground: root.noteBackground.toString(),
      docked: root.docked,
      freeX: Math.round(root.freeX),
      freeY: Math.round(root.freeY)
    }, null, 2) + "\n")
  }

  onFontSizeChanged: scheduleSettingsSave()
  onKeybindChanged: scheduleSettingsSave()
  onCardWidthChanged: scheduleSettingsSave()
  onCardHeightChanged: scheduleSettingsSave()
  onNoteBackgroundChanged: scheduleSettingsSave()
  onDockedChanged: scheduleSettingsSave()
  onFreeXChanged: scheduleSettingsSave()
  onFreeYChanged: scheduleSettingsSave()

  Component.onCompleted: {
    ensureDirsProc.running = true
    Qt.callLater(function() { settingsFile.reload() })
  }

  function setFontSize(size) {
    root.fontSize = Math.max(10, Math.min(28, size))
  }

  function setCardWidth(width) {
    root.cardWidth = Math.max(root.minCardWidth, Math.min(root.screenW > 0 ? root.screenW - root.gap * 2 : 900, width))
  }

  function setCardHeight(height) {
    root.cardHeight = Math.max(root.minCardHeight, Math.min(root.screenH > 0 ? root.screenH - root.gap * 2 : 900, height))
  }

  function setNoteBackground(color) {
    root.noteBackground = color
  }

  function restorePosition() {
    root.docked = true
    root.cardWidth = root.defaultCardWidth
    root.cardHeight = root.defaultCardHeight
    root.freeX = 0
    root.freeY = 0
    root.scheduleSettingsSave()
  }

  function syncSelectionFormat() {
    if (!textArea || !textArea.cursorSelection) return
    var f = textArea.cursorSelection.font
    root.selBold = f.bold === true
    root.selItalic = f.italic === true
    root.selUnderline = f.underline === true
  }

  function toggleBold() {
    var f = textArea.cursorSelection.font
    f.bold = !root.selBold
    textArea.cursorSelection.font = f
    root.syncSelectionFormat()
  }

  function toggleItalic() {
    var f = textArea.cursorSelection.font
    f.italic = !root.selItalic
    textArea.cursorSelection.font = f
    root.syncSelectionFormat()
  }

  function toggleUnderline() {
    var f = textArea.cursorSelection.font
    f.underline = !root.selUnderline
    textArea.cursorSelection.font = f
    root.syncSelectionFormat()
  }

  function changeSelectionSize(delta) {
    var f = textArea.cursorSelection.font
    var current = f.pixelSize > 0 ? f.pixelSize : root.fontSize
    f.pixelSize = Math.max(8, Math.min(40, current + delta))
    textArea.cursorSelection.font = f
    root.syncSelectionFormat()
  }

  function isNoteBackground(value) {
    var a = root.noteBackground
    var b = (typeof value === "string") ? value : value.toString()
    var sa = a.toString().toLowerCase()
    var sb = b.toLowerCase()
    if (sa === sb) return true
    if (sa.length === 9 && sb.length === 7 && sa.substring(3) === sb.substring(1)) return true
    if (sb.length === 9 && sa.length === 7 && sb.substring(3) === sa.substring(1)) return true
    return false
  }

  function beginMove(sceneX, sceneY) {
    root._dragStartX = root.docked ? root.dockedPos.x : root.freeX
    root._dragStartY = root.docked ? root.dockedPos.y : root.freeY
    root._resizePressX = sceneX
    root._resizePressY = sceneY
  }

  function updateMove(sceneX, sceneY) {
    root.docked = false
    root.freeX = Geo.clampX(root._dragStartX + sceneX - root._resizePressX, root.cardWidth, root.screenW, root.gap)
    root.freeY = Geo.clampY(root._dragStartY + sceneY - root._resizePressY, root.cardHeight, root.screenH, root.gap)
  }

  function beginResize(edgeX, edgeY, sceneX, sceneY) {
    root._resizeEdgeX = edgeX
    root._resizeEdgeY = edgeY
    root._resizeStartW = root.cardWidth
    root._resizeStartH = root.cardHeight
    root._resizeStartX = root.docked ? root.dockedPos.x : root.freeX
    root._resizeStartY = root.docked ? root.dockedPos.y : root.freeY
    root._resizePressX = sceneX
    root._resizePressY = sceneY
    if (root.docked) {
      root.freeX = root._resizeStartX
      root.freeY = root._resizeStartY
      root.docked = false
    }
  }

  function updateResize(sceneX, sceneY) {
    var dx = sceneX - root._resizePressX
    var dy = sceneY - root._resizePressY
    var w = root._resizeStartW
    var h = root._resizeStartH
    var x = root._resizeStartX
    var y = root._resizeStartY

    if (root._resizeEdgeX < 0) {
      w = root._resizeStartW - dx
      x = root._resizeStartX + dx
    } else if (root._resizeEdgeX > 0) {
      w = root._resizeStartW + dx
    }
    if (root._resizeEdgeY < 0) {
      h = root._resizeStartH - dy
      y = root._resizeStartY + dy
    } else if (root._resizeEdgeY > 0) {
      h = root._resizeStartH + dy
    }

    w = Math.max(root.minCardWidth, Math.min(root.screenW > 0 ? root.screenW - root.gap * 2 : 900, w))
    h = Math.max(root.minCardHeight, Math.min(root.screenH > 0 ? root.screenH - root.gap * 2 : 900, h))
    if (root._resizeEdgeX < 0) x = root._resizeStartX + root._resizeStartW - w
    if (root._resizeEdgeY < 0) y = root._resizeStartY + root._resizeStartH - h

    root.cardWidth = Math.round(w)
    root.cardHeight = Math.round(h)
    root.freeX = Geo.clampX(x, root.cardWidth, root.screenW, root.gap)
    root.freeY = Geo.clampY(y, root.cardHeight, root.screenH, root.gap)
  }

  function endResize() {
    root.scheduleSettingsSave()
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
    screen: root.panelScreen
    anchors.top: true
    anchors.left: true
    margins.left: Math.round(root.docked ? root.dockedPos.x : root.freeX)
    margins.top: Math.round(root.docked ? root.dockedPos.y : root.freeY)
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

      // Middle-drag on the note body moves the window. Middle only, so left
      // clicks, selection, and every control keep their normal behavior.
      MouseArea {
        id: moveArea
        anchors.fill: parent
        z: 40
        acceptedButtons: Qt.MiddleButton
        property bool dragging: false
        onPressed: function(mouse) {
          if (mouse.button !== Qt.MiddleButton) return
          dragging = true
          var p = moveArea.mapToItem(null, mouse.x, mouse.y)
          root.beginMove(root.windowX + p.x, root.windowY + p.y)
          mouse.accepted = true
        }
        onPositionChanged: function(mouse) {
          if (!dragging) return
          var p = moveArea.mapToItem(null, mouse.x, mouse.y)
          root.updateMove(root.windowX + p.x, root.windowY + p.y)
        }
        onReleased: dragging = false
        onCanceled: dragging = false
      }

      NoteUi.ResizeHandles {
        anchors.fill: parent
        z: 50
        handlesEnabled: root.opened
        onResizeBegan: function(edgeX, edgeY, sceneX, sceneY) { root.beginResize(edgeX, edgeY, sceneX, sceneY) }
        onResizeMoved: function(sceneX, sceneY) { root.updateResize(sceneX, sceneY) }
        onResizeEnded: root.endResize()
      }

      Item {
        id: content
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Item {
          id: topBar
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Math.max(toolbarRow.height, headerRow.height)

          Row {
            id: toolbarRow
            visible: !root.settingsOpen
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: headerRow.left
            anchors.rightMargin: Style.spacing.sm
            spacing: Style.spacing.xs
            z: 2

            PanelActionButton {
              iconText: "B"
              foreground: root.selBold ? Color.accent : root.foreground
              bordered: root.selBold
              tooltipText: "Bold"
              onClicked: root.toggleBold()
            }
            PanelActionButton {
              iconText: "I"
              foreground: root.selItalic ? Color.accent : root.foreground
              bordered: root.selItalic
              tooltipText: "Italic"
              onClicked: root.toggleItalic()
            }
            PanelActionButton {
              iconText: "U"
              foreground: root.selUnderline ? Color.accent : root.foreground
              bordered: root.selUnderline
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

          Row {
            id: headerRow
            anchors.top: parent.top
            anchors.right: parent.right
            spacing: Style.spacing.xs

            Button {
              id: pinButton
              text: root.stayOnTop ? "Pinned" : "Pin"
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
              onClicked: {
                root.settingsOpen = !root.settingsOpen
                if (!root.settingsOpen) Qt.callLater(function() { textArea.forceActiveFocus() })
              }
            }
          }
        }

        ScrollView {
          visible: !root.settingsOpen
          anchors.fill: parent
          anchors.topMargin: topBar.height + Style.spacing.sm
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
            placeholderTextColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
            background: Item {}

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.dismiss()
                event.accepted = true
              }
            }

            onTextChanged: {
              saveTimer.restart()
              root.syncSelectionFormat()
            }
            onCursorPositionChanged: root.syncSelectionFormat()
            onSelectionStartChanged: root.syncSelectionFormat()
            onSelectionEndChanged: root.syncSelectionFormat()
            onActiveFocusChanged: if (activeFocus) root.syncSelectionFormat()

            Connections {
              target: textArea.cursorSelection
              function onFontChanged() { root.syncSelectionFormat() }
            }
          }
        }

        Flickable {
          visible: root.settingsOpen
          anchors.fill: parent
          anchors.topMargin: topBar.height + Style.spacing.sm
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

              Button {
                text: "Restore position"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: root.restorePosition()
              }

              Text {
                textFormat: Text.PlainText
                text: "Docks under the bar icon and resets the default size."
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.6)
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
                width: parent.width
              }
            }

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
                  model: [Color.menu.background, "#f2e8d5", "#f0dada", "#dbe7f3", "#dcebdc", "#232833"]
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
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.6)
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
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.6)
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
      }
    }
  }
}
