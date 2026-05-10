import QtQuick

Item {
    id: reviewScreen

    property string selectedDisk: ""
    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"
    property color stroke: "#3a3a3a"

    signal previous()
    signal installRequested()

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 560)
        spacing: 12

        Text {
            width: parent.width
            text: "All set! Ready to proceed?"
            color: reviewScreen.fg
            font.family: reviewScreen.uiFont
            font.pixelSize: 28
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: "Everything on " + reviewScreen.selectedDisk + " will be permanently erased."
            color: reviewScreen.fg
            font.family: reviewScreen.uiFont
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
        }

        NavButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 98
            text: "Install"
            primary: true
            uiFont: reviewScreen.uiFont
            fg: reviewScreen.fg
            stroke: reviewScreen.stroke
            onClicked: reviewScreen.installRequested()
        }

    }

    NavButton {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 24
        anchors.bottomMargin: 28
        width: 126
        text: "Previous"
        primary: false
        uiFont: reviewScreen.uiFont
        fg: reviewScreen.fg
        stroke: reviewScreen.stroke
        onClicked: reviewScreen.previous()
    }

}
