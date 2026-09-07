PulsePad Control Center — v2.1.1 (Linux x86_64)
=================================================

A single-file desktop app for the PulsePad phone-to-PC virtual controller.
Double-click (or run) the `PulsePad` executable in this folder.

WHAT IT IS
----------
The daemon runs INSIDE this window (no background processes). Start it,
then connect your phone:

  * Wi-Fi  — phone app → Connect (radar auto-finds this PC, or scan the QR
             shown in the window). Same network required.
  * USB    — phone app → Connect → USB. Wire it once:

                adb reverse tcp:5005 tcp:5005

             (or press "⚡ USB (cable)" — it runs the command for you and
             verifies it). Requires USB debugging on the phone and an
             authorized connection on the phone's "allow USB debugging" popup.

BUTTONS
-------
  ▶ Start Daemon    start listening on this PC (must be on to connect)
  ■ Stop Daemon     stop it (closing the window also stops it)
  ⚠ Enable Gamepad  one-time: make Windows/Linux see a virtual gamepad
  ⚡ USB (cable)    set up the cable link (adb reverse)
  Show QR           a code the phone scans to connect over Wi-Fi

TESTER
------
The "Gamepad" and "Keyboard" tabs mirror whatever you press on the phone, so
you can see every input land on the PC live. The "Help" tab walks through the
Wi-Fi and USB steps inside the app.

FIRST RUN ON LINUX
------------------
If the virtual gamepad can't open /dev/uinput you'll see a warning; press
"⚠ Enable Gamepad" once to install a udev rule (one pkexec/sudo prompt, never
needed again). Games/emulators then see "PulsePad Gamepad" + "PulsePad
Keyboard". Without uinput the daemon still runs (network + tester work).

NOTES
-----
* Closing the window stops the daemon.
* Verify this download: see SHA256SUMS below.