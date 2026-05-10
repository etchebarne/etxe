import QtQuick
import QtQuick.Controls

Item {
    id: failureScreen

    property string message: ""
    property string logText: ""
    property bool showDetails: false
    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"
    property color muted: "#9a9a9a"
    property color stroke: "#3a3a3a"

    signal toggleDetails()

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 760)
        spacing: 18

        Text {
            width: parent.width
            text: "Something went wrong."
            color: failureScreen.fg
            font.family: failureScreen.uiFont
            font.pixelSize: 30
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: failureScreen.message.length > 0 ? failureScreen.message : "Installation failed."
            color: failureScreen.muted
            font.family: failureScreen.uiFont
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        NavButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 168
            text: failureScreen.showDetails ? "Hide details" : "Show details"
            primary: false
            uiFont: failureScreen.uiFont
            fg: failureScreen.fg
            stroke: failureScreen.stroke
            onClicked: failureScreen.toggleDetails()
        }

        Rectangle {
            visible: failureScreen.showDetails
            width: parent.width
            height: 260
            radius: 12
            color: "#050505"
            border.color: failureScreen.stroke

            TextArea {
                anchors.fill: parent
                anchors.margins: 12
                readOnly: true
                text: failureScreen.logText
                color: failureScreen.fg
                font.family: "monospace"
                font.pixelSize: 12
                wrapMode: TextEdit.NoWrap

                background: Rectangle {
                    color: "transparent"
                }

            }

        }

    }

}
