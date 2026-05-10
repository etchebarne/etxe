import QtQuick

Rectangle {
    id: navButton

    property string text
    property bool primary: true
    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"
    property color stroke: "#3a3a3a"

    signal clicked()

    height: 40
    radius: 10
    color: primary ? (enabled ? "#ffffff" : "#7a7a7a") : "#000000"
    border.color: primary ? color : stroke
    opacity: enabled ? 1 : 0.45

    Text {
        anchors.centerIn: parent
        text: navButton.text
        color: navButton.primary ? "#111111" : navButton.fg
        font.family: navButton.uiFont
        font.pixelSize: 19
        font.weight: Font.Normal
    }

    MouseArea {
        anchors.fill: parent
        enabled: navButton.enabled
        cursorShape: Qt.ArrowCursor
        onClicked: navButton.clicked()
    }

}
