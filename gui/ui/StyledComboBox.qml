import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ComboBox {
    id: combo

    property string currentValueText: ""
    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"
    property color muted: "#9a9a9a"
    property color stroke: "#3a3a3a"
    property color fieldBg: "#020202"

    signal valuePicked(string value)

    height: 46
    implicitHeight: 46
    Layout.preferredHeight: 46
    leftPadding: 10
    rightPadding: 42
    topPadding: 0
    bottomPadding: 0
    textRole: "label"
    valueRole: "value"
    font.family: uiFont
    font.pixelSize: 20
    Component.onCompleted: {
        var index = indexOfValue(currentValueText);
        currentIndex = index >= 0 ? index : 0;
        if (currentValue !== undefined)
            valuePicked(currentValue);

    }
    onActivated: valuePicked(currentValue)

    background: Rectangle {
        radius: 10
        color: combo.fieldBg
        border.color: combo.activeFocus ? "#ffffff" : combo.stroke
        border.width: 1
    }

    contentItem: Text {
        leftPadding: combo.leftPadding
        rightPadding: combo.rightPadding
        text: combo.displayText
        color: combo.fg
        font.family: combo.uiFont
        font.pixelSize: 20
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: combo.width - width - 16
        y: combo.topPadding + (combo.availableHeight - height) / 2
        text: "v"
        color: combo.muted
        font.family: combo.uiFont
        font.pixelSize: 18
    }

    delegate: ItemDelegate {
        width: combo.width
        height: 38
        highlighted: combo.highlightedIndex === index

        background: Rectangle {
            color: highlighted ? "#1c1c1c" : "#000000"
        }

        contentItem: Text {
            text: modelData.label
            color: combo.fg
            font.family: combo.uiFont
            font.pixelSize: 16
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

    }

    popup: Popup {
        y: combo.height + 8
        width: combo.width
        implicitHeight: Math.min(contentItem.implicitHeight, 320)
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: combo.popup.visible ? combo.delegateModel : null
            currentIndex: combo.highlightedIndex

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

        }

        background: Rectangle {
            radius: 10
            color: "#000000"
            border.color: combo.stroke
        }

    }

}
