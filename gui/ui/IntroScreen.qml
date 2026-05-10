import QtQuick

Item {
    id: introScreen

    property bool active: false
    property int nextStep: -1
    property string text: ""
    property bool showIcon: false
    property string uiFont: "Red Hat Display"
    property color fg: "#f7f7f7"

    signal finished(int nextStep)

    function play() {
        introStartDelay.restart();
    }

    opacity: 0
    onActiveChanged: {
        if (active) {
            play();
        }
    }
    Component.onCompleted: {
        if (active) {
            play();
        }
    }

    Timer {
        id: introStartDelay

        interval: 80
        repeat: false
        onTriggered: introAnimation.restart()
    }

    SequentialAnimation {
        id: introAnimation

        NumberAnimation {
            target: introScreen
            property: "opacity"
            from: 0
            to: 1
            duration: 700
            easing.type: Easing.InOutQuad
        }

        PauseAnimation {
            duration: 5000
        }

        NumberAnimation {
            target: introScreen
            property: "opacity"
            to: 0
            duration: 700
            easing.type: Easing.InOutQuad
        }

        ScriptAction {
            script: {
                if (introScreen.active && introScreen.nextStep >= 0) {
                    introScreen.finished(introScreen.nextStep);
                }
            }
        }

    }

    Image {
        visible: introScreen.showIcon
        anchors.centerIn: parent
        width: 64
        height: 102
        source: "../../assets/brand/etxe-icon.svg"
        fillMode: Image.PreserveAspectFit
    }

    Text {
        visible: !introScreen.showIcon
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 640)
        text: introScreen.text
        color: introScreen.fg
        font.family: introScreen.uiFont
        font.pixelSize: 28
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        lineHeight: 1.2
    }

}
