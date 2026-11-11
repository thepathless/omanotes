import QtQuick 6.11
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omanotes"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "📝"
    foreground: root.bar ? root.bar.barForeground : Color.foreground
    fontSize: Style.font.body * 1.4
    tooltipText: "OmaNotes"
    fixedWidth: root.bar && root.bar.vertical ? -1 : Style.space(27)
    fixedHeight: root.bar && root.bar.vertical ? Style.space(26) : -1
    onPressed: function(b) {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle omanotes")
    }
  }
}
