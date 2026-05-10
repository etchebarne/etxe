import QtQuick

Item {
    id: progressScreen

    property var messages: []
    property int messageIndex: 0
    property alias messageOpacity: installText.opacity
    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"

    Text {
        id: installText

        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 640)
        text: progressScreen.messages.length > progressScreen.messageIndex ? progressScreen.messages[progressScreen.messageIndex] : ""
        color: progressScreen.fg
        font.family: progressScreen.uiFont
        font.pixelSize: 28
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        lineHeight: 1.2

        Behavior on opacity {
            NumberAnimation {
                duration: 650
                easing.type: Easing.InOutQuad
            }

        }

    }

}
