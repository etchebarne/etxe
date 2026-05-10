import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TextField {
    id: field

    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"
    property color stroke: "#3a3a3a"
    property color fieldBg: "#020202"

    height: 46
    implicitHeight: 46
    Layout.preferredHeight: 46
    color: fg
    placeholderTextColor: "#555555"
    selectedTextColor: "#000000"
    selectionColor: "#ffffff"
    font.family: uiFont
    font.pixelSize: 20
    leftPadding: 16
    rightPadding: 16
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: 10
        color: field.fieldBg
        border.color: field.activeFocus ? "#ffffff" : field.stroke
        border.width: 1
    }

}
