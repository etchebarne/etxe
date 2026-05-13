import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root

    readonly property string uiFont: "Red Hat Display"
    readonly property color fg: "#f7f7f7"
    readonly property color muted: "#9a9a9a"
    readonly property color stroke: "#3a3a3a"
    readonly property color fieldBg: "#020202"
    property int step: 0
    property string selectedDisk: ""
    property string selectedDiskLabel: ""
    property string selectedSsid: ""
    property string wifiPassword: ""
    property string installResultMessage: ""
    property bool installSucceeded: false
    property bool showFailureDetails: false
    property int installMessageIndex: 0
    property int pendingInstallMessageIndex: 0
    readonly property var installMessages: ["This could take a moment...", "We're setting up your new home...", "Almost there..."]

    function autoSelectDisk() {
        if (selectedDisk.length === 0 && backend.disks.length === 1) {
            selectedDisk = backend.disks[0].path;
            selectedDiskLabel = backend.disks[0].label;
        }
    }

    function canContinue() {
        if (step === 4)
            return selectedDisk.length > 0;

        if (step === 7)
            return form.hostname.trim().length > 0;

        if (step === 8)
            return form.username.trim().length > 0;

        if (step === 9)
            return form.password.length > 0;

        return true;
    }

    function nextStep() {
        if (!canContinue())
            return ;

        if (step === 10) {
            step = selectedSsid.length > 0 ? 11 : 12;
            return ;
        }
        if (step === 11) {
            backend.connectWifi(selectedSsid, wifiPassword);
            step = 12;
            return ;
        }
        if (step < 12)
            step += 1;

    }

    function previousStep() {
        if (step === 12 && selectedSsid.length > 0) {
            step = 11;
            return ;
        }
        if (step === 12) {
            step = 10;
            return ;
        }
        if (step > 3 && step < 13)
            step -= 1;

    }

    function startInstall() {
        var started = backend.startInstall({
            "disk": selectedDisk,
            "hostname": form.hostname,
            "username": form.username,
            "password": form.password,
            "locale": form.locale,
            "keymap": form.keymap,
            "timezone": form.timezone,
            "autologin": form.autologin
        });
        if (started) {
            installMessageIndex = 0;
            pendingInstallMessageIndex = 0;
            installProgress.messageOpacity = 0;
            step = 13;
            installStartFadeDelay.restart();
        }
    }

    function installMessageIndexForPhase(phase) {
        if (phase.indexOf("Creating your account") >= 0 || phase.indexOf("Preparing the sign-in screen") >= 0 || phase.indexOf("Setting up audio") >= 0 || phase.indexOf("Setting up networking") >= 0 || phase.indexOf("Setting up boot") >= 0 || phase.indexOf("Finishing up") >= 0)
            return 2;

        if (phase.indexOf("Installing the desktop system") >= 0 || phase.indexOf("Writing disk configuration") >= 0 || phase.indexOf("Applying your region settings") >= 0)
            return 1;

        return 0;
    }

    function advanceInstallMessageForPhase(phase) {
        var nextIndex = installMessageIndexForPhase(phase);
        if (nextIndex <= installMessageIndex)
            return ;

        pendingInstallMessageIndex = nextIndex;
        installMessageTransition.restart();
    }

    visible: true
    x: 0
    y: 0
    width: Screen.width
    height: Screen.height
    minimumWidth: Screen.width
    minimumHeight: Screen.height
    flags: Qt.FramelessWindowHint
    color: "#000000"
    title: "Etxe Installer"
    font.family: uiFont
    onStepChanged: {
        if (step === 10)
            backend.refreshWifi();

    }
    Component.onCompleted: autoSelectDisk()

    QtObject {
        id: form

        property string locale: "en_US.UTF-8"
        property string keymap: "us"
        property string timezone: "Europe/Madrid"
        property string hostname: "etxe"
        property string username: ""
        property string password: ""
        property bool autologin: false
    }

    Connections {
        function onDisksChanged() {
            autoSelectDisk();
        }

        function onInstallFinished(success, message) {
            installSucceeded = success;
            installResultMessage = message;
            step = success ? 14 : 15;
        }

        function onInstallPhaseChanged() {
            advanceInstallMessageForPhase(backend.installPhase);
        }

        target: backend
    }

    SequentialAnimation {
        id: installMessageTransition

        NumberAnimation {
            target: installProgress
            property: "messageOpacity"
            to: 0
            duration: 700
            easing.type: Easing.InOutQuad
        }

        ScriptAction {
            script: installMessageIndex = pendingInstallMessageIndex
        }

        NumberAnimation {
            target: installProgress
            property: "messageOpacity"
            to: 1
            duration: 700
            easing.type: Easing.InOutQuad
        }

    }

    Timer {
        id: installStartFadeDelay

        interval: 80
        repeat: false
        onTriggered: installStartFade.restart()
    }

    NumberAnimation {
        id: installStartFade

        target: installProgress
        property: "messageOpacity"
        to: 1
        duration: 700
        easing.type: Easing.InOutQuad
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: step

        IntroScreen {
            active: step === 0
            nextStep: 1
            showIcon: true
            onFinished: function(nextStep) {
                step = nextStep;
            }
        }

        IntroScreen {
            active: step === 1
            nextStep: 2
            text: "Welcome home."
            onFinished: function(nextStep) {
                step = nextStep;
            }
        }

        IntroScreen {
            active: step === 2
            nextStep: 3
            text: "Let's take a minute to\nset up your system."
            onFinished: function(nextStep) {
                step = nextStep;
            }
        }

        ComboQuestionScreen {
            title: "First of all, select your language:"
            showBack: false
            model: backend.locales
            currentValueText: form.locale
            onValuePicked: function(value) {
                form.locale = value;
            }
            onNext: nextStep()
        }

        QuestionScreen {
            title: "Where do you want to install Etxe?"
            canGoNext: selectedDisk.length > 0
            onPrevious: previousStep()
            onNext: nextStep()

            Column {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 386
                width: 386
                spacing: 10

                Repeater {
                    model: backend.disks

                    delegate: SelectRow {
                        width: parent.width
                        text: modelData.label
                        selected: selectedDisk === modelData.path
                        onClicked: {
                            selectedDisk = modelData.path;
                            selectedDiskLabel = modelData.label;
                        }
                    }

                }

                Text {
                    width: parent.width
                    visible: backend.disks.length === 0
                    text: "No installable disks found."
                    color: muted
                    font.family: uiFont
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                }

            }

        }

        ComboQuestionScreen {
            title: "Now, select your keyboard distribution:"
            model: backend.keymaps
            currentValueText: form.keymap
            onPrevious: previousStep()
            onNext: nextStep()
            onValuePicked: function(value) {
                form.keymap = value;
                backend.applyKeymap(value);
            }
        }

        ComboQuestionScreen {
            title: "Choose your timezone:"
            model: backend.timezones
            currentValueText: form.timezone
            onValuePicked: function(value) {
                form.timezone = value;
            }
            onPrevious: previousStep()
            onNext: nextStep()
        }

        TextQuestionScreen {
            title: "How do you want to call this computer?"
            value: form.hostname
            placeholderText: "etxe"
            canGoNext: form.hostname.trim().length > 0
            onPrevious: previousStep()
            onNext: nextStep()
            onValueEdited: function(value) {
                form.hostname = value;
            }
        }

        TextQuestionScreen {
            title: "What is your name?"
            value: form.username
            placeholderText: "john"
            canGoNext: form.username.trim().length > 0
            onPrevious: previousStep()
            onNext: nextStep()
            onValueEdited: function(value) {
                form.username = value;
            }
        }

        TextQuestionScreen {
            title: "Now, enter a password:"
            value: form.password
            echoMode: TextInput.Password
            onPrevious: previousStep()
            onNext: nextStep()
            onValueEdited: function(value) {
                form.password = value;
            }
        }

        QuestionScreen {
            title: "Do you want to connect to Wi-Fi?"
            onPrevious: previousStep()
            onNext: nextStep()

            Column {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 386
                width: 386
                spacing: 10

                Repeater {
                    model: backend.wifiNetworks

                    delegate: SelectRow {
                        width: parent.width
                        text: modelData.ssid
                        selected: selectedSsid === modelData.ssid
                        onClicked: selectedSsid = modelData.ssid
                    }

                }

                Text {
                    width: parent.width
                    visible: backend.networkMessage.length > 0 || backend.wifiNetworks.length === 0
                    text: backend.networkMessage.length > 0 ? backend.networkMessage : "Scanning for Wi-Fi networks..."
                    color: muted
                    font.family: uiFont
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                NavButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 112
                    text: "Rescan"
                    primary: false
                    onClicked: backend.refreshWifi()
                }

            }

        }

        TextQuestionScreen {
            title: "Enter the Wi-Fi password:"
            value: wifiPassword
            echoMode: TextInput.Password
            canGoNext: true
            onPrevious: previousStep()
            onNext: nextStep()
            onValueEdited: function(value) {
                wifiPassword = value;
            }
        }

        InstallReviewScreen {
            selectedDisk: root.selectedDisk
            onPrevious: previousStep()
            onInstallRequested: startInstall()
        }

        InstallProgressScreen {
            id: installProgress

            messages: installMessages
            messageIndex: installMessageIndex
        }

        InstallSuccessScreen {
            onRebootRequested: backend.reboot()
        }

        InstallFailureScreen {
            message: installResultMessage
            logText: backend.logText
            showDetails: showFailureDetails
            onToggleDetails: showFailureDetails = !showFailureDetails
        }

    }

}
