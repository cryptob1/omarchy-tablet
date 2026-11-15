#!/bin/bash
# The swipe classifier and the rotation mapping are pure functions; the device
# reading around them needs fingers on glass and is not tested here.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO/tests/lib.sh"
py() { python3 -c "
import importlib.machinery, importlib.util, sys
l = importlib.machinery.SourceFileLoader('tg', '$REPO/bin/tablet-gestures')
m = importlib.util.module_from_spec(importlib.util.spec_from_loader('tg', l)); l.exec_module(m)
print($1)"; }

assert_eq "swipe left"            "left"  "$(py 'm.classify(-0.20, 0.02)')"
assert_eq "swipe right"           "right" "$(py 'm.classify(0.15, -0.03)')"
assert_eq "swipe up"              "up"    "$(py 'm.classify(0.01, -0.12)')"
assert_eq "swipe down"            "down"  "$(py 'm.classify(0.00, 0.30)')"
assert_eq "too short is nothing"  "None"  "$(py 'm.classify(0.03, 0.01)')"
assert_eq "diagonal is nothing"   "None"  "$(py 'm.classify(0.12, 0.11)')"
assert_eq "landscape: unchanged"  "up"    "$(py 'm.rotate("up", 0)')"
assert_eq "90 deg: panel-up is user-right" "right" "$(py 'm.rotate("up", 1)')"
assert_eq "180 deg: flipped"      "down"  "$(py 'm.rotate("up", 2)')"
assert_eq "270 deg"               "left"  "$(py 'm.rotate("up", 3)')"
assert_eq "odd transform ignored" "left"  "$(py 'm.rotate("left", 7)')"

# Three fingers: workspace sideways, launcher up, next window down. Four maximise.
assert_eq "3 fingers sideways"        "left"  "$(py 'm.gesture(3, "left")')"
assert_eq "3 fingers up: launcher"    "up"    "$(py 'm.gesture(3, "up")')"
assert_eq "3 fingers down: next window" "down" "$(py 'm.gesture(3, "down")')"
assert_eq "first touch is a burst"    "True"  "$(py 'm.burst_start(100.0, None)')"
assert_eq "touch after a pause is a burst" "True" "$(py 'm.burst_start(100.0, 95.0)')"
assert_eq "continuous touch is not"   "False" "$(py 'm.burst_start(100.0, 99.5)')"
assert_eq "4 fingers up maximises"    "up"    "$(py 'm.gesture(4, "up")')"
assert_eq "4 fingers down restores"   "down"  "$(py 'm.gesture(4, "down")')"
assert_eq "4 fingers sideways: nothing" "None" "$(py 'm.gesture(4, "right")')"
assert_eq "5 fingers: nothing"        "None"  "$(py 'm.gesture(5, "up")')"

# Two-finger scrolling.
assert_eq "no notch before a full step"  "0"  "$(py 'm.wheel_notches(0.02, 0, 0.022)')"
assert_eq "fingers down = wheel up"      "2"  "$(py 'm.wheel_notches(0.05, 0, 0.022)')"
assert_eq "fingers up = wheel down"      "-2" "$(py 'm.wheel_notches(-0.05, 0, 0.022)')"
assert_eq "only the notches still owed"  "1"  "$(py 'm.wheel_notches(0.07, 2, 0.022)')"
assert_eq "portrait: panel-x is user-y"  "(0, 0.1)" "$(py 'm.to_user(0.1, 0, 1)')"
assert_eq "landscape point -> layout px" "(720, 450)" "$(py 'm.to_layout(0.5, 0.5, {"width":2880,"height":1800,"scale":2,"transform":0,"x":0,"y":0})')"
assert_eq "portrait point -> layout px"  "(225, 720)" "$(py 'm.to_layout(0.5, 0.75, {"width":2880,"height":1800,"scale":2,"transform":1,"x":0,"y":0})')"
assert_eq "terminals scroll, browsers do not" "True False" "$(py '"com.mitchellh.ghostty" in m.SCROLL_CLASSES, "google-chrome" in m.SCROLL_CLASSES' | tr -d "(),")"

# Finding the window under the fingers must not move the pointer (focus follows
# it), and a finger on the floating mic button is never part of a scroll.
L='{"eDP-1":{"levels":{"3":[{"x":1308,"y":568,"w":104,"h":304,"namespace":"omarchy-tablet-rail"},{"x":0,"y":0,"w":1440,"h":30,"namespace":"omarchy-bar"}]}}}'
assert_eq "only the mic layer is ignored" "[(1308, 568, 104, 304)]" "$(py "m.ignored_rects($L)")"
assert_eq "finger on the mic button"      "True"  "$(py "m.inside((1360, 800), m.ignored_rects($L))")"
assert_eq "finger elsewhere"              "False" "$(py "m.inside((400, 400), m.ignored_rects($L))")"
C='[{"class":"chrome","at":[0,0],"size":[700,900],"workspace":{"id":2},"floating":False,"fullscreen":0},{"class":"term","at":[700,0],"size":[700,900],"workspace":{"id":2},"floating":False,"fullscreen":0},{"class":"float","at":[600,300],"size":[300,300],"workspace":{"id":2},"floating":True,"fullscreen":0},{"class":"other","at":[0,0],"size":[1400,900],"workspace":{"id":5},"floating":False,"fullscreen":0}]'
assert_eq "tiled window under the point"  "term"  "$(py "m.window_at((1000, 100), $C, 2)['class']")"
assert_eq "floating window wins"          "float" "$(py "m.window_at((750, 400), $C, 2)['class']")"
assert_eq "other workspaces are invisible" "chrome" "$(py "m.window_at((100, 100), $C, 2)['class']")"
assert_eq "no window there"               "None"  "$(py "m.window_at((1430, 100), $C, 2)")"

# The touch mark (the floating buttons hide without it) is refreshed at most once a second.
assert_eq "first touch marks"        "True"  "$(py 'm.mark_due(100.0, None)')"
assert_eq "same second: no rewrite"  "False" "$(py 'm.mark_due(100.4, 100.0)')"
assert_eq "a second later: again"    "True"  "$(py 'm.mark_due(101.0, 100.0)')"

# Long press: one finger, held, still.
assert_eq "held and still"         "True"  "$(py 'm.is_long_press(0.7, 0.002, 0.001, False, 0.6, 0.012)')"
assert_eq "too short"              "False" "$(py 'm.is_long_press(0.3, 0.0, 0.0, False, 0.6, 0.012)')"
assert_eq "a drag is not a press"  "False" "$(py 'm.is_long_press(0.9, 0.05, 0.0, False, 0.6, 0.012)')"
assert_eq "fires once"             "False" "$(py 'm.is_long_press(0.9, 0.0, 0.0, True, 0.6, 0.012)')"
M='{"width":2880,"height":1800,"scale":2,"transform":0,"x":0,"y":0}'
assert_eq "menu above the finger"      "(574, 310)"  "$(py "m.menu_origin(700, 400, $M)")"
assert_eq "no room above: below"       "(574, 84)"   "$(py "m.menu_origin(700, 50, $M)")"
assert_eq "kept on screen at the edge" "(1180, 310)" "$(py "m.menu_origin(1430, 400, $M)")"
assert_eq "long press skips the keyboard" "True" "$(py '"wvkbd" in m.IGNORE_LAYERS')"

# One finger over a terminal: the direction a drag sets off in decides.
assert_eq "inside the slop: undecided"   "None"   "$(py 'm.one_finger_intent(0.005, 0.010)')"
assert_eq "straight down: scroll"        "scroll" "$(py 'm.one_finger_intent(0.002, 0.020)')"
assert_eq "straight up: scroll"          "scroll" "$(py 'm.one_finger_intent(0.0, -0.020)')"
assert_eq "sideways: select"             "select" "$(py 'm.one_finger_intent(0.020, 0.003)')"
assert_eq "diagonal: select"             "select" "$(py 'm.one_finger_intent(0.020, 0.021)')"
# Fling: speed from the end of the drag, then a decaying run of notches.
assert_eq "moving at lift: notches/s"    "50.0"  "$(py 'round(m.fling_velocity([(0.0, 0.0), (0.05, 0.05), (0.10, 0.10)], step=0.02), 1)')"
assert_eq "upward fling is negative"     "-50.0" "$(py 'round(m.fling_velocity([(0.0, 0.0), (0.10, -0.10)], step=0.02), 1)')"
assert_eq "stopped before lifting: none" "0.0"   "$(py 'm.fling_velocity([(0.0, 0.0), (0.05, 0.05), (0.50, 0.05)], step=0.02)')"
assert_eq "one sample: none"             "0.0"   "$(py 'm.fling_velocity([(0.0, 0.0)])')"
assert_eq "speed is capped"              "220.0" "$(py 'm.fling_velocity([(0.0, 0.0), (0.05, 5.0)], step=0.02)')"
assert_eq "a fling travels and stops"    "True"  "$(py '(lambda s: 5 < sum(s) < 60 and len(s) * m.FLING_TICK < m.FLING_MAX)(m.fling_steps(60.0))')"
assert_eq "a fling keeps its direction"  "True"  "$(py 'all(n <= 0 for n in m.fling_steps(-60.0)) and sum(m.fling_steps(-60.0)) < -5')"
assert_eq "too slow: nothing"            "[]"    "$(py 'm.fling_steps(2.0)')"

# Focus history: what tablet-touch restores after the mic button is touched.
assert_eq "first focus"   "{'current': ['0xa', 1.0], 'previous': None}" "$(py 'm.focus_step({}, "0xa", 1.0)')"
assert_eq "focus moves"   "{'current': ['0xb', 2.0], 'previous': ['0xa', 1.0]}" "$(py 'm.focus_step({"current": ["0xa", 1.0]}, "0xb", 2.0)')"
assert_eq "focus on nothing is not history" "{'current': ['0xa', 1.0]}" "$(py 'm.focus_step({"current": ["0xa", 1.0]}, "", 2.0)')"
tt() { python3 -c "
import importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader('tt', '$REPO/bin/tablet-touch')
m = importlib.util.module_from_spec(importlib.util.spec_from_loader('tt', l)); l.exec_module(m)
print($1)"; }
H='{"current": ["0xb", 100.0], "previous": ["0xa", 50.0]}'
assert_eq "focus settled: keep it"            "0xb" "$(tt "m.focus_before($H, 105.0)")"
assert_eq "focus just jumped: the one before" "0xa" "$(tt "m.focus_before($H, 100.2)")"
assert_eq "no history"                        ""    "$(tt 'm.focus_before({}, 1.0)')"
# The rail's switch button: next window on this workspace, in a stable order.
W='[{"address":"0xc","workspace":{"id":1}},{"address":"0xa","workspace":{"id":1}},{"address":"0xb","workspace":{"id":2}},{"address":"0xd","workspace":{"id":1},"hidden":True},{"address":"0xe","workspace":{"id":1}}]'
assert_eq "next window"                    "0xc" "$(tt "m.next_window($W, 1, '0xa')")"
assert_eq "next again"                     "0xe" "$(tt "m.next_window($W, 1, '0xc')")"
assert_eq "wraps round"                    "0xa" "$(tt "m.next_window($W, 1, '0xe')")"
assert_eq "nothing focused: the first"     "0xa" "$(tt "m.next_window($W, 1, '')")"
assert_eq "only window: nowhere to go"     ""    "$(tt "m.next_window($W, 2, '0xb')")"
assert_eq "empty workspace"                ""    "$(tt "m.next_window($W, 3, '')")"
# The focus lock: held while the finger is down, ended by Cortex finishing, a
# newer press, or a later touch (the user choosing another window).
G='{"press": 10.0, "current_press": 10.0'
assert_eq "finger down: hold"          ""                  "$(tt "m.guard_over($G}, 50.0, 12.0, 49.0)")"
assert_eq "released, busy: hold"       ""                  "$(tt "m.guard_over($G, 'release': 20.0}, 21.0, None, 15.0)")"
assert_eq "released, dictation done"      "dictation done"    "$(tt "m.guard_over($G, 'release': 20.0}, 23.0, 21.5, 15.0)")"
assert_eq "released, just went idle"   ""                  "$(tt "m.guard_over($G, 'release': 20.0}, 21.6, 21.5, 15.0)")"
assert_eq "touched after release"      "touched elsewhere" "$(tt "m.guard_over($G, 'release': 20.0}, 21.0, None, 20.6)")"
assert_eq "newer press owns the lock"  "newer press"       "$(tt "m.guard_over({'press': 10.0, 'current_press': 30.0}, 31.0, None, 0)")"
assert_eq "stuck: give up"             "timeout"           "$(tt "m.guard_over($G}, 200.0, None, 0)")"
