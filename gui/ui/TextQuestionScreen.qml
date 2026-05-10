import QtQuick
import QtQuick.Layouts

QuestionScreen {
    id: textQuestion

    property string value: ""
    property string placeholderText: ""
    property int echoMode: TextInput.Normal

    signal valueEdited(string value)

    canGoNext: value.length > 0

    StyledTextField {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 310
        placeholderText: textQuestion.placeholderText
        echoMode: textQuestion.echoMode
        text: textQuestion.value
        onTextChanged: textQuestion.valueEdited(text)
    }

}
