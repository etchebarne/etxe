import QtQuick
import QtQuick.Layouts

Item {
    id: questionScreen

    default property alias content: contentColumn.data
    property string title
    property bool showBack: true
    property bool showNext: true
    property bool canGoNext: true
    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"
    property color stroke: "#3a3a3a"

    signal previous()
    signal next()

    ColumnLayout {
        id: contentColumn

        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 720)
        spacing: 18

        Text {
            Layout.fillWidth: true
            text: questionScreen.title
            color: questionScreen.fg
            font.family: questionScreen.uiFont
            font.pixelSize: 28
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

    }

    NavButton {
        visible: questionScreen.showBack
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 24
        anchors.bottomMargin: 28
        width: 126
        text: "Previous"
        primary: false
        uiFont: questionScreen.uiFont
        fg: questionScreen.fg
        stroke: questionScreen.stroke
        onClicked: questionScreen.previous()
    }

    NavButton {
        visible: questionScreen.showNext
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 24
        anchors.bottomMargin: 28
        width: 92
        text: "Next"
        primary: true
        enabled: questionScreen.canGoNext
        uiFont: questionScreen.uiFont
        fg: questionScreen.fg
        stroke: questionScreen.stroke
        onClicked: questionScreen.next()
    }

}
