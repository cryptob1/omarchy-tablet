// Touch controls for tablet use: a rail of buttons along the screen edge, with
// a push-to-talk mic for your dictation tool at its end.
//
// TWO RAILS (the default, `tablet-mode rails both`): held in both hands, a big
// tablet has a thumb on each edge, and the lower a button is the easier it is
// to reach. So the buttons are split by hand and ordered bottom-up by use:
//   right, bottom up   mic, enter, keyboard, switch window, the scroll strip,
//                      maximise, and close at the top
//   left, bottom up    next / previous workspace, launcher, play-pause (hold:
//                      next track), volume down / up (hold: repeat), and stay
//                      awake at the top
// `tablet-mode rails right`, or an upright screen, gives the single rail
// described below, which has no media or volume buttons.
//
// THE RAIL. While ~/.local/state/tablet-mode/state reads "tablet" (written by
// bin/tablet-mode on keyboard detach) a strip RAIL px wide is reserved along
// the right edge (the bottom edge when the screen is upright). Windows stop
// at it, so the buttons cover nothing, are fully opaque, and never need to
// hide. It sits on the Top layer: a truly fullscreen window (a film) covers
// it; a maximised one does not. In order, far end to thumb end:
//   close        asks first, see below
//   switch       focus the next window on this workspace; if the current
//                one fills the screen, the next takes its place (a swap)
//   maximise     fill the screen / restore (the four-finger swipe up / down)
//   launcher     the app menu (Super+Space)
//   scroll       (the tall strip) drag along it to scroll the focused window;
//                it flings. The way to scroll a terminal with one finger.
//   stay awake   no screensaver, auto-lock or screen-off while lit (Omarchy's
//                own stay-awake state, the same one the bar's mug shows)
//   < n >        previous / next workspace, the current one between them;
//                HOLD an arrow to take the focused window along
//   keyboard     on-screen keyboard toggle (bin/tablet-osk)
//   enter        sent to the focused app, to submit a dictated message
//   mic          push-to-talk for a dictation tool (only with `tablet-mode
//                dictation on`)
//
// THE MIC. Press and release run the dictation backend's press and release
// commands (bin/tablet-touch, DICTATION), exactly as a hardware push-to-talk
// key would, so the backend's own hold / tap logic applies unchanged. It turns
// red while the backend reports "recording" and pulses while "transcribing"
// (a word in $XDG_RUNTIME_DIR/tablet-mode/mic-state, or Cortex's state file).
//
// No surface here EVER takes keyboard focus (WlrKeyboardFocus.None, as the
// dock does). If one did, tapping it would move focus off the app you are
// writing in and the dictation would paste into nothing.
//
// CLOSE ASKS FIRST. Closing a window cannot be undone and the button sits
// among things tapped without looking. The first tap only arms it: it turns
// red and reads "Close?"; a second tap within `closeConfirmMs` closes the
// window. Doing nothing, or touching any other button, disarms it.
//
// FLOATING STACK. With a keyboard attached there is no rail. If
// ~/.local/state/tablet-mode/mic reads "always", the mic, Enter and the
// keyboard toggle float bottom-right instead, see-through, and hide after
// `hideAfterMs` without a touch on the screen (bin/tablet-gestures reports
// touches by rewriting $XDG_RUNTIME_DIR/tablet-mode/touch).
//
// LONG-PRESS MENU. Holding one finger still on a window makes tablet-gestures
// write $XDG_RUNTIME_DIR/tablet-mode/longpress; a small Copy / Paste / All
// menu then appears by the finger (last PanelWindow below). It acts on
// press, never takes keyboard focus, and goes away after `menuMs`, on a
// choice, or when tablet-gestures reports a touch elsewhere.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/tablet-mode"
  property string mode: "laptop"
  property string micPref: "auto"
  // `tablet-mode rails both|right`: a rail on each edge, or one on the right.
  property string railsPref: "both"
  property string cortexState: "idle"   // the dictation backend's state
  property string micWord: ""           // ...as a plain word, when it publishes one
  // Whether there is a mic at all: `tablet-mode dictation on|off`.
  property string dictation: "off"
  readonly property bool hasMic: dictation.trim() === "on"
  // No keyboard attached: the rail, with everything the keyboard used to do.
  readonly property bool noKeyboard: mode.trim() === "tablet"
  // Keyboard attached but the mic asked for anyway: the small floating stack.
  readonly property bool floating: !noKeyboard && hasMic && micPref.trim() === "always"
  readonly property string micState: micWord.trim().length > 0 ? micWord.trim() : cortexState
  readonly property bool listening: micState === "recording"
  readonly property bool busy: micState === "transcribing"
  // Floating stack only (the rail is opaque and covers nothing).
  // How solid an idle button's DISC is (0-1): low enough that content behind
  // shows through. Only the disc is see-through. The glyph and the rim stay
  // opaque and the glyph carries an outline in the disc's colour, so a button
  // reads the same over a white page as over a dark terminal — fading the
  // whole button left a pale glyph on a pale disc on any light background.
  readonly property real idleOpacity: 0.65
  // Hide after this long without a screen touch; never while recording.
  readonly property int hideAfterMs: 30000
  property bool awake: true

  function touched() { awake = true; hideTimer.restart() }

  Timer {
    id: hideTimer
    interval: root.hideAfterMs
    running: root.floating && !root.listening && !root.busy
    onTriggered: root.awake = false
  }

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/tablet-mode/touch"
    watchChanges: true
    printErrors: false
    onFileChanged: { reload(); root.touched() }
  }

  // Every button action goes through here, so any of them also disarms close.
  function run(args) { disarmClose(); Quickshell.execDetached(args) }

  // Workspace arrows: tap switches, hold carries the focused window (see header).
  readonly property int carryMs: 500
  function wsTapped(rel) { run(["hyprctl", "dispatch", 'hl.dsp.focus({ workspace = "' + rel + '" })']) }
  function wsHeld(rel) { run(["hyprctl", "dispatch", 'hl.dsp.window.move({ workspace = "' + rel + '" })']) }

  // Same toggle as the four-finger swipe: fills the screen, bar and rail stay.
  function toggleMaximise() { run(["hyprctl", "dispatch", 'hl.dsp.window.fullscreen({ mode = "maximized" })']) }
  function micPress() { Quickshell.execDetached([home + "/.local/bin/tablet-touch", "mic-press"]) }
  function micRelease() { Quickshell.execDetached([home + "/.local/bin/tablet-touch", "mic-release"]) }

  // Omarchy's stay-awake state is a file that exists while it is on. Read it
  // from there: a service plugin is not handed the idle service
  // (shell.firstPartyServiceFor returns null without bar capabilities).
  property bool stayAwake: false
  FileView {
    id: stayAwakeFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/indicators/stay-awake"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.stayAwake = true
    onLoadFailed: root.stayAwake = false
  }
  function toggleStayAwake() { run(["omarchy-toggle-idle", "toggle"]) }

  // Close-window confirmation (see header).
  readonly property int closeConfirmMs: 3000
  // A second touch this soon after the first is the same slip, not a "yes".
  readonly property int closeGuardMs: 350
  property bool closeArmed: false
  property double closeArmedAt: 0

  function disarmClose() { closeArmed = false; closeTimer.stop() }

  function closeTapped() {
    if (!closeArmed) {
      closeArmed = true
      closeArmedAt = Date.now()
      closeTimer.restart()
    } else if (Date.now() - closeArmedAt >= closeGuardMs) {
      run(["hyprctl", "dispatch", "hl.dsp.window.close()"])
    }
  }

  Timer {
    id: closeTimer
    interval: root.closeConfirmMs
    onTriggered: root.closeArmed = false
  }

  // Long-press menu state (see header).
  readonly property int menuMs: 5000
  property bool menuShown: false
  property int menuX: 0
  property int menuY: 0
  property bool menuTerminal: false
  property string menuAddress: ""

  function menuAct(action) {
    var args = [root.home + "/.local/bin/tablet-touch", action]
    if (root.menuTerminal) args.push("--terminal")
    if (root.menuAddress.length > 0) { args.push("--address"); args.push(root.menuAddress) }
    root.menuShown = false
    root.run(args)
  }

  Timer {
    id: menuTimer
    interval: root.menuMs
    onTriggered: root.menuShown = false
  }

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/tablet-mode/longpress"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var req = {}
      try { req = JSON.parse(text()) } catch (e) { req = {} }
      // A stale file (shell restart) must not pop a menu up.
      if (!req.show || Math.abs(Date.now() / 1000 - Number(req.at || 0)) > 3) {
        root.menuShown = false
        return
      }
      root.menuX = Math.max(0, Math.round(Number(req.x) || 0))
      root.menuY = Math.max(0, Math.round(Number(req.y) || 0))
      root.menuTerminal = !!req.terminal
      root.menuAddress = String(req.address || "")
      root.menuShown = true
      menuTimer.restart()
    }
  }

  FileView {
    path: root.stateDir + "/state"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.mode = text()
    onLoadFailed: root.mode = "laptop"
  }

  FileView {
    path: root.stateDir + "/rails"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.railsPref = text()
    onLoadFailed: root.railsPref = "both"
  }

  FileView {
    path: root.stateDir + "/mic"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.micPref = text()
    onLoadFailed: root.micPref = "auto"
  }

  FileView {
    path: root.stateDir + "/dictation"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.dictation = text()
    onLoadFailed: root.dictation = "off"
  }

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/tablet-mode/mic-state"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.micWord = text()
    onLoadFailed: root.micWord = ""
  }

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/cortex/state"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.cortexState = String(JSON.parse(text()).class || "idle") }
      catch (e) { root.cortexState = "idle" }
    }
  }

  // Inline components do not see this file's ids: everything they need comes
  // in as a property and goes out as a signal.

  // A round button. `see` < 1 makes only the disc see-through (floating
  // stack); the glyph and rim stay opaque and the glyph is outlined in the
  // disc's colour, so it reads over a white page as well as a dark one.
  component TouchButton: Rectangle {
    id: b
    property string glyph: ""
    property int size: 50
    property int glyphSize: 24
    property bool boldGlyph: false
    property bool active: false
    property color activeColor: Color.accent
    property color idleColor: Color.popups.background
    property real see: 1.0
    // > 0: holding this long fires held() instead of tapped().
    property int holdMs: 0
    property string heldGlyph: ""
    property bool holding: false
    // > 0: tapped() fires on press and then every repeatMs while held (volume).
    property int repeatMs: 0
    signal tapped()
    signal held()

    readonly property bool lit: active || area.pressed
    property real fill: lit ? 0.95 : see
    Behavior on fill { NumberAnimation { duration: 120 } }
    implicitWidth: size; implicitHeight: size
    width: size; height: size; radius: size / 2
    color: Qt.alpha(lit ? activeColor : idleColor, fill)
    border.color: active ? activeColor : Color.popups.border
    border.width: 2

    Text {
      anchors.centerIn: parent
      text: b.holding && b.heldGlyph.length > 0 ? b.heldGlyph : b.glyph
      color: b.lit ? Color.background : Color.popups.text
      font.pixelSize: b.glyphSize
      font.bold: b.boldGlyph
      style: Text.Outline
      styleColor: b.fill > 0.9 ? "transparent" : b.idleColor
    }

    MouseArea {
      id: area
      anchors.fill: parent
      pressAndHoldInterval: b.holdMs > 0 ? b.holdMs : 800
      onPressed: if (b.repeatMs > 0) { b.tapped(); again.interval = 380; again.start() }
      onPressAndHold: if (b.holdMs > 0) { b.holding = true; b.held() }
      onClicked: (mouse) => { if (b.repeatMs === 0 && !(b.holdMs > 0 && mouse.wasHeld)) b.tapped() }
      onReleased: { b.holding = false; again.stop() }
      onCanceled: { b.holding = false; again.stop() }
    }

    Timer {
      id: again
      repeat: true
      onTriggered: { interval = b.repeatMs; b.tapped() }
    }
  }

  // The mic. Press/release, not click: the hold length IS the gesture. A touch
  // the compositor takes away (canceled) must still release, or the backend would
  // keep recording with nothing left to stop it. Both go through tablet-touch,
  // which runs the backend's command and keeps focus on the window dictated into.
  component MicButton: Rectangle {
    id: m
    property int size: 92
    property bool listening: false
    property bool busy: false
    property real see: 1.0
    // Rail: the one button filled with the accent colour while idle, so the
    // eye finds it first. Red while listening, pulsing while transcribing.
    property bool prominent: false
    signal down()
    signal up()

    readonly property bool solid: listening || busy || prominent
    property real fill: (area.pressed || solid) ? 0.95 : see
    Behavior on fill { NumberAnimation { duration: 120 } }
    implicitWidth: size; implicitHeight: size
    width: size; height: size; radius: size / 2
    color: Qt.alpha(listening ? Color.urgent : (solid ? Color.accent : Color.popups.background), fill)
    border.color: listening ? Color.urgent : (prominent ? Color.accent : Color.popups.border)
    border.width: 3
    // A filled button has no colour change left to show a press with.
    scale: area.pressed ? 0.9 : 1.0
    Behavior on scale { NumberAnimation { duration: 90 } }

    SequentialAnimation {
      running: m.busy
      loops: Animation.Infinite
      onStopped: m.opacity = 1
      NumberAnimation { target: m; property: "opacity"; from: 1.0; to: 0.5; duration: 450 }
      NumberAnimation { target: m; property: "opacity"; from: 0.5; to: 1.0; duration: 450 }
    }

    // Breathing ring while the mic is hot, so it is obvious from a distance.
    Rectangle {
      anchors.centerIn: parent
      width: parent.width; height: parent.height; radius: width / 2
      color: "transparent"
      border.color: Color.urgent
      border.width: 3
      visible: m.listening
      SequentialAnimation on scale {
        running: m.listening
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 1.35; duration: 700; easing.type: Easing.OutQuad }
        NumberAnimation { from: 1.35; to: 1.0; duration: 0 }
      }
      SequentialAnimation on opacity {
        running: m.listening
        loops: Animation.Infinite
        NumberAnimation { from: 0.9; to: 0.0; duration: 700 }
        NumberAnimation { from: 0.0; to: 0.9; duration: 0 }
      }
    }

    Text {
      anchors.centerIn: parent
      text: m.busy ? "󰔟" : "󰍬"
      color: m.solid ? Color.background : Color.popups.text
      font.pixelSize: Math.round(m.size * 0.44)
      style: Text.Outline
      styleColor: m.fill > 0.9 ? "transparent" : Color.popups.background
    }

    MouseArea {
      id: area
      anchors.fill: parent
      onPressed: m.down()
      onReleased: m.up()
      onCanceled: m.up()
    }
  }

  // Scroll strip: drag along it to scroll the focused window, let go while
  // moving and it carries on, slowing down. It turns the drag into mouse-wheel
  // notches, so it works on anything that scrolls with a wheel — above all
  // terminals, where a finger on the text is a mouse and selects.
  //
  // WHY HERE and not a drag on the terminal itself: that was tried. The
  // terminal sees the finger land before a drag can be told from a
  // selection, and nothing can take that touch back from it afterwards (see
  // bin/tablet-gestures, ONE-FINGER SCROLLING WAS TRIED). This surface is our
  // own, so scrolling here never touches the app's idea of a selection.
  component ScrollStrip: Rectangle {
    id: st
    property bool horizontal: false
    // Finger travel per wheel notch, and the fling's feel.
    property real stepPx: 9
    property real flingMin: 12      // notches/s needed to carry on
    property real flingStop: 3
    property real flingTau: 0.33    // s
    signal aim()
    signal wheel(int notches)

    property real last: 0
    property real owed: 0
    property real speed: 0          // notches/s, smoothed
    property double lastAt: 0

    function along(mouse) { return horizontal ? mouse.x : mouse.y }
    function give(amount) {
      owed += amount
      var n = owed > 0 ? Math.floor(owed) : Math.ceil(owed)
      if (n !== 0) { owed -= n; wheel(n) }
    }

    implicitWidth: 50; implicitHeight: 50
    radius: 16
    color: Qt.alpha(Color.popups.text, area.pressed || fling.running ? 0.16 : 0.07)
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
      anchors.horizontalCenter: st.horizontal ? undefined : parent.horizontalCenter
      anchors.verticalCenter: st.horizontal ? parent.verticalCenter : undefined
      anchors.top: st.horizontal ? undefined : parent.top
      anchors.left: st.horizontal ? parent.left : undefined
      anchors.margins: 6
      rotation: st.horizontal ? -90 : 0
      text: "󰅃"
      color: Color.popups.text
      opacity: 0.55
      font.pixelSize: 20
    }
    Column {
      anchors.centerIn: parent
      spacing: 6
      rotation: st.horizontal ? 90 : 0
      Repeater {
        model: 3
        Rectangle { width: 22; height: 2; radius: 1; color: Qt.alpha(Color.popups.text, 0.45) }
      }
    }
    Text {
      anchors.horizontalCenter: st.horizontal ? undefined : parent.horizontalCenter
      anchors.verticalCenter: st.horizontal ? parent.verticalCenter : undefined
      anchors.bottom: st.horizontal ? undefined : parent.bottom
      anchors.right: st.horizontal ? parent.right : undefined
      anchors.margins: 6
      rotation: st.horizontal ? -90 : 0
      text: "󰅀"
      color: Color.popups.text
      opacity: 0.55
      font.pixelSize: 20
    }

    MouseArea {
      id: area
      anchors.fill: parent
      preventStealing: true
      onPressed: (mouse) => {
        fling.stop()
        st.last = st.along(mouse); st.owed = 0; st.speed = 0; st.lastAt = Date.now()
        st.aim()
      }
      onPositionChanged: (mouse) => {
        var p = st.along(mouse), now = Date.now()
        var d = (p - st.last) / st.stepPx
        var dt = Math.max(1, now - st.lastAt) / 1000
        st.last = p; st.lastAt = now
        st.speed = Math.max(-220, Math.min(220, 0.6 * st.speed + 0.4 * (d / dt)))
        st.give(d)
      }
      // Only a finger that was still moving when it left flings.
      onReleased: if (Date.now() - st.lastAt < 80 && Math.abs(st.speed) >= st.flingMin) fling.start()
      onCanceled: fling.stop()
    }

    Timer {
      id: fling
      interval: 16
      repeat: true
      onTriggered: {
        st.give(st.speed * interval / 1000)
        st.speed *= Math.exp(-(interval / 1000) / st.flingTau)
        if (Math.abs(st.speed) < st.flingStop) stop()
      }
    }
  }

  // ---------------------------------------------------------------- the rail
  readonly property int railSize: 64
  // Two rails when asked for and the screen is wide; upright, one bar.
  readonly property bool upright: Quickshell.screens.length > 0
    && Quickshell.screens[0].height > Quickshell.screens[0].width
  readonly property bool dual: !upright && railsPref.trim() !== "right"
  // The rail is a card like every other Omarchy surface: the windows' corner
  // radius and border width, and the same gap to the screen edge that windows
  // keep (Style.gapsOut is half of Hyprland's gaps_out). No gap on the window
  // side: the windows bring their own.
  readonly property int railGap: Style.gapsOut * 2
  // As see-through as the terminal beside it. Omarchy's standard window
  // opacity is 0.985 (o.transparent_window in default/hypr/helpers.lua); the
  // popup colour already carries the theme's own alpha, which is what drops
  // when Appearance is set to Glassy (hypr/fragments/tablet.lua asks for the
  // blur behind it then, as Omarchy does for its own surfaces).
  readonly property real railOpacity: 0.985

  PanelWindow {
    id: rail
    visible: root.noKeyboard
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    // Along the right edge; along the bottom when the screen is upright.
    readonly property bool upright: screen !== null && screen.height > screen.width
    color: "transparent"
    // This name is what bin/tablet-gestures matches (IGNORE_LAYERS) to keep
    // touches here out of its gestures.
    WlrLayershell.namespace: "omarchy-tablet-rail"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: root.railSize + root.railGap
    anchors { right: true; bottom: true; top: !rail.upright; left: rail.upright }
    implicitWidth: root.railSize + root.railGap
    implicitHeight: root.railSize + root.railGap

    Rectangle {
      anchors.fill: parent
      anchors.rightMargin: root.railGap
      anchors.bottomMargin: root.railGap
      anchors.topMargin: rail.upright ? 0 : root.railGap
      anchors.leftMargin: rail.upright ? root.railGap : 0
      radius: Style.cornerRadius
      color: Qt.alpha(Color.popups.background, Color.popups.background.a * root.railOpacity)
      border.color: Color.popups.border
      border.width: 2

      GridLayout {
        anchors.fill: parent
        anchors.margins: 7
        flow: rail.upright ? GridLayout.LeftToRight : GridLayout.TopToBottom
        rowSpacing: 10
        columnSpacing: 10

        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: root.closeArmed ? "Close?" : "󰅖"
          glyphSize: root.closeArmed ? 12 : 24
          boldGlyph: root.closeArmed
          active: root.closeArmed
          activeColor: Color.urgent
          onTapped: root.closeTapped()
        }

        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰊓"
          onTapped: root.toggleMaximise()
        }
        TouchButton {
          Layout.alignment: Qt.AlignCenter
          visible: !root.dual
          glyph: "󰀻"
          onTapped: root.run(["omarchy-menu", "toggle", "apps"])
        }
        TouchButton {
          Layout.alignment: Qt.AlignCenter
          visible: !root.dual
          glyph: root.stayAwake ? "󰅶" : "󰛊"
          active: root.stayAwake
          onTapped: root.toggleStayAwake()
        }

        ScrollStrip {
          Layout.alignment: Qt.AlignCenter
          Layout.fillHeight: !rail.upright
          Layout.fillWidth: rail.upright
          horizontal: rail.upright
          onAim: root.run([root.home + "/.local/bin/tablet-touch", "scroll-aim"])
          onWheel: (notches) => Quickshell.execDetached(["ydotool", "mousemove", "--wheel", "-x", "0", "-y", String(notches)])
        }

        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰓡"
          onTapped: root.run([root.home + "/.local/bin/tablet-touch", "next-window"])
        }

        TouchButton {
          Layout.alignment: Qt.AlignCenter
          visible: !root.dual
          glyph: "󰁍"
          heldGlyph: "󰖯"
          holdMs: root.carryMs
          onTapped: root.wsTapped("r-1")
          onHeld: root.wsHeld("r-1")
        }
        Text {
          Layout.alignment: Qt.AlignCenter
          visible: !root.dual
          text: Hyprland.focusedWorkspace !== null ? Hyprland.focusedWorkspace.id : ""
          color: Color.popups.text
          opacity: 0.75
          font.pixelSize: 17
          font.bold: true
        }
        TouchButton {
          Layout.alignment: Qt.AlignCenter
          visible: !root.dual
          glyph: "󰁔"
          heldGlyph: "󰖯"
          holdMs: root.carryMs
          onTapped: root.wsTapped("r+1")
          onHeld: root.wsHeld("r+1")
        }

        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰌌"
          onTapped: root.run([root.home + "/.local/bin/tablet-osk", "toggle"])
        }
        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰌑"
          onTapped: root.run(["ydotool", "key", "28:1", "28:0"])
        }
        MicButton {
          Layout.alignment: Qt.AlignCenter
          visible: root.hasMic
          size: 50
          prominent: true
          listening: root.listening
          busy: root.busy
          onDown: root.micPress()
          onUp: root.micRelease()
        }
      }
    }
  }

  // The left rail (two-rail layout): where the other thumb rests. Bottom up,
  // most used first: workspaces, launcher, then media and volume, with stay
  // awake out of the way at the top.
  PanelWindow {
    id: railLeft
    visible: root.noKeyboard && root.dual
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"
    WlrLayershell.namespace: "omarchy-tablet-rail"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: root.railSize + root.railGap
    anchors { left: true; top: true; bottom: true }
    implicitWidth: root.railSize + root.railGap
    implicitHeight: root.railSize + root.railGap

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: root.railGap
      anchors.topMargin: root.railGap
      anchors.bottomMargin: root.railGap
      radius: Style.cornerRadius
      color: Qt.alpha(Color.popups.background, Color.popups.background.a * root.railOpacity)
      border.color: Color.popups.border
      border.width: 2

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 7
        spacing: 10

        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: root.stayAwake ? "󰅶" : "󰛊"
          active: root.stayAwake
          onTapped: root.toggleStayAwake()
        }

        Item { Layout.fillHeight: true }

        // Volume: hold to keep going. Omarchy's own command, so its OSD shows.
        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰝝"
          repeatMs: 120
          onTapped: root.run(["omarchy-audio-output-volume", "raise"])
        }
        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰝞"
          repeatMs: 120
          onTapped: root.run(["omarchy-audio-output-volume", "lower"])
        }
        // Play / pause; hold for the next track.
        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰐎"
          heldGlyph: "󰒭"
          holdMs: root.carryMs
          onTapped: root.run(["omarchy-shell", "media", "playPause"])
          onHeld: root.run(["omarchy-shell", "media", "next"])
        }

        Item { Layout.fillHeight: true }

        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰀻"
          onTapped: root.run(["omarchy-menu", "toggle", "apps"])
        }
        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰁍"
          heldGlyph: "󰖯"
          holdMs: root.carryMs
          onTapped: root.wsTapped("r-1")
          onHeld: root.wsHeld("r-1")
        }
        Text {
          Layout.alignment: Qt.AlignCenter
          text: Hyprland.focusedWorkspace !== null ? Hyprland.focusedWorkspace.id : ""
          color: Color.popups.text
          opacity: 0.75
          font.pixelSize: 17
          font.bold: true
        }
        TouchButton {
          Layout.alignment: Qt.AlignCenter
          glyph: "󰁔"
          heldGlyph: "󰖯"
          holdMs: root.carryMs
          onTapped: root.wsTapped("r+1")
          onHeld: root.wsHeld("r+1")
        }
      }
    }
  }

  // ------------------------------------------- floating stack (keyboard on)
  PanelWindow {
    id: win
    visible: root.floating && (root.awake || root.listening || root.busy)
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"
    WlrLayershell.namespace: "omarchy-tablet-rail"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0
    anchors { bottom: true; right: true }
    margins { bottom: 28; right: 28 }
    implicitWidth: 104
    implicitHeight: 246
    mask: Region {
      Region { item: fMic }
      Region { item: fEnter }
      Region { item: fKbd }
    }

    TouchButton {
      id: fKbd
      anchors.horizontalCenter: fMic.horizontalCenter
      anchors.bottom: fEnter.top
      anchors.bottomMargin: 14
      see: root.idleOpacity
      glyph: "󰌌"
      onTapped: root.run([root.home + "/.local/bin/tablet-osk", "toggle"])
    }
    TouchButton {
      id: fEnter
      anchors.horizontalCenter: fMic.horizontalCenter
      anchors.bottom: fMic.top
      anchors.bottomMargin: 14
      see: root.idleOpacity
      glyph: "󰌑"
      onTapped: root.run(["ydotool", "key", "28:1", "28:0"])
    }
    MicButton {
      id: fMic
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      see: root.idleOpacity
      listening: root.listening
      busy: root.busy
      onDown: root.micPress()
      onUp: root.micRelease()
    }
  }

  PanelWindow {
    id: menuWin
    visible: root.menuShown
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"
    WlrLayershell.namespace: "omarchy-tablet-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Ignore the bar's reserved strip: the margins are screen coordinates.
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    margins { top: root.menuY; left: root.menuX }
    // Must match MENU_W / MENU_H in bin/tablet-gestures.
    implicitWidth: 252
    implicitHeight: 56

    Rectangle {
      anchors.fill: parent
      radius: 14
      color: Color.popups.background
      border.color: Color.popups.border
      border.width: 2

      Row {
        anchors.fill: parent
        anchors.margins: 4

        Repeater {
          model: [
            { label: "Copy", action: "copy" },
            { label: "Paste", action: "paste" },
            { label: "All", action: "all" }
          ]

          Rectangle {
            required property var modelData
            width: (parent.width) / 3
            height: parent.height
            radius: 10
            // "Select all" means nothing to a terminal.
            readonly property bool usable: !(root.menuTerminal && modelData.action === "all")
            color: itemArea.pressed && usable ? Color.accent : "transparent"
            opacity: usable ? 1 : 0.35

            Text {
              anchors.centerIn: parent
              text: parent.modelData.label
              color: itemArea.pressed && parent.usable ? Color.background : Color.popups.text
              font.pixelSize: 17
            }

            MouseArea {
              id: itemArea
              anchors.fill: parent
              // On press: by release, focus may already have wandered.
              onPressed: if (parent.usable) root.menuAct(parent.modelData.action)
            }
          }
        }
      }
    }
  }
}
