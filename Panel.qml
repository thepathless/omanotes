import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick 6.11
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "NoteGeometry.js" as NoteGeometry
import "ResizeHandles.qml" as ResizeHandles

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // Host from the bar widget (section 1 of the plan).
  property var bar: null
  property var anchorItem: null

  property bool opened: false
  property bool settingsOpen: false
  property bool popoutSwitchClosing: false

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string pluginDir: homeDir + "/.config/omarchy/plugins/omanotes"
  readonly property string stateDir: homeDir + "/.local/state/omarchy/omanotes"
  readonly property string notesPath: stateDir + "/notes.txt"
  readonly property string settingsPath: stateDir + "/settings.json"

  // ---- Persisted state -------------------------------------------------
  property int fontSize: 14
  property string keybind: "SUPER + R"
  property bool stayOnTop: false
  property color noteBackground: Color.menu.background
  property int cardWidth: Style.space(340)
  property int cardHeight: Style.space(420)
  property int freeX: -1
  property int freeY: -1
  property bool docked: true

  readonly property int minCardWidth: Style.space(260)
  readonly property int minCardHeight: Style.space(180)

  // ---- Read-only convenience properties -------------------------------
  readonly property string stateFile: stateDir + "/settings.json"

  property int _startWidth: 0
  property int _startHeight: 0
  property color border: NoteGeometry.isLightColor(noteBackground) ? Color.text.selection : Color.menu.border
  property color foreground: NoteGeometry.isLightColor(noteBackground) ? Color.text.primary : Color.menu.text
  property color placeholderColor: NoteGeometry.isLightColor(noteBackground) ? Color.text.secondary : Qt.darker(Color.menu.text, 1.4)
  property color selectionColor: NoteGeometry.isLightColor(noteBackground) ? Color.highlight : Qt.darker(noteBackground, 0.75)
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  readonly property int gap: Style.gapsOut
  readonly property int barThickness: 36

  // ---- Active formatting from cursor/selection -----------------------
  property bool selBold: false
  property bool selItalic: false
  property bool selUnderline: false

  // ---- Defaults for restorePosition -----------------------------------
  readonly property int defaultCardWidth: Style.space(340)
  readonly property int defaultCardHeight: Style.space(420)

  // ---- Drag state for move + resize ---------------------------------
  property bool dragging: false
  property real dragStartX: 0
  property real dragStartY: 0
  property int dragStartFreeX: 0
  property int dragStartFreeY: 0
  property bool resizing: false
  property int resizeEdgeX: 0
  property int resizeEdgeY: 0
  property real resizeStartSceneX: 0
  property real resizeStartSceneY: 0
  property int resizeStartCardWidth: 0
  property int resizeStartCardHeight: 0
  property int resizeStartFreeX: 0
  property int resizeStartFreeY: 0

  // ---- Window item referenced from Window ---------------------------
  property Item windowItem: windowLoader.item

  // ---- The floating window ------------------------------------------
  Window {
    id: window
    width: root.cardWidth
    height: root.cardHeight
    x: root.docked ? dockedRect.x : root.freeX
    y: root.docked ? dockedRect.y : root.freeY
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    visibility: Window.Active
    layer.enabled: true
    layer.samples: 0
    exclusions.visibility: WindowExcludeVisibility.Active
    onXChanged: { if (!root.dragging && !root.resizing) root.syncPositionFromWindow() }
    onYChanged: { if (!root.dragging && !root.resizing) root.syncPositionFromWindow() }
    onWidthChanged: { if (!root.resizing) root.syncSizeFromWindow() }
    onHeightChanged: { if (!root.resizing) root.syncSizeFromWindow() }
    Component.onCompleted: {
      window.title = "OmaNotes"
      window.show()
    }
    onClosing: {
      root.popoutSwitchClosing = false
      root.closed()
    }
    property var _pendingX: 0
    property var _pendingY: 0
  }

  Loader {
    id: windowLoader
    source: window
    active: root.opened
  }

  // ---- Dock geometry (section 2) ------------------------------------
  readonly property rect dockedRect: NoteGeometry.dockedPosition({
    hasAnchor: root.anchorItem && root.bar,
    anchorX: root.anchorItem ? root.anchorItem.x : 0,
    anchorY: root.anchorItem ? root.anchorItem.y : 0,
    anchorWidth: root.anchorItem ? root.anchorItem.width : 0,
    anchorHeight: root.anchorItem ? root.anchorItem.height : 0,
    barPosition: root.barPosition,
    barThickness: root.barThickness,
    cardWidth: root.cardWidth,
    cardHeight: root.cardHeight,
    gap: root.gap,
    screenWidth: screenWidth,
    screenHeight: screenHeight,
  })

  readonly property int screenWidth: {
    var s = Qt.size(0, 0)
    try { s = screenTracking.screenSize } catch (_) {}
    return s.width > 0 ? s.width : 0
  }
  readonly property int screenHeight: {
    var s = Qt.size(0, 0)
    try { s = screenTracking.screenSize } catch (_) {}
    return s.height > 0 ? s.height : 0
  }

  Item {
    id: screenTracking
    // qmllint:disable-next-line unqualified-access
    property variant screenSize: Screen.size
  }

  function syncPositionFromWindow() {
    if (root.dragging || root.resizing) return
    var w = root.windowItem ? root.windowItem : window
    if (!w) return
    var nx = Math.round(w.x)
    var ny = Math.round(w.y)
    if (nx !== root.freeX || ny !== root.freeY) {
      root.freeX = nx
      root.freeY = ny
      root.docked = false
      root.scheduleSave()
    }
  }

  function syncSizeFromWindow() {
    if (root.resizing || root.dragging) return
    var w = root.windowItem ? root.windowItem : window
    if (!w) return
    var nw = Math.round(w.width)
    var nh = Math.round(w.height)
    if (nw !== root.cardWidth || nh !== root.cardHeight) {
      root.cardWidth = Math.max(root.minCardWidth, nw)
      root.cardHeight = Math.max(root.minCardHeight, nh)
      root.scheduleSave()
    }
  }

  // ---- Open / close / toggle (section 1 + 2) -----------------------
  function open(payloadJson) {
    root.opened = true
    root.settingsOpen = false
    root.stayOnTop = false
    root.popoutSwitchClosing = false
    root.bar = null
    root.anchorItem = null
    Qt.callLater(function() { textArea.forceActiveFocus() })
  }

  function close() {
    root.popoutSwitchClosing = false
    root.opened = false
  }

  function closeForPopoutSwitch() {
    root.popoutSwitchClosing = true
    root.opened = false
  }

  function toggle() {
    if (root.opened) {
      root.close()
    } else {
      root.open()
    }
  }

  function closed() {
    root.saveNow()
  }

  // ---- Geometry: docked vs free (section 2) ------------------------
  function setDocked() {
    root.docked = true
    root.freeX = -1
    root.freeY = -1
  }

  function restorePosition() {
    root.setDocked()
    root.cardWidth = root.defaultCardWidth
    root.cardHeight = root.defaultCardHeight
    Qt.callLater(function() {
      if (root.windowItem) {
        root.windowItem.x = root.dockedRect.x
        root.windowItem.y = root.dockedRect.y
        root.windowItem.width = root.defaultCardWidth
        root.windowItem.height = root.defaultCardHeight
      } else {
        window.x = root.dockedRect.x
        window.y = root.dockedRect.y
        window.width = root.defaultCardWidth
        window.height = root.defaultCardHeight
      }
      root.scheduleSave()
    })
  }

  // ---- Settings save (debounced) ------------------------------------
  property var _saveTimer: null
  function scheduleSave() {
    if (root._saveTimer) {
      clearTimeout(root._saveTimer)
      root._saveTimer = null
    }
    root._saveTimer = setTimeout(function() {
      root.saveNow()
      root._saveTimer = null
    }, 350)
  }

  function saveNow() {
    var s = root.readSettings()
    s.cardWidth = root.cardWidth
    s.cardHeight = root.cardHeight
    s.fontSize = root.fontSize
    s.noteBackground = root.noteBackground
    s.keybind = root.keybind
    s.stayOnTop = root.stayOnTop
    s.docked = root.docked
    s.freeX = root.freeX < 0 ? -1 : root.freeX
    s.freeY = root.freeY < 0 ? -1 : root.freeY
    Io.writeText(root.stateFile, JSON.stringify(s, null, 2))
  }

  // ---- Settings load + apply --------------------------------------- 
  function readSettings() {
    var raw = ""
    try { raw = Io.readText(root.stateFile) } catch (_) {}
    if (!raw || raw.trim() === "") return {}
    try { return JSON.parse(raw) } catch (_) { return {} }
  }

  function applySettings(s) {
    root.fontSize = s.fontSize != null ? s.fontSize : 14
    root.keybind = s.keybind || "SUPER + R"
    root.stayOnTop = !!s.stayOnTop
    root.noteBackground = s.noteBackground || Color.menu.background
    root.cardWidth = Math.max(root.minCardWidth, s.cardWidth || root.defaultCardWidth)
    root.cardHeight = Math.max(root.minCardHeight, s.cardHeight || root.defaultCardHeight)
    root.freeX = s.freeX != null && s.freeX >= 0 ? s.freeX : -1
    root.freeY = s.freeY != null && s.freeY >= 0 ? s.freeY : -1
    root.docked = s.docked === true ? false : true
    if (root.docked) {
      root.freeX = -1
      root.freeY = -1
    }
  }

  function loadSettings() {
    var s = root.readSettings()
    root.applySettings(s)
    root.settingsLoaded = true
  }

  // ---- Apply pending geometry changes to the window ----------------
  function applyPendingGeometry() {
    if (!root.opened) return
    var w = root.windowItem ? root.windowItem : window
    if (!w) return
    w.x = root.docked ? root.dockedRect.x : root.freeX
    w.y = root.docked ? root.dockedRect.y : root.freeY
    w.width = root.cardWidth
    w.height = root.cardHeight
  }

  // ---- Compose the UI ----------------------------------------------
  property Item card: cardRoot

  Item {
    id: cardRoot
    anchors.fill: parent
    property bool isNoteView: !root.settingsOpen
    property bool isSettingsView: root.settingsOpen

    // ---- Header row: Pin + gear -----------------------------------
    Row {
      id: headerRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: Style.space(36)
      spacing: Style.space(6)
      visible: root.opened

      PanelActionButton {
        id: pinButton
        text: root.pinned ? "Pinned" : "Pin"
        pressed: root.pinned
        selected: root.pinned
        bordered: root.pinned
        foreground: root.pinned ? Color.accent : undefined
        fill: parent
        onClicked: root.togglePin()
      }

      Item { width: Style.space(4) }

      PanelActionButton {
        id: settingsBtn
        icon: Icon.Cog
        fill: parent
        onClicked: root.toggleSettings()
      }
    }

    // ---- Toolbar row (note view only) ----------------------------
    Row {
      id: toolbarRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: headerRow.bottom
      height: Style.space(32)
      spacing: Style.space(4)
      visible: root.isNoteView && root.opened

      // Bold
      PanelActionButton {
        id: boldBtn
        icon: Icon.Bold
        active: root.selBold
        foreground: root.selBold ? Color.accent : undefined
        bordered: root.selBold
        fill: parent
        tooltipText: "Bold (Ctrl+B)"
        onClicked: textArea.executeCommand("font-weight", root.selBold ? "normal" : "bold")
        anchors.left: parent.left
        anchors.leftMargin: Style.space(2)
      }

      // Italic
      PanelActionButton {
        id: italicBtn
        icon: Icon.Italic
        active: root.selItalic
        foreground: root.selItalic ? Color.accent : undefined
        bordered: root.selItalic
        fill: parent
        tooltipText: "Italic (Ctrl+I)"
        onClicked: textArea.executeCommand("font-italic", root.selItalic ? "normal" : "italic")
        anchors.left: boldBtn.right
        anchors.leftMargin: Style.space(2)
      }

      // Underline
      PanelActionButton {
        id: underlineBtn
        icon: Icon.Underline
        active: root.selUnderline
        foreground: root.selUnderline ? Color.accent : undefined
        bordered: root.selUnderline
        fill: parent
        tooltipText: "Underline (Ctrl+U)"
        onClicked: textArea.executeCommand("font-underline", root.selUnderline ? "normal" : "underline")
        anchors.left: italicBtn.right
        anchors.leftMargin: Style.space(2)
      }

      Item { width: Style.space(4) }

      // A- / A+
      PanelActionButton {
        id: shrinkBtn
        icon: Icon.FontDecrease
        fill: parent
        tooltipText: "Decrease font size (Ctrl+-)"
        onClicked: root.adjustFontSize(-1)
        anchors.left: underlineBtn.right
        anchors.leftMargin: Style.space(2)
      }

      PanelActionButton {
        id: growBtn
        icon: Icon.FontIncrease
        fill: parent
        tooltipText: "Increase font size (Ctrl+=)"
        onClicked: root.adjustFontSize(1)
        anchors.left: shrinkBtn.right
        anchors.leftMargin: Style.space(2)
      }
    }

    // ---- Content region (clears header + toolbar) ----------------
    Item {
      id: contentRegion
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: toolbarRow.bottom
      anchors.bottom: parent.bottom
      visible: root.opened

      // ---- Resize handles (section 3) -----------------------------
      ResizeHandles {
        id: handles
        anchors.fill: parent
        handlesEnabled: !root.settingsOpen && root.opened
        onResizeBegan: function(ex, ey, sx, sy) {
          root.beginResize(ex, ey, sx, sy)
        }
        onResizeMoved: function(sx, sy) {
          root.updateResize(sx, sy)
        }
        onResizeEnded: root.endResize()
      }

      // ---- Middle-drag anywhere on the card (section 3) -----------
      MouseArea {
        id: moveArea
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        propagateComposedEvents: true
        onPressed: function(m) {
          if (!root.opened) return
          root.beginMove(m.button, m.x, m.y, m.sceneX, m.sceneY)
        }
        onReleased: function(m) {
          root.endMove(m.button)
        }
        onPositionChanged: function(m) {
          root.updateMove(m.sceneX, m.sceneY)
        }
      }

      // ---- Border surface under the content -----------------------
      BorderSurface {
        id: surface
        implicitWidth: parent.width
        implicitHeight: parent.height
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 0
        background: root.noteBackground
        border: root.borderSpec
        radius: root.cornerRadius
      }

      // ---- Text area ----------------------------------------------
      TextEdit {
        id: textArea
        anchors.fill: parent
        anchors.margins: root.contentMargin
        text: root.noteText
        readOnly: false
        font.family: root.fontFamily
        font.pointSize: root.fontSize
        cursorVisible: true
        selectByMouse: true
        wrapMode: TextEdit.Wrap
        background: null
        onTextChanged: root.noteText = textArea.text
        onCursorSelectionChanged: root.updateSelectionFormatting()
        Keys.onPressed: function(k) {
          if ((k.key === Qt.Key_B && (k.modifiers & Qt.ControlModifier)) ||
              (k.key === Qt.Key_I && (k.modifiers & Qt.ControlModifier)) ||
              (k.key === Qt.Key_U && (k.modifiers & Qt.ControlModifier))) {
            // Handled via executeCommand below
          }
          if ((k.key === Qt.Key_Minus && (k.modifiers & Qt.ControlModifier)) ||
              (k.key === Qt.Key_Underscore && (k.modifiers & Qt.ControlModifier))) {
            root.adjustFontSize(-1)
            k.accepted = true
          }
          if ((k.key === Qt.Key_Equal && (k.modifiers & Qt.ControlModifier)) ||
              (k.key === Qt.Key_Plus && (k.modifiers & Qt.ControlModifier))) {
            root.adjustFontSize(1)
            k.accepted = true
          }
        }
      }

      // ---- Placeholder when empty --------------------------------
      Text {
        id: placeholder
        anchors.fill: parent
        anchors.margins: root.contentMargin
        text: root.emptyNoteHint
        color: root.placeholderColor
        font.family: root.fontFamily
        font.pointSize: root.fontSize
        visible: textArea.text.length === 0 && !textArea.activeFocus
        z: 1
        readonly property string emptyNoteHint: qsTr("Start typing…")
      }
    }
  }

  // ---- Formatting indicator update (section 6) ---------------------
  function updateSelectionFormatting() {
    var f = textArea.cursorSelection.font
    root.selBold = f.bold === true
    root.selItalic = f.italic === true
    root.selUnderline = f.underline === true
  }

  // ---- Pin ---------------------------------------------
  property bool pinned: false
  property bool recording: false
  property string pendingCombo: ""
  property string recordError: ""
  function togglePin() {
    root.pinned = !root.pinned
    if (root.pinned) {
      root.stayOnTop = true
    }
    root.scheduleSave()
  }

  // ---- Settings panel (section 4) ---------------------------------
  Item {
    id: settingsPanel
    anchors.fill: parent
    visible: root.settingsOpen && root.opened
    property color accentFg: NoteGeometry.isLightColor(noteBackground) ? Color.menu.text : Color.accent
    property color accentBg: NoteGeometry.isLightColor(noteBackground) ? Color.highlight : Qt.darker(noteBackground, 0.85)

    Rectangle {
      anchors.fill: parent
      color: root.accentBg
      opacity: 0.15
      radius: root.cornerRadius
    }

    Column {
      anchors.fill: parent
      anchors.margins: root.contentMargin
      spacing: Style.space(8)

      Text {
        text: qsTr("Settings")
        font.pointSize: root.fontSize + 2
        font.bold: true
        color: root.foreground
      }

      Row {
        spacing: Style.space(10)
        // Font size
        Row {
          Text { text: qsTr("Font size:"); color: root.foreground }
          Slider {
            value: root.fontSize
            from: 10
            to: 32
            width: Style.space(140)
            onValueChanged: root.fontSize = Math.round(value)
          }
          Text {
            text: root.fontSize
            color: root.foreground
            width: Style.space(30)
            horizontalAlignment: Text.AlignRight
          }
        }

        // Note background color
        Row {
          Text { text: qsTr("Background:"); color: root.foreground }
          spacing: Style.space(6)
          // Swatches (section 5): muted palette
          Repeater {
            model: [
              { name: "Menu", color: Color.menu.background },
              { name: "Parchment", color: "#e9e2cf" },
              { name: "Dusty rose", color: "#c9a0a0" },
              { name: "Muted blue", color: "#9bb4c9" },
              { name: "Sage", color: "#a8b8a0" },
              { name: "Slate", color: "#8b95a3" },
            ]
            delegate: Rectangle {
              width: Style.space(22)
              height: Style.space(22)
              color: modelData.color
              radius: 4
              border.color: root.noteBackground === modelData.color ? Color.accent : "transparent"
              border.width: root.noteBackground === modelData.color ? 2 : 0
              visible: parent.visible
              MouseArea {
                anchors.fill: parent
                onClicked: root.noteBackground = modelData.color
              }
            }
          }
        }

        // Restore position button (section 4)
        Button {
          text: qsTr("Restore position")
          onClicked: root.restorePosition()
          highlighted: false
        }

        // Keybind
        Row {
          Text { text: qsTr("Keybind:"); color: root.foreground }
          Text {
            text: root.keybind
            color: root.foreground
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onPressed: function(m) {
                if (m.button === Qt.LeftButton) {
                  root.recording = true
                  root.pendingCombo = ""
                  root.recordError = ""
                } else if (m.button === Qt.RightButton) {
                  root.keybind = "SUPER + R"
                  root.recording = false
                  root.recordError = ""
                }
              }
            }
          }
        }

        // Recording feedback
        Text {
          text: root.recording ? qsTr("Press a key combo…") : (root.recordError || "")
          color: root.recordError ? Color.red : root.foreground
          visible: root.recording || root.recordError
        }

        // Apply / cancel
        Row {
          spacing: Style.space(8)
          Button {
            text: qsTr("Apply")
            onClicked: root.closeSettings()
          }
          Button {
            text: qsTr("Cancel")
            onClicked: root.closeSettings()
          }
        }
      }
    }
  }

  // ---- Settings view helpers --------------------------------------
  function toggleSettings() {
    root.settingsOpen = !root.settingsOpen
    if (root.settingsOpen) {
      root.loadSettings()
    }
  }

  function closeSettings() {
    root.settingsOpen = false
    root.saveNow()
  }

  // ---- Font size adjustment (toolbar A-/A+) ----------------------
  function adjustFontSize(delta) {
    root.fontSize = Math.max(10, Math.min(32, root.fontSize + delta))
    root.scheduleSave()
  }

  // ---- Middle-drag move (section 3) ------------------------------
  function beginMove(btn, x, y, sceneX, sceneY) {
    if (btn !== Qt.MiddleButton) return
    if (!root.opened) return
    root.dragging = true
    root.dragStartX = sceneX
    root.dragStartY = sceneY
    var w = root.windowItem ? root.windowItem : window
    root.dragStartFreeX = Math.round(w.x)
    root.dragStartFreeY = Math.round(w.y)
    root.setDocked = false
    root.docked = false
  }

  function updateMove(sceneX, sceneY) {
    if (!root.dragging) return
    var dx = sceneX - root.dragStartX
    var dy = sceneY - root.dragStartY
    var nx = NoteGeometry.clampX(root.dragStartFreeX + dx, root.cardWidth, root.screenWidth, root.gap)
    var ny = NoteGeometry.clampY(root.dragStartFreeY + dy, root.cardHeight, root.screenHeight, root.gap)
    var w = root.windowItem ? root.windowItem : window
    w.x = nx
    w.y = ny
  }

  function endMove(btn) {
    if (btn !== Qt.MiddleButton) return
    root.dragging = false
    root.syncPositionFromWindow()
  }

  // ---- Edge resize (section 3) -----------------------------------
  function beginResize(ex, ey, sx, sy) {
    if (!root.opened) return
    root.resizing = true
    root.resizeEdgeX = ex
    root.resizeEdgeY = ey
    root.resizeStartSceneX = sx
    root.resizeStartSceneY = sy
    var w = root.windowItem ? root.windowItem : window
    root.resizeStartCardWidth = w.width
    root.resizeStartCardHeight = w.height
    root.resizeStartFreeX = Math.round(w.x)
    root.resizeStartFreeY = Math.round(w.y)
    if (ex !== 0) {
      root.docked = false
      root.freeX = root.resizeStartFreeX
      root.freeY = root.resizeStartFreeY
    }
    if (ey !== 0) {
      root.docked = false
      root.freeX = root.resizeStartFreeX
      root.freeY = root.resizeStartFreeY
    }
  }

  function updateResize(sx, sy) {
    if (!root.resizing) return
    var w = root.windowItem ? root.windowItem : window
    var dx = sx - root.resizeStartSceneX
    var dy = sy - root.resizeStartSceneY
    var nw = root.resizeStartCardWidth
    var nh = root.resizeStartCardHeight
    var nx = root.resizeStartFreeX
    var ny = root.resizeStartFreeY
    if (root.resizeEdgeX < 0) { nw += dx; nx += dx }
    if (root.resizeEdgeX > 0) { nw -= dx }
    if (root.resizeEdgeY < 0) { nh += dy; ny += dy }
    if (root.resizeEdgeY > 0) { nh -= dy }
    nw = Math.max(root.minCardWidth, nw)
    nh = Math.max(root.minCardHeight, nh)
    nx = NoteGeometry.clampX(nx, nw, root.screenWidth, root.gap)
    ny = NoteGeometry.clampY(ny, nh, root.screenHeight, root.gap)
    w.width = nw
    w.height = nh
    w.x = nx
    w.y = ny
  }

  function endResize() {
    root.resizing = false
    root.syncSizeFromWindow()
    root.syncPositionFromWindow()
  }

  // ---- Misc -------------------------------------------------------
  readonly property string noteText: textArea.text
  readonly property bool emptyNoteHint: textArea.text.length === 0

  property string barPosition: "top"

  Component.onCompleted: {
    root.loadSettings()
    root.applyPendingGeometry()
  }

  Connections {
    target: root
    function onStayOnTopChanged() {
      if (root.stayOnTop) {
        window.flags |= Qt.StaysOnTopHint
      } else {
        window.flags &= ~Qt.StaysOnTopHint
      }
    }
  }

  // ---- IPC: omarchy-shell shell toggle ---------------------------
  function receiveOpen(payloadJson) {
    root.open(payloadJson)
  }
  function receiveClose() {
    root.close()
  }
  function receiveToggle() {
    root.toggle()
  }
}
