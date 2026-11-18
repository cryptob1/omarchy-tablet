#!/bin/bash
# bin/tablet-pin: the rules the PIN lives by, and what it does to the PAM file.
python3 - bin/tablet-pin <<'PY'
import importlib.machinery, importlib.util, json, os, sys, tempfile
loader = importlib.machinery.SourceFileLoader("tp", sys.argv[1])
spec = importlib.util.spec_from_loader("tp", loader); tp = importlib.util.module_from_spec(spec); loader.exec_module(tp)
d = tempfile.mkdtemp()
p = {"pin": d + "/cfg/pin", "armed": d + "/run/armed", "fails": d + "/run/fails", "run": d + "/run"}
def ok(name, cond): print(("  ok   - " if cond else "  FAIL - ") + "pin: " + name)
ok("unset before a PIN exists", tp.state(p) == "unset")
salt = os.urandom(16)
tp.write(p["pin"], json.dumps({"salt": salt.hex(), "hash": tp.digest("482917", salt).hex()}))
ok("needs the password first", tp.state(p) == "needs-password" and not tp.check(p, "482917"))
tp.arm(p, now=1000)
ok("ready after a password unlock", tp.state(p, now=1100) == "ready")
ok("the right PIN unlocks", tp.check(p, "482917", now=1100))
ok("a wrong PIN does not, and is counted", not tp.check(p, "111111", now=1100) and tp.read_int(p["fails"]) == 1)
ok("a wrong password is not counted", not tp.check(p, "hunter2!", now=1100) and tp.read_int(p["fails"]) == 1)
ok("the right PIN clears the count", tp.check(p, "482917", now=1100) and tp.read_int(p["fails"]) == 0)
for _ in range(tp.TRIES): tp.check(p, "000001", now=1100)
ok("five wrong PINs turn it off", tp.state(p, now=1100) == "locked" and not tp.check(p, "482917", now=1100))
tp.arm(p, now=1200)
ok("the password turns it back on", tp.check(p, "482917", now=1300))
late = 1200 + tp.MAX_AGE + 1
ok("it expires after 24 hours", tp.state(p, now=late) == "needs-password" and not tp.check(p, "482917", now=late))
ok("a stamp from the future is not trusted", tp.state(p, now=500) == "needs-password")
import io, contextlib
tp.getpass.getpass = lambda prompt="": "4829175"
with contextlib.redirect_stderr(io.StringIO()): seven = tp.cmd_set({k: v + ".new" for k, v in p.items()})
ok("a new PIN is six digits exactly", seven == 1 and not os.path.exists(p["pin"] + ".new"))
ok("six digits at least, digits only", not tp.is_pin("12345") and not tp.is_pin("12345a") and tp.is_pin("123456"))
stack = ["#%PAM-1.0\n",
         "auth       required                    pam_faillock.so preauth silent deny=10 unlock_time=120\n",
         "-auth      [success=2 default=ignore]  pam_systemd_home.so\n",
         "auth       [success=1 default=bad]     pam_unix.so try_first_pass nullok\n",
         "auth       [default=die]               pam_faillock.so authfail deny=10 unlock_time=120\n",
         "auth       optional                    pam_permit.so\n",
         "auth       required                    pam_env.so\n",
         "auth       required                    pam_faillock.so authsucc\n",
         "account    include                     system-local-login\n"]
new = tp.with_pin(stack)
ok("check goes after the lockout line and before the password", new.index(tp.CHECK_LINE) == 2)
ok("arm is the last auth line", new.index(tp.ARM_LINE) == len(new) - 2)
ok("installing twice adds nothing", tp.with_pin(new) == new)
ok("taking it out leaves the original", [l for l in new if tp.MARK not in l] == stack)
ok("a file of another shape is left alone", tp.with_pin(["account include system\n"]) is None)
PY
