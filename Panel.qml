import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Type (or select, then open) a short text: it is translated into the other
// two of Swedish, Portuguese and English as you type. Click a translation to
// copy it.
Panel {
  id: root
  moduleName: "gread.translate"
  ipcTarget: "gread.translate"
  manageIpc: true

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string script: Qt.resolvedUrl("bin/translate").toString().replace(/^file:\/\//, "")
  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Qt.alpha(root.fg, 0.55)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property real innerWidth: Math.max(Style.space(240), keyCatcher.width - Style.space(4))

  readonly property var names: ({ sv: "Svenska", pt: "Português", en: "English" })
  readonly property var flags: ({ sv: "🇸🇪", pt: "🇧🇷", en: "🇬🇧" })

  property string source: ""
  property var results: []          // [{ lang, text }]
  property string errorText: ""
  property bool busy: false
  property string copied: ""        // lang just copied, for the ✓
  property string lastSelection: ""
  property string pending: ""       // text waiting for the running request

  function languageName(code) {
    return root.names[code] || (code ? code.toUpperCase() : "")
  }

  function open() {
    root.controller.show()
    Qt.callLater(function() { input.forceActiveFocus() })
    // A new selection since the last opening is what you want translated.
    selectionProc.running = true
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function translate() {
    var text = input.text
    if (text.trim() === "") {
      root.results = []
      root.source = ""
      root.errorText = ""
      return
    }
    if (translateProc.running) {
      root.pending = text
      return
    }
    root.pending = ""
    root.busy = true
    translateProc.command = ["timeout", "-k", "2", "20", "bash", root.script, text]
    translateProc.running = true
  }

  function copy(entry) {
    copyProc.command = ["wl-copy", "--", entry.text]
    copyProc.running = true
    root.copied = entry.lang
    copiedTimer.restart()
  }

  function errorMessage(code) {
    if (code === "too_long") return "Text too long (up to 1500 characters)."
    if (code === "network") return "No connection to Google Translate."
    if (code === "blocked") return "Google Translate refused the request. Try again in a moment."
    return ""
  }

  Process {
    id: selectionProc
    command: ["bash", root.script, "selection"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var sel = String(text || "").trim()
        if (sel !== "" && sel !== root.lastSelection) {
          root.lastSelection = sel
          input.text = sel
          input.selectAll()
          root.translate()
        }
      }
    }
  }

  Process {
    id: translateProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "") return
        try {
          var data = JSON.parse(raw)
          var list = []
          for (var code in data.results) list.push({ lang: code, text: data.results[code] })
          root.source = data.source
          root.results = list
          root.errorText = ""
        } catch (e) {
          root.errorText = "Unexpected answer from Google Translate."
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var code = String(text || "").trim()
        if (code !== "" && code !== "empty") root.errorText = root.errorMessage(code) || code
      }
    }
    // Typed on while a request ran: translate what is there now.
    onExited: {
      root.busy = false
      if (root.pending !== "") root.translate()
    }
  }

  Process { id: copyProc }

  Timer {
    id: debounce
    interval: 450
    onTriggered: root.translate()
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copied = ""
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: input
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)
        topPadding: Style.space(4)
        bottomPadding: Style.space(4)

        Row {
          spacing: Style.space(8)
          Text {
            id: title
            text: "Translate"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            anchors.baseline: title.baseline
            text: "by Gread"
            color: Qt.darker(root.fg, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // ---- Input
        Rectangle {
          width: root.innerWidth
          height: Math.min(Math.max(input.implicitHeight, Style.space(64)), Style.space(160))
          radius: Style.cornerRadius
          color: Qt.alpha(root.fg, 0.04)
          border.width: 1
          border.color: input.activeFocus ? Color.accent : Qt.alpha(root.fg, 0.18)

          ScrollView {
            anchors.fill: parent
            anchors.margins: 1

            TextArea {
              id: input
              wrapMode: TextArea.Wrap
              placeholderText: "Type or paste text — Swedish, Portuguese or English…"
              placeholderTextColor: root.dim
              color: root.fg
              selectionColor: Qt.alpha(Color.accent, 0.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              background: null
              padding: Style.space(8)
              onTextChanged: debounce.restart()

              // Esc reaches the panel; Ctrl+Enter copies the first translation.
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.close()
                  event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                           && (event.modifiers & Qt.ControlModifier) && root.results.length > 0) {
                  root.copy(root.results[0])
                  event.accepted = true
                }
              }
            }
          }
        }

        Text {
          width: root.innerWidth
          text: root.busy ? "Translating…"
            : root.errorText !== "" ? root.errorText
            : root.source !== "" ? "From " + root.languageName(root.source) + " · click to copy · Ctrl+Enter copies the first"
            : "Opens with the selected text. Esc closes."
          color: root.errorText !== "" ? Color.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // ---- Results
        Repeater {
          model: root.results

          Rectangle {
            id: card
            required property var modelData
            width: root.innerWidth
            height: body.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: area.containsMouse ? Qt.alpha(root.fg, 0.08) : Qt.alpha(root.fg, 0.04)
            border.width: 1
            border.color: root.copied === card.modelData.lang ? Color.accent : Qt.alpha(root.fg, 0.15)

            Column {
              id: body
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              spacing: Style.space(4)

              Text {
                text: (root.flags[card.modelData.lang] || "") + "  " + root.languageName(card.modelData.lang)
                  + (root.copied === card.modelData.lang ? "   ✓ copied" : "")
                color: root.copied === card.modelData.lang ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                width: parent.width
                text: card.modelData.text
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
              }
            }

            MouseArea {
              id: area
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copy(card.modelData)
            }
          }
        }
      }
    }
  }
}
