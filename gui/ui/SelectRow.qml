import QtQuick
import QtQuick.Layouts

Rectangle {
    id: selectRow

    property string text
    property bool selected: false
    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"
    property color stroke: "#3a3a3a"

    signal clicked()

    height: 48
    implicitHeight: 48
    Layout.preferredHeight: 48
    radius: 9
    color: "#000000"
    border.color: selected ? "#ffffff" : stroke
    border.width: 1

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 17
            height: 17
            radius: 9
            color: "#000000"
            border.color: "#ffffff"
            border.width: 1

            Rectangle {
                anchors.centerIn: parent
                visible: selectRow.selected
                width: 7
                height: 7
                radius: 4
                color: "#ffffff"
            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40
            text: selectRow.text
            color: selectRow.fg
            font.family: selectRow.uiFont
            font.pixelSize: 20
            elide: Text.ElideRight
        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onClicked: selectRow.clicked()
    }

}
