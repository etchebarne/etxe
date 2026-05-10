import QtQuick

Item {
    id: successScreen

    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"
    property color stroke: "#3a3a3a"

    signal rebootRequested()

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 760)
        spacing: 22

        Text {
            width: parent.width
            text: "Your device will now restart,\nmake sure you remove the installation\ndevice once the screen goes black."
            color: successScreen.fg
            font.family: successScreen.uiFont
            font.pixelSize: 28
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.08
        }

        NavButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 112
            text: "Restart"
            primary: true
            uiFont: successScreen.uiFont
            fg: successScreen.fg
            stroke: successScreen.stroke
            onClicked: successScreen.rebootRequested()
        }

    }

}
