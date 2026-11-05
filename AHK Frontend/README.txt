============================================================
SkyrimVR Devkit v2.0.1
============================================================

HOW TO RUN:

1. Download and Install AutoHotKey v2.0 from https://www.autohotkey.com/

2. Double click "SkyrimVR Devkit.ahk" to open the devkit.

You can open the .ahk file in any text editor to make modifications easily.

FIRST TIME SETUP:

The devkit opens a Setup Checklist by itself the first time. It walks you through everything, including
downloading the null driver (the "Download / Install" button, also under Settings). This version needs the
v2.0.1 null driver, so if you used an older devkit, update the driver there too (the devkit tells you).

============================================================
WHAT'S NEW IN v2.0.1 (since v2.0)
============================================================

THE DRIVER INSTALL IS RELIABLE NOW

- Installing or updating the driver shows a "Please close Steam" window and waits until Steam and SteamVR are
  fully closed before it touches any files. SteamVR (and sometimes Steam itself) keeps the driver file locked,
  which could leave the old driver file sitting next to the new ones. The devkit
  never closes Steam or SteamVR for you, so nothing you have open gets interrupted, it carries on by itself as
  soon as they're closed, and Cancel stops the install without changing anything. If a file is somehow still
  locked after that, it asks you to retry instead of failing silently.
- The driver is now checked, not just assumed. The devkit confirms that driver_null.dll really is the devkit's
  (Steam updating or verifying SteamVR can put SteamVR's own driver_null.dll back while our other files stay,
  which used to look "installed" but do nothing). Every driver zip also carries a SHA-256 for its DLL, so a
  wrong or older file is caught too. If anything is off the Setup Checklist, the Live line and the Download
  button say the driver is damaged and offer "Update / Repair Driver".

DIAGNOSTICS

- The driver now writes a small status report (driver_status.txt in %LOCALAPPDATA%\SkyrimVR Devkit\Actions)
  about once a second while SteamVR runs it: whether it sees the devkit's heartbeat, which keys it has seen,
  mouse activity, yaw and pitch. Copy Diagnostics includes it, along with the driver DLL check.
- If the devkit is sending keys but the driver isn't receiving them, the Live line now says so instead of
  looking fine.

NOTES

- v2.0.1 needs the v2.0.1 null driver. A v2.0.0 driver still works, but the devkit will ask you to update it
  (the repair checks and the status report need the new one).
- The How To describes the new install.

============================================================
WHAT'S NEW IN v2.0 (since v1.0.5, the last version before it)
============================================================

THE BIG CHANGE: THE DRIVER DOES THE WORK NOW

In v1.0.5 this script worked out every turn and move and wrote it to text files for the null driver to read.
In v2.0 the script only tells the driver what you're pressing (using keys no physical keyboard has, F16 to F23)
and the null driver does the turning, the interact timing and the camera moves. That means:

- Turning is smooth and the same at any frame rate.
- If the devkit crashes or you close it, the camera can't keep spinning (the driver ignores held keys once
  the devkit's "heartbeat" stops).
- Looking up and down stops at straight up / straight down, like a neck.
- Interacting is more reliable due to there no longer being controller drift.
- v2.0 needs the v2.0 null driver. Older drivers don't understand the new keys, and the devkit tells you if
  yours is out of date.

MOUSE LOOK (new)

With Movement Mode on and SkyrimVR focused, RIGHT CLICK in the game to turn mouse look on: the cursor is held
in the middle of the game window and moving the mouse turns the view. Right click again to turn it off. It turns
itself off (and gives your cursor back) whenever Movement Mode pauses, you click away from the game or the
devkit closes. The null driver does all of this, not this script. Sensitivity, invert Y and an off switch are in
Settings > Controls. The first time you open this version it asks for your consent to the mouse capture, saying
No just switches mouse look off.

A NEW LAYOUT

- The main window is simpler: Launch SteamVR, Setup Checklist, How To, Settings, and a single
  "Enable Null Driver in SteamVR" checkbox that replaces the Load / Unload Null Driver buttons.
- Settings has four tabs: General (Steam folder, download / update the driver, edit quick commands, copy
  diagnostics, update check), Controls, Keybinds and Display.
- Your settings are now saved. In v1.0.5 the turn sensitivity went back to 1.0 every time you opened the devkit.

CONTROLS

- Settings > Keybinds: rebind the look keys, interact and the menu keys (Q / E), for keyboards without
  arrow keys.
- Settings > Controls: turn sensitivity, base turn speed, console command delay (raise it if commands fail on
  a slow system), auto console view, and the mouse look settings. Changes apply live, with no SteamVR restart.
- The "hold Left Alt" camera movement (Alt + WASD / Q / E) is gone. It was the buggy part, and moving the camera
  directly tends to mess things up. Use the console view buttons below instead.
- Q / E menu navigation and sprint no longer drop or stick keys, and E still can't crash the game while
  Movement Mode is on, even while sprinting.
- Movement Mode pauses by itself while SkyrimVR's own console is open, so you can type in it.

CONSOLE VIEW

- Quick Commands has "Move to Console View" and "Reset Camera" buttons (replacing "Position Camera and
  Controller"). Move to Console View puts the camera at a spot where the console is readable, and pressing it
  twice doesn't move you twice. It turns with you, so it lands in the same place wherever you're looking.
  Reset Camera goes back to the start but keeps the direction you're looking.
- Optional "Auto console view" (Settings > Controls): the camera moves in when you open the game console with
  ~ and back when you close it.
- The position can be tuned without rebuilding anything: edit console_view.txt in
  %LOCALAPPDATA%\SkyrimVR Devkit\Actions and press the button again.

QUICK COMMANDS AND CONSOLE

- Quick Commands are edited right in the window now (no more editing the .ahk): tick "Edit mode" and click a
  button, or just right-click one, to change its label and command. They save to commands.ini and survive
  updates.
- A console command no longer closes a console you already had open (it pastes and leaves it open).
- Toggle Candlelight retries if a recast lands while another command is running.

SETUP, DRIVER AND UPDATES

- A Setup Checklist opens by itself the first time and turns each step green as you finish it.
- Download / Install is much more careful: it waits for Steam and SteamVR to be fully closed before touching any files (SteamVR locks the
  driver file), won't report success unless every file really copied, and tells you exactly what went wrong
  if something didn't. It also finds SteamVR when it's in a second Steam library (another drive).
- Turning on Movement Mode without the devkit's driver (or with an outdated one) warns you once, and the
  "Live" line keeps saying so, instead of silently doing nothing.
- Display tab: pick the virtual headset's render resolution (Quest 2 / 3, Index, Reverb G2 and more, or a
  custom size) and frame rate. It's reapplied after a driver update.
- Optional update check (asks the first time): tells you when a new devkit release or driver is out.
- One-time clean slate for people coming from an older devkit (your Quick Commands are kept), so leftovers
  can't cause problems.
- Copy Diagnostics includes much more (driver and SteamVR folder details, keybinds, display and mouse look
  settings, recent errors) and replaces your Windows user name with USER before you paste it anywhere.
- The consent text now mentions the simulated key presses and the mouse capture.

============================================================
The SkyrimVR Devkit script ("SkyrimVR Devkit.ahk") is free software, licensed under the GNU General Public
License v3. See LICENSE.txt.

This project includes optional SteamVR null driver files located in null driver.zip.
Which are distributed under Valve Software's BSD-3-Clause license included within that archive.
============================================================