import QtQuick 6.11

// Eight invisible grab strips around the card. Each reports its edge
// (-1 / 0 / 1 per axis) and the pointer position in scene coordinates so the
// panel can resize without caring that the window moves under the cursor.
Item {
  id: root

  property int edgeSize: 8
  property bool handlesEnabled: true

  signal resizeBegan(int edgeX, int edgeY, real sceneX, real sceneY)
  signal resizeMoved(real sceneX, real sceneY)
  signal resizeEnded()

  readonly property int grab: Math.max(4, edgeSize)
  readonly property int corner: Math.round(grab * 1.5)

  function begin(edgeX, edgeY, handler) {
    root.resizeBegan(edgeX, edgeY, handler.centroid.scenePosition.x, handler.centroid.scenePosition.y)
  }

  function move(handler) {
    if (handler.active) root.resizeMoved(handler.centroid.scenePosition.x, handler.centroid.scenePosition.y)
  }

  Item {
    x: 0
    y: root.corner
    width: root.grab
    height: Math.max(0, root.height - root.corner * 2)
    enabled: root.handlesEnabled
    HoverHandler { cursorShape: Qt.SizeHorCursor }
    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      onActiveChanged: if (active) root.begin(-1, 0, this)
      onCentroidChanged: root.move(this)
    }
  }

  Item {
    x: root.width - root.grab
    y: root.corner
    width: root.grab
    height: Math.max(0, root.height - root.corner * 2)
    enabled: root.handlesEnabled
    HoverHandler { cursorShape: Qt.SizeHorCursor }
    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      onActiveChanged: if (active) root.begin(1, 0, this)
      onCentroidChanged: root.move(this)
    }
  }

  Item {
    x: root.corner
    y: 0
    width: Math.max(0, root.width - root.corner * 2)
    height: root.grab
    enabled: root.handlesEnabled
    HoverHandler { cursorShape: Qt.SizeVerCursor }
    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      onActiveChanged: if (active) root.begin(0, -1, this)
      onCentroidChanged: root.move(this)
    }
  }

  Item {
    x: root.corner
    y: root.height - root.grab
    width: Math.max(0, root.width - root.corner * 2)
    height: root.grab
    enabled: root.handlesEnabled
    HoverHandler { cursorShape: Qt.SizeVerCursor }
    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      onActiveChanged: if (active) root.begin(0, 1, this)
      onCentroidChanged: root.move(this)
    }
  }

  Item {
    x: 0
    y: 0
    width: root.corner
    height: root.corner
    z: 2
    enabled: root.handlesEnabled
    HoverHandler { cursorShape: Qt.SizeFDiagCursor }
    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      onActiveChanged: if (active) root.begin(-1, -1, this)
      onCentroidChanged: root.move(this)
    }
  }

  Item {
    x: root.width - root.corner
    y: 0
    width: root.corner
    height: root.corner
    z: 2
    enabled: root.handlesEnabled
    HoverHandler { cursorShape: Qt.SizeBDiagCursor }
    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      onActiveChanged: if (active) root.begin(1, -1, this)
      onCentroidChanged: root.move(this)
    }
  }

  Item {
    x: 0
    y: root.height - root.corner
    width: root.corner
    height: root.corner
    z: 2
    enabled: root.handlesEnabled
    HoverHandler { cursorShape: Qt.SizeBDiagCursor }
    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      onActiveChanged: if (active) root.begin(-1, 1, this)
      onCentroidChanged: root.move(this)
    }
  }

  Item {
    x: root.width - root.corner
    y: root.height - root.corner
    width: root.corner
    height: root.corner
    z: 2
    enabled: root.handlesEnabled
    HoverHandler { cursorShape: Qt.SizeFDiagCursor }
    DragHandler {
      target: null
      acceptedButtons: Qt.LeftButton
      onActiveChanged: if (active) root.begin(1, 1, this)
      onCentroidChanged: root.move(this)
    }
  }
}
