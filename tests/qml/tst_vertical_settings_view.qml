import QtQuick
import QtQuick.Layouts
import QtTest
import "../../ui/Controls" as Controls

Item {
    width: 520
    height: 340

    Controls.VerticalSettingsView {
        id: view
        anchors.fill: parent
        contentHeight: body.implicitHeight
        ColumnLayout {
            id: body
            x: view.contentInset
            width: view.availableWidth
            height: implicitHeight
            spacing: 12
            Repeater {
                model: 8
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    color: "lightgray"
                }
            }
        }
    }

    TestCase {
        name: "VerticalSettingsView"
        when: windowShown

        function test_scroll_data() {
            return [{tag: "LTR", rtl: false}, {tag: "RTL", rtl: true}]
        }

        function test_scroll(data) {
            view.LayoutMirroring.enabled = data.rtl
            view.LayoutMirroring.childrenInherit = true
            view.contentY = 0
            wait(50)
            compare(view.contentWidth, view.width)
            compare(body.width + 2 * view.contentInset, view.width)
            compare(view.contentX, view.originX)
            mouseDrag(view, 260, 160, -150, 0, Qt.LeftButton)
            wait(100)
            compare(view.contentX, view.originX)
            mouseDrag(view, 150, 160, 150, 0, Qt.LeftButton)
            wait(100)
            compare(view.contentX, view.originX)
            mouseWheel(view, 250, 160, -120, 0)
            wait(100)
            compare(view.contentX, view.originX)
            mouseWheel(view, 250, 160, 120, 0)
            wait(100)
            compare(view.contentX, view.originX)
            mouseDrag(view, 250, 250, -60, -140, Qt.LeftButton)
            tryVerify(function() { return view.contentY > view.originY })
            compare(view.contentX, view.originX)
            tryCompare(view, "moving", false, 3000)
            view.contentY = 0
            mouseDrag(view, 250, 100, 0, 150, Qt.LeftButton)
            wait(100)
            compare(view.contentY, view.originY)
        }

        function test_short_content() {
            view.contentHeight = view.height - 20
            view.contentY = 0
            mouseDrag(view, 250, 150, -100, -100, Qt.LeftButton)
            wait(100)
            compare(view.contentX, view.originX)
            compare(view.contentY, view.originY)
            view.contentHeight = Qt.binding(function() { return body.implicitHeight })
        }
    }
}
