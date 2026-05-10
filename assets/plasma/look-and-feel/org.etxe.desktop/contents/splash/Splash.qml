import QtQuick

Rectangle {
    id: root

    property int stage: 0

    color: "#0b0b0f"

    Image {
        id: logo

        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
        height: width * 125 / 79
        smooth: true
        source: "images/etxe-icon.svg"
        sourceSize.height: 172
        sourceSize.width: 108
        width: Math.min(parent.width * 0.18, parent.height * 0.24 * 79 / 125, 108)
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: 40
        color: "#2a2a31"
        height: 2
        radius: 1
        width: Math.min(root.width * 0.28, 160)

        Rectangle {
            color: "#ffffff"
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.min(root.stage / 6, 1)

            Behavior on width {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
