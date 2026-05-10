import QtQuick
import QtQuick.Layouts

QuestionScreen {
    id: comboQuestion

    property alias model: picker.model
    property string currentValueText: ""

    signal valuePicked(string value)

    canGoNext: currentValueText.length > 0

    StyledComboBox {
        id: picker

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 420
        currentValueText: comboQuestion.currentValueText
        onValuePicked: function(value) {
            comboQuestion.valuePicked(value);
        }
    }

}
