// Touch controls for tablet use: a rail of buttons along the screen edge, with
// a push-to-talk mic for your dictation tool at its end.
//
// TWO RAILS (the default, `tablet-mode rails both`): held in both hands, a big
// tablet has a thumb on each edge, and the lower a button is the easier it is
// to reach. So the buttons are split by hand and ordered bottom-up by use:
//   right, bottom up   mic, enter, NEXT workspace (with the number above
//                      it), keyboard, switch window, the scroll strip,
//                      maximise, and close at the top
//   left, bottom up    launcher, play-pause (hold: next track), PREVIOUS
//                      workspace level with "next" on the right, a volume
//                      rocker and a brightness rocker (plus / minus, hold to
//                      repeat, filled to show the level; tap the speaker to
//                      mute), and stay awake at the top
// `tablet-mode rails right`, or an upright screen, gives the single rail
// described below, which has no media or volume buttons.
//
// THREE LOOKS (`tablet-mode look theme|controller|cheetah`). "theme" draws the
// rails like every other Omarchy surface. "controller" draws them like a
// handheld game controller: a moulded shell a shade lighter than the theme's
// background, flush with the screen edges and rounded only towards the
// windows, with the buttons as raised caps that sink when pressed, the scroll
// strip as a ridged thumb wheel, and the close legend in red. "cheetah" is the
// controller with a shell in the theme's accent colour, covered in darker
// cheetah spots. Colours always come from the theme, so the looks change
// with it.
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
import Quickshell.Services.Pipewire
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
  // `tablet-mode look theme|controller|cheetah`: drawn like the rest of
  // Omarchy, or like a handheld game controller (a moulded shell with raised
  // button caps), or that controller with a blue cheetah-spot shell.
  property string lookPref: "theme"
  // Every look but "theme" is a SKIN: the colours of a controller shell, its
  // button caps and their legends, and a pattern across the shell. Two take
  // their colours from the Omarchy theme; the rest are fixed, loud and
  // unapologetic. `skin` is null for the flat theme look.
  readonly property var lookNames: ["theme", "controller", "cheetah", "tiger", "arcade", "neon",
                                    "retro", "candy", "lava", "galaxy", "ice",
                                    "rainbow", "unicorn", "fairy", "mermaid", "dragon", "sunset",
                                    "watermelon", "honeybee", "circuit", "pixel", "prism"]
  function skinFor(name) {
    var bg = Color.popups.background, ac = Color.accent
    switch (name) {
    case "controller": return {
        label: "Controller", shellTop: Qt.lighter(bg, 2.2), shellBottom: Qt.lighter(bg, 1.45),
        cap: Qt.darker(bg, 1.25), legend: Color.popups.text, accent: ac, close: Color.urgent,
        pattern: "none", ink: "transparent", glow: "transparent" }
    case "cheetah": return {
        label: "Cheetah", shellTop: Qt.tint(Qt.lighter(bg, 2.4), Qt.alpha(ac, 0.55)),
        shellBottom: Qt.tint(Qt.lighter(bg, 1.7), Qt.alpha(ac, 0.38)),
        cap: Qt.darker(bg, 1.25), legend: Color.popups.text, accent: ac, close: Color.urgent,
        pattern: "spots", ink: Qt.alpha(Qt.darker(ac, 3.4), 0.62), glow: Qt.alpha(Qt.lighter(ac, 1.5), 0.55) }
    case "tiger": return {
        label: "Tiger", shellTop: "#f7a02b", shellBottom: "#d8660a", cap: "#1c130d", legend: "#ffe7c2",
        accent: "#ffd23f", close: "#ff5a4d", pattern: "stripes", ink: "#d91a0f08", glow: "transparent" }
    case "arcade": return {
        label: "Arcade", shellTop: "#2d2f3d", shellBottom: "#14151c", cap: "#0b0c11", legend: "#f4f4f4",
        accent: "#ffcc00", close: "#ff3b3b", pattern: "confetti", ink: "#ff3b3b", glow: "#2ec4ff" }
    case "neon": return {
        label: "Neon", shellTop: "#2c1052", shellBottom: "#110423", cap: "#0d0420", legend: "#3ef0ff",
        accent: "#ff2fd0", close: "#ff4f7a", pattern: "grid", ink: "#59ff2fd0", glow: "#803ef0ff" }
    case "retro": return {
        label: "Retro", shellTop: "#dcd9d2", shellBottom: "#b8b4aa", cap: "#3a393e", legend: "#f3f1ea",
        accent: "#c8102e", close: "#ff6b6b", pattern: "ridges", ink: "#1f000000", glow: "#40ffffff" }
    case "candy": return {
        label: "Candy", shellTop: "#ff9ecf", shellBottom: "#ffc48a", cap: "#fff6fb", legend: "#d6336c",
        accent: "#7c4dff", close: "#e03131", pattern: "dots", ink: "#8cffffff", glow: "transparent" }
    case "lava": return {
        label: "Lava", shellTop: "#3c0e05", shellBottom: "#130302", cap: "#1b0806", legend: "#ffb36b",
        accent: "#ff5a1f", close: "#ff3b30", pattern: "spots", ink: "#99ff4d0a", glow: "#e6ffd166" }
    case "galaxy": return {
        label: "Galaxy", shellTop: "#1a1f63", shellBottom: "#3d1569", cap: "#0e0f2e", legend: "#dcd6ff",
        accent: "#9d7bff", close: "#ff6b9a", pattern: "stars", ink: "#ffffff", glow: "#b3c8b6ff" }
    case "ice": return {
        label: "Ice", shellTop: "#eaf8ff", shellBottom: "#bfe4f6", cap: "#f8fdff", legend: "#1f6f96",
        accent: "#18a0e0", close: "#e5484d", pattern: "stars", ink: "#ffffff", glow: "#997cc4e8" }
    // `palette` feeds the patterns that take several colours ("wash" paints it
    // top to bottom as one smooth gradient, "bands" as hard diagonal stripes,
    // "pixels" as random blocks); patterns joined with "+" are painted in turn.
    // `rim` gives the shell a thick coloured edge.
    case "rainbow": return {
        label: "Rainbow", shellTop: "#9bdcff", shellBottom: "#e6f7ff", cap: "#ffffff", legend: "#3a6ea5",
        accent: "#ff5fa2", close: "#e03131", pattern: "wash+chars", ink: "transparent", glow: "transparent",
        palette: ["#8fd6ff", "#bfe9ff", "#e9f8ff"],
        chars: ["\ud83c\udf08", "\ud83c\udf08", "\u2601\ufe0f", "\u2b50", "\u2600\ufe0f"] }
    case "prism": return {
        label: "Prism", shellTop: "#ff4d4d", shellBottom: "#7a5cff", cap: "#ffffff", legend: "#3a3a4a",
        accent: "#ff3fa4", close: "#e03131", pattern: "bands", ink: "transparent", glow: "transparent",
        barText: "#1b1c22",
        palette: ["#ff4d4d", "#ff9a3c", "#ffe14d", "#4cd964", "#3fb8ff", "#7a5cff", "#d65cff"] }
    case "unicorn": return {
        label: "Unicorn", shellTop: "#ffd1ec", shellBottom: "#c8f7e4", cap: "#ffffff", legend: "#a25bd6",
        accent: "#ff7ac8", close: "#e0457b", pattern: "wash+stars+chars", ink: "#ffffff", glow: "#e6ffd700",
        palette: ["#ffd1ec", "#e3ccff", "#c9e4ff", "#c8f7e4", "#fff3c4"],
        chars: ["\ud83e\udd84", "\ud83e\udd84", "\ud83c\udf08", "\u2b50", "\ud83d\udc96"] }
    case "fairy": return {
        label: "Fairy", shellTop: "#2b1055", shellBottom: "#1b8a7a", cap: "#1a0b33", legend: "#ffe9a8",
        accent: "#3ee6c1", close: "#ff7aa8", pattern: "wash+stars+chars", ink: "#ffe9a8", glow: "#ff9ff3",
        palette: ["#2b1055", "#4a1f7a", "#1f5f7a", "#1b8a7a"],
        chars: ["\ud83e\uddda", "\ud83e\uddda", "\u2728", "\ud83c\udf44", "\ud83e\udd8b", "\ud83c\udf38"] }
    case "mermaid": return {
        label: "Mermaid", shellTop: "#14c9c0", shellBottom: "#7a5cd6", cap: "#0b2a44", legend: "#aef6ee",
        accent: "#ff7fd1", close: "#ff6b6b", pattern: "wash+scales+chars", ink: "#40ffffff", glow: "#1a000000",
        palette: ["#14c9c0", "#1e8fd6", "#7a5cd6"],
        chars: ["\ud83e\udddc", "\ud83e\udddc", "\ud83d\udc1a", "\ud83d\udc20", "\ud83e\udee7", "\u2b50"] }
    case "dragon": return {
        label: "Dragon", shellTop: "#0f3d1e", shellBottom: "#050d08", cap: "#0a1a0f", legend: "#e8c66a",
        accent: "#e03131", close: "#ff5a4d", pattern: "wash+scales", ink: "#80d4af37", glow: "#59000000",
        palette: ["#14502a", "#0a2413", "#050d08"] }
    case "sunset": return {
        label: "Sunset", shellTop: "#ffd76b", shellBottom: "#3b2a8c", cap: "#2a1540", legend: "#ffe6c7",
        accent: "#ffd23f", close: "#ff6b6b", pattern: "wash+ridges", ink: "#12000000", glow: "#14ffffff",
        palette: ["#ffd76b", "#ff9a4d", "#ff5e7a", "#b04adf", "#3b2a8c"] }
    case "watermelon": return {
        label: "Watermelon", shellTop: "#ff6b88", shellBottom: "#f03a5f", cap: "#f6fff2", legend: "#2f9e44",
        accent: "#2f9e44", close: "#c92a2a", pattern: "seeds", ink: "#2b1a1f", glow: "#73ffffff", rim: "#37b24d" }
    case "honeybee": return {
        label: "Honeybee", shellTop: "#ffd43b", shellBottom: "#f5a700", cap: "#1c1a14", legend: "#ffd43b",
        accent: "#fff8dc", close: "#ff6b4d", pattern: "hex", ink: "#73a05a00", glow: "transparent", rim: "#1c1a14" }
    case "circuit": return {
        label: "Circuit", shellTop: "#0b5d3b", shellBottom: "#063a25", cap: "#04130c", legend: "#7dffb0",
        accent: "#d4af37", close: "#ff6b6b", pattern: "traces", ink: "#8c56d98a", glow: "#d4af37" }
    case "pixel": return {
        label: "Pixel", shellTop: "#2b2f77", shellBottom: "#141852", cap: "#0d0f2e", legend: "#ffffff",
        accent: "#ff4f7a", close: "#ff4f7a", pattern: "pixels", ink: "transparent", glow: "transparent",
        palette: ["#3b43a8", "#4f58c9", "#232765", "#6c75ff"] }
    }
    return null
  }
  function lookLabel(name) { var k = skinFor(name); return k ? k.label : "Omarchy" }
  readonly property var skin: skinFor(lookPref.trim())

  // THE TOP BAR JOINS IN. With a skin on, Omarchy's bar is made see-through
  // and a strip in the skin's shell (colour and pattern) is drawn behind it,
  // so the bar reads as the top of the controller, not a separate thing. The
  // bar's text is set to whichever of dark or light reads on that shell. Both
  // go through the machine's own ~/.config/omarchy/shell.toml (`tablet-mode
  // bar-colors`), and are taken back out with the plain look, with the
  // keyboard attached, or if the bar is not along the top.
  property string barPosition: "top"
  FileView {
    path: root.home + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.barPosition = String((JSON.parse(text()).bar || {}).position || "top") }
      catch (e) { root.barPosition = "top" }
    }
  }
  readonly property bool barSkinned: noKeyboard && skin !== null && barPosition === "top"
  // What the bar's text sits on: the top of the shell. No scrim over it: the
  // strip has to be exactly as bright as the rails it runs into.
  readonly property color barBase: !skin ? "black"
    : (skin.palette && skin.pattern.indexOf("wash") >= 0 ? skin.palette[0] : skin.shellTop)
  readonly property string barText: skin && skin.barText ? skin.barText
    : ((barBase.r * 0.299 + barBase.g * 0.587 + barBase.b * 0.114) > 0.58 ? "#1b1c22" : "#ffffff")
  // The frame: how far its inside corners sweep, and its edge line.
  readonly property int frameRadius: 14
  // The frame is CLOSED along the bottom by a thin bezel in the same shell: a
  // U of thick sides and a thin top reads as three strips, a closed ring reads
  // as one object with the screen set into it. It costs the windows this much
  // height.
  readonly property int bezel: 8
  // A rim skin keeps its coloured edge. Otherwise the edge is a thin dark seam:
  // the frame is shaded to fall away into the screen, and a pale line there (as
  // it was) made a second border round the windows' own.
  readonly property color frameEdge: !skin ? "transparent" : (skin.rim ? skin.rim : Qt.alpha("black", 0.55))
  readonly property int frameEdgeWidth: skin && skin.rim ? 3 : 1
  readonly property string barWanted: barSkinned ? barText : ""
  onBarWantedChanged: applyBar()
  function applyBar() {
    Quickshell.execDetached([home + "/.local/bin/tablet-mode", "bar-colors", barWanted.length > 0 ? barWanted : "clear"])
  }

  // The settings panel (the cog at the top of the left rail; with one rail,
  // hold the stay-awake button). Choices go through `tablet-mode`, which
  // writes the state files this plugin watches, so the command line and the
  // panel can never disagree; the property is also set at once so the change
  // shows without waiting for the file.
  property bool settingsOpen: false
  function setLook(name) { lookPref = name; run([home + "/.local/bin/tablet-mode", "look", name]) }
  function setRails(v) { railsPref = v; run([home + "/.local/bin/tablet-mode", "rails", v]) }
  function setSounds(v) { soundsPref = v; run([home + "/.local/bin/tablet-mode", "sounds", v]); click() }
  readonly property bool controller: skin !== null
  // `tablet-mode sounds on|off`: a soft tap as a button goes down.
  property string soundsPref: "off"
  property var tapSound: null
  readonly property string tapFile: home + "/.local/share/omarchy-tablet/tap.wav"
  // QtMultimedia plays it with no start-up lag; it is optional in Qt, so it is
  // loaded at run time and pw-play stands in where it is missing.
  Component.onCompleted: {
    applyBar()
    try {
      tapSound = Qt.createQmlObject('import QtMultimedia; SoundEffect { volume: 0.35 }', root, "tapSound")
      tapSound.source = "file://" + tapFile
    } catch (e) { tapSound = null }
  }
  function click() {
    if (soundsPref.trim() !== "on") return
    if (tapSound) tapSound.play()
    else Quickshell.execDetached(["pw-play", "--volume", "0.35", tapFile])
  }
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

  // Levels shown in the rockers. Volume straight from PipeWire; brightness by
  // asking brightnessctl (after each press, and now and then: other things
  // change it too). -1: not known, and the rocker then shows no fill.
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  readonly property real volume: sink && sink.audio ? Math.min(1, sink.audio.volume) : -1
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  property real brightness: -1
  Process {
    id: brightnessProbe
    command: ["brightnessctl", "-m"]
    stdout: SplitParser {
      onRead: (line) => {
        var m = String(line).match(/,(\d+)%,/)
        if (m) root.brightness = Number(m[1]) / 100
      }
    }
  }
  Timer {
    interval: 8000
    repeat: true
    triggeredOnStart: true
    running: root.noKeyboard && root.dual
    onTriggered: brightnessProbe.running = true
  }
  Timer { id: brightnessSoon; interval: 180; onTriggered: brightnessProbe.running = true }
  function brightnessStep(step) { run(["omarchy-brightness-display", step]); brightnessSoon.restart() }

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
    path: root.stateDir + "/look"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.lookPref = text()
    onLoadFailed: root.lookPref = "theme"
  }

  FileView {
    path: root.stateDir + "/sounds"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.soundsPref = text()
    onLoadFailed: root.soundsPref = "off"
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
    // Controller look: a raised cap (sheen on top, shade below, a shadow under
    // it) that sinks when pressed. `legend` colours the glyph, as the printed
    // legends on a pad's buttons are coloured.
    property var skin: null            // root.skin, or null for the flat look
    readonly property bool cap: skin !== null
    property bool danger: false        // its legend is the skin's warning colour (close)
    // The colour it turns when active: the skin's accent, unless the button
    // was given one of its own (close's red).
    readonly property color onColor: skin && Qt.colorEqual(activeColor, Color.accent) ? skin.accent : activeColor
    // Dark ink on a light cap, light ink on a dark one.
    function inkOn(c) { return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) > 0.6 ? "#1b1c22" : "#ffffff" }
    signal tapped()
    signal held()
    signal pressedDown()               // the finger landed (for the tap sound)

    readonly property bool lit: active || area.pressed
    readonly property color capBase: active ? onColor : (skin ? skin.cap : Color.popups.background)
    property real fill: lit ? 0.95 : see
    Behavior on fill { NumberAnimation { duration: 120 } }
    implicitWidth: size; implicitHeight: size
    width: size; height: size; radius: size / 2
    color: Qt.alpha(lit ? activeColor : idleColor, fill)
    border.color: cap ? Qt.alpha("black", 0.6) : (active ? activeColor : Color.popups.border)
    border.width: cap ? 1.5 : 2
    gradient: cap ? capGradient : null
    scale: cap && area.pressed ? 0.93 : 1.0
    Behavior on scale { NumberAnimation { duration: 80 } }

    Gradient {
      id: capGradient
      // Pressed: the light comes from below, i.e. the cap has gone in.
      GradientStop { position: 0.0; color: area.pressed ? Qt.darker(b.capBase, 1.35) : Qt.tint(b.capBase, Qt.alpha("white", 0.20)) }
      GradientStop { position: 0.5; color: b.capBase }
      GradientStop { position: 1.0; color: area.pressed ? Qt.tint(b.capBase, Qt.alpha("white", 0.08)) : Qt.darker(b.capBase, 1.45) }
    }
    Rectangle {       // the shadow the cap throws on the shell
      visible: b.cap && !area.pressed
      z: -1
      width: parent.width; height: parent.height; radius: parent.radius
      y: 3
      color: Qt.alpha("black", 0.45)
    }
    Rectangle {       // the gloss: a soft highlight across the top of the dome
      visible: b.cap && !area.pressed
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.07
      width: parent.width * 0.62; height: parent.height * 0.34
      radius: height / 2
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.alpha("white", 0.26) }
        GradientStop { position: 1.0; color: Qt.alpha("white", 0.0) }
      }
    }
    Rectangle {       // a hairline of light round the cap's rim
      visible: b.cap
      anchors.fill: parent
      anchors.margins: 1.5
      radius: width / 2
      color: "transparent"
      border.width: 1
      border.color: Qt.alpha("white", 0.10)
    }

    Text {
      anchors.centerIn: parent
      text: b.holding && b.heldGlyph.length > 0 ? b.heldGlyph : b.glyph
      color: b.cap ? (b.active ? b.inkOn(b.onColor) : (b.danger ? b.skin.close : b.skin.legend))
                   : (b.lit ? Color.background : Color.popups.text)
      font.pixelSize: b.glyphSize
      font.bold: b.boldGlyph
      style: Text.Outline
      styleColor: (b.cap || b.fill > 0.9) ? "transparent" : b.idleColor
    }

    MouseArea {
      id: area
      anchors.fill: parent
      pressAndHoldInterval: b.holdMs > 0 ? b.holdMs : 800
      onPressed: { b.pressedDown(); if (b.repeatMs > 0) { b.tapped(); again.interval = 380; again.start() } }
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
    property var skin: null            // see TouchButton
    readonly property bool cap: skin !== null
    signal down()
    signal up()
    readonly property color capBase: listening ? Color.urgent : (skin ? skin.accent : Color.accent)
    function inkOn(c) { return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) > 0.6 ? "#1b1c22" : "#ffffff" }

    readonly property bool solid: listening || busy || prominent
    property real fill: (area.pressed || solid) ? 0.95 : see
    Behavior on fill { NumberAnimation { duration: 120 } }
    implicitWidth: size; implicitHeight: size
    width: size; height: size; radius: size / 2
    color: Qt.alpha(listening ? Color.urgent : (solid ? Color.accent : Color.popups.background), fill)
    border.color: cap ? Qt.alpha("black", 0.6) : (listening ? Color.urgent : (prominent ? Color.accent : Color.popups.border))
    border.width: cap ? 1.5 : 3
    gradient: cap ? micGradient : null
    Gradient {
      id: micGradient
      GradientStop { position: 0.0; color: area.pressed ? Qt.darker(m.capBase, 1.3) : Qt.lighter(m.capBase, 1.25) }
      GradientStop { position: 0.5; color: m.capBase }
      GradientStop { position: 1.0; color: area.pressed ? Qt.lighter(m.capBase, 1.1) : Qt.darker(m.capBase, 1.4) }
    }
    Rectangle {
      visible: m.cap && !area.pressed
      z: -1
      width: parent.width; height: parent.height; radius: parent.radius
      y: 3
      color: Qt.alpha("black", 0.45)
    }
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
      color: m.cap ? m.inkOn(m.capBase) : (m.solid ? Color.background : Color.popups.text)
      font.pixelSize: Math.round(m.size * 0.44)
      style: Text.Outline
      styleColor: (m.cap || m.fill > 0.9) ? "transparent" : Color.popups.background
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
    // Controller look: an inset, ridged thumb wheel.
    property var skin: null            // see TouchButton
    readonly property bool cap: skin !== null
    readonly property color mark: skin ? skin.legend : Color.popups.text
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
    color: cap ? Qt.darker(skin.cap, area.pressed || fling.running ? 1.0 : 1.22)
               : Qt.alpha(Color.popups.text, area.pressed || fling.running ? 0.16 : 0.07)
    border.width: cap ? 1.5 : 0
    border.color: Qt.alpha("black", 0.6)
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
      anchors.horizontalCenter: st.horizontal ? undefined : parent.horizontalCenter
      anchors.verticalCenter: st.horizontal ? parent.verticalCenter : undefined
      anchors.top: st.horizontal ? undefined : parent.top
      anchors.left: st.horizontal ? parent.left : undefined
      anchors.margins: 6
      rotation: st.horizontal ? -90 : 0
      text: "󰅃"
      color: st.mark
      opacity: 0.55
      font.pixelSize: 20
    }
    Column {
      anchors.centerIn: parent
      spacing: 6
      rotation: st.horizontal ? 90 : 0
      Repeater {
        model: st.cap ? 9 : 3
        Rectangle { width: st.cap ? 30 : 22; height: 2; radius: 1; color: Qt.alpha(st.mark, st.cap ? 0.34 : 0.45) }
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
      color: st.mark
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

  // A rocker: one capsule for a level that goes up and down. Plus at the top,
  // minus at the bottom, both repeating while held; what it controls in the
  // middle (tap: `middle()`, e.g. mute). The capsule fills from the bottom to
  // show the level, so a glance says how loud or how bright.
  component Rocker: Rectangle {
    id: rk
    property string glyph: ""
    property real level: -1            // 0-1, or -1 when unknown
    property bool off: false           // muted: the fill goes grey
    property int repeatMs: 110
    property var skin: null            // see TouchButton
    readonly property bool cap: skin !== null
    readonly property color body: skin ? skin.cap : Color.popups.background
    readonly property color mark: skin ? skin.legend : Color.popups.text
    readonly property color hot: skin ? skin.accent : Color.accent
    signal up()
    signal down()
    signal middle()
    signal pressedDown()

    readonly property real shown: level < 0 ? 0 : Math.max(0, Math.min(1, level))
    readonly property color fillColor: Qt.tint(body,
      Qt.alpha(off ? mark : hot, off ? 0.18 : 0.42))
    // Which third is under the finger: 0 top, 1 middle, 2 bottom, -1 none.
    readonly property int pressedThird: upArea.pressed ? 0 : (midArea.pressed ? 1 : (downArea.pressed ? 2 : -1))
    implicitWidth: 50; implicitHeight: 150
    radius: width / 2
    border.color: cap ? Qt.alpha("black", 0.6) : Color.popups.border
    border.width: cap ? 1.5 : 2
    Rectangle {
      visible: rk.cap
      z: -1
      width: parent.width; height: parent.height; radius: parent.radius
      y: 3
      color: Qt.alpha("black", 0.45)
    }
    // The fill is the capsule itself, painted with a hard-edged gradient, so
    // it follows the rounded ends instead of poking out of them.
    gradient: Gradient {
      GradientStop { position: 0.0; color: rk.body }
      GradientStop { position: Math.max(0.0, 1 - rk.shown - 0.002); color: rk.body }
      GradientStop { position: Math.max(0.002, 1 - rk.shown); color: rk.fillColor }
      GradientStop { position: 1.0; color: rk.fillColor }
    }

    // Press feedback, the same way, for the third under the finger.
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      visible: rk.pressedThird >= 0
      readonly property real from: Math.max(0, rk.pressedThird) / 3
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: Math.max(0.0, parent.from - 0.002); color: "transparent" }
        GradientStop { position: Math.max(0.001, parent.from); color: Qt.alpha(rk.hot, 0.5) }
        GradientStop { position: Math.min(0.999, parent.from + 1 / 3); color: Qt.alpha(rk.hot, 0.5) }
        GradientStop { position: Math.min(1.0, parent.from + 1 / 3 + 0.002); color: "transparent" }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    Column {
      anchors.fill: parent
      Repeater {
        model: ["󰐕", rk.glyph, "󰍴"]
        Item {
          required property string modelData
          required property int index
          width: rk.width; height: rk.height / 3
          Text {
            anchors.centerIn: parent
            text: parent.modelData
            color: rk.mark
            opacity: parent.index === 1 ? 1.0 : 0.8
            font.pixelSize: parent.index === 1 ? 22 : 20
          }
        }
      }
    }

    MouseArea {
      id: upArea
      width: parent.width; height: parent.height / 3
      onPressed: { rk.pressedDown(); rk.up(); again.dir = 1; again.interval = 380; again.start() }
      onReleased: again.stop()
      onCanceled: again.stop()
    }
    MouseArea {
      id: midArea
      y: parent.height / 3
      width: parent.width; height: parent.height / 3
      onPressed: rk.pressedDown()
      onClicked: rk.middle()
    }
    MouseArea {
      id: downArea
      y: parent.height * 2 / 3
      width: parent.width; height: parent.height / 3
      onPressed: { rk.pressedDown(); rk.down(); again.dir = -1; again.interval = 380; again.start() }
      onReleased: again.stop()
      onCanceled: again.stop()
    }
    Timer {
      id: again
      property int dir: 1
      repeat: true
      onTriggered: { interval = rk.repeatMs; if (dir > 0) rk.up(); else rk.down() }
    }
  }

  Gradient {
    id: shellGradient
    GradientStop { position: 0.0; color: root.skin ? root.skin.shellTop : "transparent" }
    GradientStop { position: 1.0; color: root.skin ? root.skin.shellBottom : "transparent" }
  }

  // The pattern across a skin's shell. Drawn once per size or skin change,
  // from a fixed seed, so it does not crawl; clipped to the shell's outline.
  //   spots     irregular blots on a jittered grid, some with a paler heart
  //   stripes   tapering, slightly wavy bands (a tiger's)
  //   confetti  small bright shapes in a few colours
  //   dots      a polka grid
  //   grid      thin lines both ways, a brighter one now and then
  //   ridges    fine horizontal grooves (moulded plastic)
  //   stars     scattered points, a few with a four-point sparkle
  // Little characters scattered over a skin's shell: mermaids, unicorns,
  // fairies. They are emoji, and Canvas text is drawn as outlines, which a
  // colour emoji font does not have (nothing appeared), so each is a Text item
  // instead. Positions come from a fixed seed, like the patterns.
  component CharField: Item {
    id: cf
    property var chars: []
    property int seed: 3
    property bool row: false               // the bar strip: a single row
    property real keepClear: 0             // no characters within this of the bottom corners
    clip: true
    readonly property var spots: {
      var out = [], w = width, h = height
      if (chars.length === 0 || w < 8 || h < 8) return out
      var state = seed * 2654435761 % 4294967296
      function rnd() {
        state = (state + 0x6D2B79F5) | 0
        var t = Math.imul(state ^ (state >>> 15), 1 | state)
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
      }
      var cell = row ? 46 : 32
      for (var ky = 0; ky * cell < (row ? 1 : h); ky++) {
        for (var kx = 0; kx * cell < w; kx++) {
          var skip = rnd() < (row ? 0.45 : 0.3), ch = chars[Math.floor(rnd() * chars.length)]
          var jx = (rnd() - 0.5) * 0.6, jy = (rnd() - 0.5) * 0.6, tilt = (rnd() - 0.5) * 34, size = 14 + rnd() * 6
          var x = (kx + 0.5 + jx) * cell + (ky % 2 ? cell / 2 : 0)
          var y = row ? h / 2 : (ky + 0.5 + jy) * cell
          if (skip || y > h - keepClear) continue
          out.push({ x: x, y: y, ch: ch, tilt: tilt, size: row ? Math.min(size, h * 0.72) : size })
        }
      }
      return out
    }
    Repeater {
      model: cf.spots
      Text {
        required property var modelData
        x: modelData.x - width / 2; y: modelData.y - height / 2
        text: modelData.ch
        font.family: "Noto Color Emoji"
        font.pixelSize: Math.round(modelData.size)
        rotation: modelData.tilt
      }
    }
  }

  component ShellPattern: Canvas {
    id: skin
    property string pattern: "none"
    property int seed: 7
    property real rTL: 0
    property real rTR: 0
    property real rBR: 0
    property real rBL: 0
    property color ink: "black"
    property color glow: "white"
    property var palette: []
    property var chars: []                 // drawn by CharField, not here
    // Where this piece sits on the screen. The repeating patterns (bands,
    // dots, grid, ridges, scales, honeycomb) are laid out in SCREEN
    // coordinates, so they run unbroken from the bar strip into the rails.
    property real ox: 0
    property real oy: 0
    // The bar strip. `base` is painted first (the strip has no rectangle of
    // its own to colour); "wash" paints only its first colour, the one the
    // rails start with; and with `frameRail` > 0 the outline is the strip PLUS
    // a rounded inside corner where it meets each rail, `frameRail` wide,
    // `frameBar` down: the bar and the rails then read as one moulding.
    property color base: "transparent"
    property bool flatWash: false
    property real frameRail: 0
    property real frameBar: 0
    property bool frameFlip: false         // the bottom strip: the same outline, upside down
    property color edge: "transparent"     // a line along the frame's inside edge
    property bool shade: true
    property real soft: 0.72               // how strongly decoration is drawn
    property real edgeWidth: 1
    onPaletteChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onInkChanged: requestPaint()
    onGlowChanged: requestPaint()
    onBaseChanged: requestPaint()
    onEdgeChanged: requestPaint()
    onPatternChanged: requestPaint()
    onVisibleChanged: requestPaint()
    onPaint: {
      var c = getContext("2d"), w = width, h = height
      c.reset()
      if (!visible || w < 4 || h < 4) return
      var state = seed * 2654435761 % 4294967296
      function rnd() {            // mulberry32: small, repeatable
        state = (state + 0x6D2B79F5) | 0
        var t = Math.imul(state ^ (state >>> 15), 1 | state)
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
      }
      function mod(a, n) { return ((a % n) + n) % n }
      var R = h - frameBar                 // the inside corners' radius (frame only)
      c.beginPath()
      if (frameRail > 0 && frameFlip) {
        c.moveTo(0, h); c.lineTo(w, h); c.lineTo(w, 0); c.lineTo(w - frameRail, 0)
        c.arc(w - frameRail - R, 0, R, 0, Math.PI / 2, false)
        c.lineTo(frameRail + R, R)
        c.arc(frameRail + R, 0, R, Math.PI / 2, Math.PI, false)
        c.lineTo(0, 0)
      } else if (frameRail > 0) {
        c.moveTo(0, 0); c.lineTo(w, 0); c.lineTo(w, h); c.lineTo(w - frameRail, h)
        c.arc(w - frameRail - R, h, R, 0, -Math.PI / 2, true)
        c.lineTo(frameRail + R, frameBar)
        c.arc(frameRail + R, h, R, -Math.PI / 2, Math.PI, true)
        c.lineTo(0, h)
      } else {
        c.moveTo(rTL, 0); c.lineTo(w - rTR, 0); c.arcTo(w, 0, w, rTR, rTR)
        c.lineTo(w, h - rBR); c.arcTo(w, h, w - rBR, h, rBR)
        c.lineTo(rBL, h); c.arcTo(0, h, 0, h - rBL, rBL)
        c.lineTo(0, rTL); c.arcTo(0, 0, rTL, 0, rTL)
      }
      c.closePath()
      c.save()
      c.clip()
      if (base.a > 0) { c.fillStyle = base; c.fillRect(0, 0, w, h) }
      // From here on, screen coordinates.
      c.translate(-ox, -oy)
      var X0 = ox, Y0 = oy, X1 = ox + w, Y1 = oy + h
      var x, y, i, k, r0, pal = palette && palette.length ? palette : [ink]
      var parts = pattern === "none" ? [] : pattern.split("+")
      for (var pi = 0; pi < parts.length; pi++) {
        var pat = parts[pi]
        // What IS the shell's colour is painted at full strength; what
        // decorates it sits back a little, so the buttons stay in front.
        var solid = pat === "wash" || pat === "bands" || pat === "pixels"
        c.globalAlpha = solid ? 1 : soft
        if (pat === "wash") {
          var g = c.createLinearGradient(0, Y0, 0, Y1)
          for (k = 0; k < pal.length; k++) g.addColorStop(pal.length > 1 ? k / (pal.length - 1) : 0, pal[k])
          c.fillStyle = flatWash ? pal[0] : g
          c.fillRect(X0, Y0, w, h)
        } else if (pat === "bands") {
          var bh = 20, m = 0.7                       // lines  y + m*x = k*bh
          for (k = Math.floor((Y0 + m * X0) / bh) - 1; k * bh < Y1 + m * X1 + bh; k++) {
            c.fillStyle = pal[mod(k, pal.length)]
            c.beginPath()
            c.moveTo(X0, k * bh - m * X0); c.lineTo(X1, k * bh - m * X1)
            c.lineTo(X1, (k + 1) * bh - m * X1 + 0.6); c.lineTo(X0, (k + 1) * bh - m * X0 + 0.6)
            c.closePath(); c.fill()
          }
        } else if (pat === "dots") {
          var ds = 13, dv = ds * 0.87
          c.fillStyle = ink
          for (r0 = Math.floor(Y0 / dv) - 1; r0 * dv < Y1 + dv; r0++) {
            for (x = Math.floor(X0 / ds) * ds - ds + (mod(r0, 2) ? ds / 2 : 0); x < X1 + ds; x += ds) {
              c.beginPath(); c.arc(x, r0 * dv + ds / 2, 2.6, 0, 6.283); c.fill()
            }
          }
        } else if (pat === "grid") {
          c.lineWidth = 1
          for (x = Math.floor(X0 / 16) * 16 + 8; x < X1; x += 16) {
            c.strokeStyle = ink
            c.beginPath(); c.moveTo(x + 0.5, Y0); c.lineTo(x + 0.5, Y1); c.stroke()
          }
          for (k = Math.floor(Y0 / 16); k * 16 + 8 < Y1; k++) {
            c.strokeStyle = mod(k, 5) === 2 ? glow : ink
            c.beginPath(); c.moveTo(X0, k * 16 + 8.5); c.lineTo(X1, k * 16 + 8.5); c.stroke()
          }
        } else if (pat === "ridges") {
          for (y = Math.floor(Y0 / 6) * 6 + 3; y < Y1; y += 6) {
            c.fillStyle = ink;  c.fillRect(X0, y, w, 1)
            c.fillStyle = glow; c.fillRect(X0, y + 1, w, 1)
          }
        } else if (pat === "scales") {
          var sr2 = 9, sv = sr2 * 0.95
          c.lineWidth = 1.3
          for (r0 = Math.floor(Y0 / sv) - 1; r0 * sv < Y1 + sr2; r0++) {
            for (x = Math.floor(X0 / (sr2 * 2)) * sr2 * 2 - sr2 * 2 + (mod(r0, 2) ? 0 : sr2); x < X1 + sr2; x += sr2 * 2) {
              c.beginPath(); c.arc(x, r0 * sv, sr2, 0, 3.1416)
              c.fillStyle = glow; c.fill()            // each scale shades the one below
              c.strokeStyle = ink; c.stroke()
            }
          }
        } else if (pat === "hex") {
          var hr = 8.5, hw = hr * 1.732, hv = hr * 1.5
          c.strokeStyle = ink; c.lineWidth = 1.4
          for (r0 = Math.floor(Y0 / hv) - 1; r0 * hv < Y1 + hr * 2; r0++) {
            for (x = Math.floor(X0 / hw) * hw - hw + (mod(r0, 2) ? hw / 2 : 0); x < X1 + hw; x += hw) {
              c.beginPath()
              for (k = 0; k < 6; k++) {
                var ha = 3.1416 / 6 + k * 3.1416 / 3
                if (k === 0) c.moveTo(x + hr * Math.cos(ha), r0 * hv + hr * Math.sin(ha))
                else c.lineTo(x + hr * Math.cos(ha), r0 * hv + hr * Math.sin(ha))
              }
              c.closePath(); c.stroke()
            }
          }
        } else if (pat === "spots") {
          var cell = 17
          for (var gy = -1; gy * cell < h + cell; gy++) {
            for (var gx = -1; gx * cell < w + cell; gx++) {
              if (rnd() < 0.16) continue                     // a gap now and then
              var cx = X0 + (gx + 0.5 + (rnd() - 0.5) * 0.8) * cell + (gy % 2 ? cell / 2 : 0)
              var cy = Y0 + (gy + 0.5 + (rnd() - 0.5) * 0.8) * cell
              var r = 3.2 + rnd() * 3.4, n = 7, turn = rnd() * 6.283
              var pts = []
              for (i = 0; i < n; i++) {
                var a = turn + i * 6.283 / n, rr = r * (0.62 + rnd() * 0.6)
                pts.push([cx + Math.cos(a) * rr * 1.15, cy + Math.sin(a) * rr])
              }
              c.beginPath()
              c.moveTo((pts[0][0] + pts[n - 1][0]) / 2, (pts[0][1] + pts[n - 1][1]) / 2)
              for (var j = 0; j < n; j++) {
                var q = pts[j], nx = pts[(j + 1) % n]
                c.quadraticCurveTo(q[0], q[1], (q[0] + nx[0]) / 2, (q[1] + nx[1]) / 2)
              }
              c.closePath()
              c.fillStyle = ink
              c.fill()
              if (rnd() < 0.3) {                             // a few carry a paler heart
                c.beginPath(); c.arc(cx, cy, r * 0.28, 0, 6.283)
                c.fillStyle = glow; c.fill()
              }
            }
          }
        } else if (pat === "stripes") {
          c.fillStyle = ink
          var along = w > h * 3                              // the strip: stripes run across it
          for (var t0 = -10; t0 < (along ? w : h) + 20; t0 += 15 + rnd() * 12) {
            var span = along ? h : w
            var fromA = rnd() < 0.5, len = span * (0.55 + rnd() * 0.5), thick = 3.5 + rnd() * 4.5
            var p0 = fromA ? -2 : span + 2, p1 = fromA ? len : span - len
            var bend = (rnd() - 0.5) * 16, drop = 6 + rnd() * 10
            c.beginPath()
            if (along) {
              c.moveTo(X0 + t0 - thick, Y0 + p0)
              c.quadraticCurveTo(X0 + t0 + bend - thick * 0.6, Y0 + (p0 + p1) / 2, X0 + t0 + drop, Y0 + p1)
              c.quadraticCurveTo(X0 + t0 + bend + thick * 0.9, Y0 + (p0 + p1) / 2, X0 + t0 + thick, Y0 + p0)
            } else {
              c.moveTo(X0 + p0, Y0 + t0 - thick)
              c.quadraticCurveTo(X0 + (p0 + p1) / 2, Y0 + t0 + bend - thick * 0.6, X0 + p1, Y0 + t0 + drop)
              c.quadraticCurveTo(X0 + (p0 + p1) / 2, Y0 + t0 + bend + thick * 0.9, X0 + p0, Y0 + t0 + thick)
            }
            c.closePath()
            c.fill()
          }
        } else if (pat === "confetti") {
          var colours = [ink, glow, "#ffcc00", "#3ddc84"]
          for (i = 0; i < w * h / 190; i++) {
            c.save()
            c.translate(X0 + rnd() * w, Y0 + rnd() * h); c.rotate(rnd() * 3.14)
            c.globalAlpha = (0.55 + rnd() * 0.3) * soft
            c.fillStyle = colours[Math.floor(rnd() * colours.length)]
            if (rnd() < 0.5) c.fillRect(-2.2, -1, 4.4, 2)
            else { c.beginPath(); c.arc(0, 0, 1.5, 0, 6.283); c.fill() }
            c.restore()
          }
        } else if (pat === "stars") {
          for (i = 0; i < w * h / 210; i++) {
            x = X0 + rnd() * w; y = Y0 + rnd() * h
            var big = rnd() < 0.09, sr = big ? 1.5 : 0.5 + rnd() * 0.9
            c.globalAlpha = (0.45 + rnd() * 0.55) * soft
            c.fillStyle = rnd() < 0.3 ? glow : ink
            c.beginPath(); c.arc(x, y, sr, 0, 6.283); c.fill()
            if (big) {
              c.strokeStyle = ink; c.lineWidth = 0.8
              c.beginPath(); c.moveTo(x - 4.5, y); c.lineTo(x + 4.5, y)
              c.moveTo(x, y - 4.5); c.lineTo(x, y + 4.5); c.stroke()
            }
          }
        } else if (pat === "seeds") {
          var sc = 19
          for (var sy = 0; sy * sc < h + sc; sy++) {
            for (var sx = 0; sx * sc < w + sc; sx++) {
              if (rnd() < 0.2) continue
              c.save()
              c.translate(X0 + (sx + 0.5 + (rnd() - 0.5) * 0.7) * sc + (sy % 2 ? sc / 2 : 0), Y0 + (sy + 0.5 + (rnd() - 0.5) * 0.7) * sc)
              c.rotate((rnd() - 0.5) * 1.2)
              c.beginPath()
              c.moveTo(0, -4.2); c.quadraticCurveTo(3.4, 0.5, 0, 4.6); c.quadraticCurveTo(-3.4, 0.5, 0, -4.2)
              c.fillStyle = ink; c.fill()
              c.beginPath(); c.arc(-0.7, -1.2, 0.8, 0, 6.283); c.fillStyle = glow; c.fill()
              c.restore()
            }
          }
        } else if (pat === "traces") {
          c.lineWidth = 1.5; c.lineJoin = "round"
          for (i = 0; i < Math.max(w, h) / 22; i++) {
            x = X0 + Math.round(rnd() * w / 8) * 8; y = Y0 + Math.round(rnd() * h / 8) * 8
            c.beginPath(); c.moveTo(x, y)
            for (k = 0; k < 3 + Math.floor(rnd() * 3); k++) {
              var step2 = (2 + Math.floor(rnd() * 5)) * 8 * (rnd() < 0.5 ? -1 : 1)
              if ((k % 2) === (w > h * 3 ? 0 : 1)) x += step2; else y += Math.abs(step2) * (w > h * 3 ? 0.25 : 1)
              c.lineTo(x, y)
            }
            c.strokeStyle = ink; c.stroke()
            c.beginPath(); c.arc(x, y, 2.6, 0, 6.283); c.fillStyle = glow; c.fill()      // a solder pad
            c.beginPath(); c.arc(x, y, 1.0, 0, 6.283); c.fillStyle = "#99000000"; c.fill()
          }
        } else if (pat === "pixels") {
          var px = 8
          for (y = Math.floor(Y0 / px) * px; y < Y1; y += px) {
            for (x = Math.floor(X0 / px) * px; x < X1; x += px) {
              if (rnd() < 0.45) continue
              c.fillStyle = pal[Math.floor(rnd() * pal.length)]
              c.fillRect(x, y, px, px)
            }
          }
        }
      }
      c.globalAlpha = 1
      c.translate(ox, oy)
      if (frameRail > 0 && shade) {
        // Light from above: a sheen along the top edge, falling to shadow
        // where the frame meets the screen. The rails are shaded the same way
        // across their width, so the whole frame reads as one raised moulding.
        // (flipped: the outside edge, and so the sheen, is at the bottom)
        var sg = frameFlip ? c.createLinearGradient(0, h, 0, R) : c.createLinearGradient(0, 0, 0, frameBar)
        sg.addColorStop(0, "rgba(255,255,255,0.16)")
        sg.addColorStop(0.45, "rgba(255,255,255,0)")
        sg.addColorStop(1, "rgba(0,0,0,0.30)")
        c.fillStyle = sg; c.fillRect(0, frameFlip ? R : 0, w, frameBar)
        c.fillStyle = "rgba(0,0,0,0.30)"; c.fillRect(0, frameFlip ? 0 : frameBar, w, R)
      }
      c.restore()
      if (frameRail > 0 && edge.a > 0) {       // the frame's inside edge, round the corners
        c.strokeStyle = edge; c.lineWidth = edgeWidth
        var e = edgeWidth / 2
        c.beginPath()
        if (frameFlip) {
          c.moveTo(w - frameRail - e, 0)
          c.arc(w - frameRail - R, 0, R - e, 0, Math.PI / 2, false)
          c.lineTo(frameRail + R, R - e)
          c.arc(frameRail + R, 0, R - e, Math.PI / 2, Math.PI, false)
        } else {
          c.moveTo(w - frameRail - e, h)
          c.arc(w - frameRail - R, h, R - e, 0, -Math.PI / 2, true)
          c.lineTo(frameRail + R, frameBar + e)
          c.arc(frameRail + R, h, R - e, -Math.PI / 2, Math.PI, true)
        }
        c.stroke()
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
  // The controller is a grip on the screen, not a card floating beside it: it
  // runs flush to the screen edges and is rounded only on the window side.
  readonly property int edgeGap: controller ? 0 : railGap
  readonly property int shellRadius: 26
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
    exclusiveZone: root.railSize + root.edgeGap
    anchors { right: true; bottom: true; top: !rail.upright; left: rail.upright }
    implicitWidth: root.railSize + root.edgeGap
    implicitHeight: root.railSize + root.edgeGap

    Rectangle {
      anchors.fill: parent
      anchors.rightMargin: root.edgeGap
      anchors.bottomMargin: root.edgeGap
      anchors.topMargin: rail.upright ? 0 : root.edgeGap
      anchors.leftMargin: rail.upright ? root.edgeGap : 0
      radius: Style.cornerRadius
      // Controller: square against the screen edges, round towards the windows.
      // Joined to the bar strip above: no corner there, the strip supplies it.
      topLeftRadius: root.controller ? (root.barSkinned && !rail.upright ? 0 : root.shellRadius) : radius
      topRightRadius: root.controller ? (rail.upright ? root.shellRadius : 0) : radius
      bottomLeftRadius: root.controller ? (rail.upright || root.barSkinned ? 0 : root.shellRadius) : radius
      bottomRightRadius: root.controller ? 0 : radius
      color: Qt.alpha(Color.popups.background, Color.popups.background.a * root.railOpacity)
      // Controller look: a moulded shell, lighter than the caps set into it.
      gradient: root.controller ? shellGradient : null
      // Joined to the bar: no outline of its own (it would draw a line across
      // the join); the frame's inside edge is drawn separately instead.
      border.color: root.controller ? root.frameEdge : Color.popups.border
      border.width: root.controller ? (root.barSkinned ? 0 : root.frameEdgeWidth) : 2

      ShellPattern {
        anchors.fill: parent
        anchors.margins: root.barSkinned ? 0 : root.frameEdgeWidth
        visible: root.skin !== null
        pattern: root.skin ? root.skin.pattern : "none"
        seed: 11
        ox: rail.screen ? rail.screen.width - root.railSize : 0
        oy: Style.bar.sizeHorizontal
        rTL: parent.topLeftRadius; rTR: parent.topRightRadius
        rBR: parent.bottomRightRadius; rBL: parent.bottomLeftRadius
        ink: root.skin ? root.skin.ink : "transparent"
        glow: root.skin ? root.skin.glow : "transparent"
        palette: root.skin && root.skin.palette ? root.skin.palette : []
      }

      Rectangle {       // light on the outer edge, shadow towards the screen
        visible: root.skin !== null
        anchors.fill: parent
        topLeftRadius: parent.topLeftRadius; topRightRadius: parent.topRightRadius
        bottomLeftRadius: parent.bottomLeftRadius; bottomRightRadius: parent.bottomRightRadius
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: Qt.alpha("black", 0.30) }
          GradientStop { position: 0.55; color: "transparent" }
          GradientStop { position: 1.0; color: Qt.alpha("white", 0.14) }
        }
      }
      CharField {
        anchors.fill: parent
        visible: root.skin !== null
        chars: root.skin && root.skin.chars ? root.skin.chars : []
        seed: 5
        keepClear: root.barSkinned ? 0 : root.shellRadius
      }

      Rectangle {       // the frame's inside edge, down the rail (joined to the bar only)
        visible: root.barSkinned && !rail.upright
        x: 0; y: root.frameRadius
        width: root.frameEdgeWidth; height: parent.height - root.frameRadius * 2 - root.bezel
        color: root.frameEdge
      }

      GridLayout {
        anchors.fill: parent
        anchors.margins: 7
        flow: rail.upright ? GridLayout.LeftToRight : GridLayout.TopToBottom
        rowSpacing: 10
        columnSpacing: 10

        TouchButton {

          skin: root.skin

          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: root.closeArmed ? "Close?" : "󰅖"
          danger: true
          glyphSize: root.closeArmed ? 12 : 24
          boldGlyph: root.closeArmed
          active: root.closeArmed
          activeColor: Color.urgent
          onTapped: root.closeTapped()
        }

        TouchButton {

          skin: root.skin

          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰊓"
          onTapped: root.toggleMaximise()
        }
        TouchButton {
          skin: root.skin
          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          visible: !root.dual
          glyph: "󰀻"
          onTapped: root.run(["omarchy-menu", "toggle", "apps"])
        }
        TouchButton {
          skin: root.skin
          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          visible: !root.dual
          glyph: root.stayAwake ? "󰅶" : "󰛊"
          active: root.stayAwake
          onTapped: root.toggleStayAwake()
          holdMs: 600
          heldGlyph: "󰒓"
          onHeld: root.settingsOpen = true
        }

        ScrollStrip {

          skin: root.skin
          Layout.alignment: Qt.AlignCenter
          Layout.fillHeight: !rail.upright
          Layout.fillWidth: rail.upright
          horizontal: rail.upright
          onAim: root.run([root.home + "/.local/bin/tablet-touch", "scroll-aim"])
          onWheel: (notches) => Quickshell.execDetached(["ydotool", "mousemove", "--wheel", "-x", "0", "-y", String(notches)])
        }

        TouchButton {

          skin: root.skin

          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰓡"
          onTapped: root.run([root.home + "/.local/bin/tablet-touch", "next-window"])
        }

        TouchButton {

          skin: root.skin

          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰌌"
          onTapped: root.run([root.home + "/.local/bin/tablet-osk", "toggle"])
        }
        TouchButton {

          skin: root.skin

          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          visible: !root.dual      // two rails: this arrow is on the left one
          glyph: "󰁍"
          heldGlyph: "󰖯"
          holdMs: root.carryMs
          onTapped: root.wsTapped("r-1")
          onHeld: root.wsHeld("r-1")
        }
        Rectangle {
          Layout.alignment: Qt.AlignCenter
          implicitWidth: 30; implicitHeight: 22
          radius: 11
          // On a skin the number sits on a chip of cap colour: a bare number
          // is lost on a patterned shell.
          color: root.skin ? root.skin.cap : "transparent"
          border.width: root.skin ? 1 : 0
          border.color: Qt.alpha("black", 0.5)
          Text {
            anchors.centerIn: parent
            text: Hyprland.focusedWorkspace !== null ? Hyprland.focusedWorkspace.id : ""
            color: root.skin ? root.skin.legend : Color.popups.text
            opacity: root.skin ? 1.0 : 0.75
            font.pixelSize: root.skin ? 14 : 17
            font.bold: true
          }
        }
        TouchButton {
          skin: root.skin
          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰁔"
          heldGlyph: "󰖯"
          holdMs: root.carryMs
          onTapped: root.wsTapped("r+1")
          onHeld: root.wsHeld("r+1")
        }

        TouchButton {
          skin: root.skin
          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰌑"
          onTapped: root.run(["ydotool", "key", "28:1", "28:0"])
        }
        MicButton {
          skin: root.skin
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
  // most used first: launcher, then media, volume and brightness, with stay
  // awake out of the way at the top.
  PanelWindow {
    id: railLeft
    visible: root.noKeyboard && root.dual
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"
    WlrLayershell.namespace: "omarchy-tablet-rail"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: root.railSize + root.edgeGap
    anchors { left: true; top: true; bottom: true }
    implicitWidth: root.railSize + root.edgeGap
    implicitHeight: root.railSize + root.edgeGap

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: root.edgeGap
      anchors.topMargin: root.edgeGap
      anchors.bottomMargin: root.edgeGap
      radius: Style.cornerRadius
      topRightRadius: root.controller ? (root.barSkinned ? 0 : root.shellRadius) : radius
      bottomRightRadius: root.controller ? (root.barSkinned ? 0 : root.shellRadius) : radius
      topLeftRadius: root.controller ? 0 : radius
      bottomLeftRadius: root.controller ? 0 : radius
      color: Qt.alpha(Color.popups.background, Color.popups.background.a * root.railOpacity)
      // Controller look: a moulded shell, lighter than the caps set into it.
      gradient: root.controller ? shellGradient : null
      // Joined to the bar: no outline of its own (it would draw a line across
      // the join); the frame's inside edge is drawn separately instead.
      border.color: root.controller ? root.frameEdge : Color.popups.border
      border.width: root.controller ? (root.barSkinned ? 0 : root.frameEdgeWidth) : 2

      ShellPattern {
        anchors.fill: parent
        anchors.margins: root.barSkinned ? 0 : root.frameEdgeWidth
        visible: root.skin !== null
        pattern: root.skin ? root.skin.pattern : "none"
        seed: 29
        ox: 0
        oy: Style.bar.sizeHorizontal
        rTL: parent.topLeftRadius; rTR: parent.topRightRadius
        rBR: parent.bottomRightRadius; rBL: parent.bottomLeftRadius
        ink: root.skin ? root.skin.ink : "transparent"
        glow: root.skin ? root.skin.glow : "transparent"
        palette: root.skin && root.skin.palette ? root.skin.palette : []
      }

      Rectangle {       // light on the outer edge, shadow towards the screen
        visible: root.skin !== null
        anchors.fill: parent
        topLeftRadius: parent.topLeftRadius; topRightRadius: parent.topRightRadius
        bottomLeftRadius: parent.bottomLeftRadius; bottomRightRadius: parent.bottomRightRadius
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: Qt.alpha("white", 0.14) }
          GradientStop { position: 0.45; color: "transparent" }
          GradientStop { position: 1.0; color: Qt.alpha("black", 0.30) }
        }
      }
      CharField {
        anchors.fill: parent
        visible: root.skin !== null
        chars: root.skin && root.skin.chars ? root.skin.chars : []
        seed: 9
        keepClear: root.barSkinned ? 0 : root.shellRadius
      }

      Rectangle {
        visible: root.barSkinned
        x: parent.width - width; y: root.frameRadius
        width: root.frameEdgeWidth; height: parent.height - root.frameRadius * 2 - root.bezel
        color: root.frameEdge
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 7
        spacing: 10

        TouchButton {
          skin: root.skin
          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰒓"
          active: root.settingsOpen
          onTapped: root.settingsOpen = !root.settingsOpen
        }
        TouchButton {

          skin: root.skin

          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: root.stayAwake ? "󰅶" : "󰛊"
          active: root.stayAwake
          onTapped: root.toggleStayAwake()
        }

        Item { Layout.fillHeight: true }

        // Brightness and volume, each a rocker that shows its level.
        Rocker {
          skin: root.skin
          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰃟"
          level: root.brightness
          onUp: root.brightnessStep("+5%")
          onDown: root.brightnessStep("5%-")
        }
        Rocker {
          skin: root.skin
          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: root.muted ? "󰖁" : "󰕾"
          level: root.volume
          off: root.muted
          onUp: root.run(["omarchy-audio-output-volume", "raise"])
          onDown: root.run(["omarchy-audio-output-volume", "lower"])
          onMiddle: root.run(["omarchy-audio-output-volume", "mute-toggle"])
        }

        Item { Layout.fillHeight: true }

        // Previous workspace here, next on the right rail: each under its own thumb.
        TouchButton {
          skin: root.skin
          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰁍"
          heldGlyph: "󰖯"
          holdMs: root.carryMs
          onTapped: root.wsTapped("r-1")
          onHeld: root.wsHeld("r-1")
        }
        // Play / pause; hold for the next track.
        TouchButton {
          skin: root.skin
          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰐎"
          heldGlyph: "󰒭"
          holdMs: root.carryMs
          onTapped: root.run(["omarchy-shell", "media", "playPause"])
          onHeld: root.run(["omarchy-shell", "media", "next"])
        }
        TouchButton {

          skin: root.skin

          onPressedDown: root.click()
          Layout.alignment: Qt.AlignCenter
          glyph: "󰀻"
          onTapped: root.run(["omarchy-menu", "toggle", "apps"])
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

  // ------------------------------------------------------- the bar strip
  PanelWindow {
    id: barStrip
    visible: root.barSkinned
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"
    WlrLayershell.namespace: "omarchy-tablet-bar"
    // Below the bar (Top) and below the windows: the corner pieces hang down
    // into the gap at the windows' own rounded corners, and nowhere else.
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true }
    implicitHeight: Style.bar.sizeHorizontal + root.frameRadius
    mask: Region {}                      // never takes a touch

    ShellPattern {
      anchors.fill: parent
      visible: root.skin !== null
      base: root.skin ? root.barBase : "transparent"
      flatWash: true
      frameRail: root.dual ? root.railSize : 0.01
      frameBar: Style.bar.sizeHorizontal
      edge: root.frameEdge
      edgeWidth: root.frameEdgeWidth
      pattern: root.skin ? root.skin.pattern : "none"
      seed: 47
      ink: root.skin ? root.skin.ink : "transparent"
      glow: root.skin ? root.skin.glow : "transparent"
      palette: root.skin && root.skin.palette ? root.skin.palette : []
    }
    CharField {
      anchors { top: parent.top; left: parent.left; right: parent.right }
      height: Style.bar.sizeHorizontal
      visible: root.skin !== null
      row: true
      chars: root.skin && root.skin.chars ? root.skin.chars : []
      seed: 13
      opacity: 0.55                      // behind the bar's own writing
    }
  }

  PanelWindow {
    id: bezelStrip
    visible: root.barSkinned
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"
    WlrLayershell.namespace: "omarchy-tablet-bar"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Reserves only the bezel; its corner pieces rise into the windows' corners.
    exclusiveZone: root.bezel
    anchors { bottom: true; left: true; right: true }
    implicitHeight: root.bezel + root.frameRadius
    mask: Region {}

    ShellPattern {
      id: bezelPattern
      anchors.fill: parent
      visible: root.skin !== null
      base: root.skin ? (root.skin.palette && root.skin.pattern.indexOf("wash") >= 0
                         ? root.skin.palette[root.skin.palette.length - 1] : root.skin.shellBottom) : "transparent"
      // "wash" here is the LAST colour: the one the rails end with.
      flatWash: true
      palette: root.skin && root.skin.palette ? [root.skin.palette[root.skin.palette.length - 1]] : []
      frameRail: root.dual ? root.railSize : 0.01
      frameBar: root.bezel
      frameFlip: true
      ox: 0
      oy: bezelStrip.screen ? bezelStrip.screen.height - height : 0
      edge: root.frameEdge
      edgeWidth: root.frameEdgeWidth
      pattern: root.skin ? root.skin.pattern : "none"
      seed: 61
      ink: root.skin ? root.skin.ink : "transparent"
      glow: root.skin ? root.skin.glow : "transparent"
    }
  }

  // ------------------------------------------------------------ settings
  PanelWindow {
    id: settingsWin
    visible: root.settingsOpen
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: Qt.alpha("black", 0.35)
    // The menu's name: bin/tablet-gestures leaves touches on it alone.
    WlrLayershell.namespace: "omarchy-tablet-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    MouseArea { anchors.fill: parent; onClicked: root.settingsOpen = false }   // tap outside: done

    Rectangle {
      id: sheet
      anchors.centerIn: parent
      width: Math.min(parent.width - 170, 720)
      height: sheetBody.implicitHeight + 36
      radius: Math.max(Style.cornerRadius, 14)
      color: Color.popups.background
      border.color: Color.popups.border
      border.width: 2
      MouseArea { anchors.fill: parent }       // taps on the sheet are not "outside"

      ColumnLayout {
        id: sheetBody
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Tablet rails"
            color: Color.popups.text
            font.pixelSize: 20
            font.bold: true
            Layout.fillWidth: true
          }
          Rectangle {
            implicitWidth: 78; implicitHeight: 36; radius: 18
            color: doneArea.pressed ? Color.accent : Qt.alpha(Color.popups.text, 0.10)
            Text { anchors.centerIn: parent; text: "Done"; font.pixelSize: 15
                   color: doneArea.pressed ? Color.background : Color.popups.text }
            MouseArea { id: doneArea; anchors.fill: parent; onClicked: root.settingsOpen = false }
          }
        }

        Text { text: "Look"; color: Color.popups.text; opacity: 0.6; font.pixelSize: 13 }
        GridLayout {
          Layout.fillWidth: true
          columns: 6
          rowSpacing: 8
          columnSpacing: 10
          Repeater {
            model: root.lookNames
            Item {
              id: sw
              required property string modelData
              readonly property var k: root.skinFor(modelData)
              readonly property bool chosen: root.lookPref.trim() === modelData
              Layout.fillWidth: true
              implicitHeight: 76
              // A miniature of the rail: shell, two caps and the accent button.
              Rectangle {
                id: mini
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 52
                radius: 12
                border.width: sw.chosen ? 3 : 1
                border.color: sw.chosen ? Color.accent : Qt.alpha(Color.popups.text, 0.25)
                gradient: Gradient {
                  GradientStop { position: 0.0; color: sw.k ? sw.k.shellTop : Color.popups.background }
                  GradientStop { position: 1.0; color: sw.k ? sw.k.shellBottom : Color.popups.background }
                }
                ShellPattern {
                  anchors.fill: parent
                  anchors.margins: 3
                  visible: sw.k !== null
                  pattern: sw.k ? sw.k.pattern : "none"
                  seed: 5
                  rTL: 9; rTR: 9; rBR: 9; rBL: 9
                  ink: sw.k ? sw.k.ink : "transparent"
                  glow: sw.k ? sw.k.glow : "transparent"
                  palette: sw.k && sw.k.palette ? sw.k.palette : []
                  shade: false
                }
                CharField {
                  anchors.fill: parent
                  anchors.margins: 3
                  visible: sw.k !== null
                  chars: sw.k && sw.k.chars ? sw.k.chars : []
                  seed: 21
                }
                Row {
                  anchors.centerIn: parent
                  spacing: 6
                  Repeater {
                    model: 3
                    Rectangle {
                      required property int index
                      width: 22; height: 22; radius: 11
                      color: sw.k ? (index === 2 ? sw.k.accent : sw.k.cap)
                                  : (index === 2 ? Color.accent : Color.popups.background)
                      border.width: sw.k ? 1.5 : 2
                      border.color: sw.k ? Qt.alpha("black", 0.6) : Color.popups.border
                    }
                  }
                }
              }
              Text {
                anchors { top: mini.bottom; topMargin: 5; horizontalCenter: parent.horizontalCenter }
                text: root.lookLabel(sw.modelData)
                color: Color.popups.text
                font.pixelSize: 12
                font.bold: sw.chosen
              }
              MouseArea { anchors.fill: parent; onPressed: root.click(); onClicked: root.setLook(sw.modelData) }
            }
          }
        }

        // Two-way switches, drawn as a pair of pills with the chosen one filled.
        Repeater {
          model: [
            { title: "Rails", a: "both", aLabel: "Both sides", b: "right", bLabel: "Right only" },
            { title: "Button sounds", a: "on", aLabel: "On", b: "off", bLabel: "Off" }
          ]
          RowLayout {
            id: sw2
            required property var modelData
            required property int index
            readonly property string current: index === 0 ? (root.railsPref.trim() === "right" ? "right" : "both")
                                                           : (root.soundsPref.trim() === "on" ? "on" : "off")
            Layout.fillWidth: true
            spacing: 8
            Text { text: sw2.modelData.title; color: Color.popups.text; font.pixelSize: 15; Layout.fillWidth: true }
            Repeater {
              model: [{ v: sw2.modelData.a, l: sw2.modelData.aLabel }, { v: sw2.modelData.b, l: sw2.modelData.bLabel }]
              Rectangle {
                required property var modelData
                readonly property bool on: sw2.current === modelData.v
                implicitWidth: 112; implicitHeight: 38; radius: 19
                color: on ? Color.accent : Qt.alpha(Color.popups.text, 0.08)
                border.width: on ? 0 : 1
                border.color: Qt.alpha(Color.popups.text, 0.2)
                Text { anchors.centerIn: parent; text: parent.modelData.l; font.pixelSize: 14
                       color: parent.on ? Color.background : Color.popups.text }
                MouseArea {
                  anchors.fill: parent
                  onClicked: { if (sw2.index === 0) root.setRails(parent.modelData.v); else root.setSounds(parent.modelData.v) }
                }
              }
            }
          }
        }
      }
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
