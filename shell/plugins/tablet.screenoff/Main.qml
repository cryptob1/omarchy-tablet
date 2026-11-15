// Screen timeout: display off after `timeoutSeconds` without input.
//
// Omarchy's idle service starts the screensaver and then the lock screen, but
// never switches the panel off — on a tablet's OLED the lock screen then burns
// battery (and pixels) for as long as it sits there. This adds the missing
// last step. It only blanks the display: locking stays with idle.lock.
//
// A film does not trip it: players hold an idle inhibitor, which is respected.
// Neither does Omarchy's "stay awake" toggle. Any input ends the idle state
// and the display comes back.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property int timeoutSeconds: 600
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
  property bool blanked: false

  function dpms(action) {
    Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.dpms({ action = "' + action + '" })'])
  }

  function apply() {
    if (monitor.isIdle && !root.stayAwake) {
      root.blanked = true
      dpms("off")
    } else if (root.blanked) {
      // Only undo our own blanking, so this never fights whatever else
      // switched the display off (a lid, a suspend).
      root.blanked = false
      dpms("on")
    }
  }

  onStayAwakeChanged: apply()

  IdleMonitor {
    id: monitor
    enabled: true
    timeout: root.timeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: root.apply()
  }
}
