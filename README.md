# SkyrimVR Modders Devkit Documentation


## What This Is

A while ago Valve released an "HMDless" driver for OpenVR called the **null driver**. It's essentially a fully customizable virtual VR headset. Normal functionality of the driver is very limited, really only allowing for launching of VR games and nothing else.

Using [ar-zadeh's modified null driver](https://github.com/ar-zadeh/VR-Emulator-Driver) and the source files they provided, I was able to make my own version of the driver with a bunch of changes. These include:

- Rewriting how HMD and controller positional/rotational data is handled to use quaternion-based rotation instead of raw Euler angles, so there's no gimbal lock or other problems with turning.
- Moving all of the actual work into the driver. The AHK program only presses "ghost keys" (F16-F23, keys Windows has but I don't think anyone has a 1980-1990s keyboard with all 24 function keys) and the driver does the turning, the interact timing and the camera moves itself, against its own frame time. That makes it smooth at any frame rate, and it's the reason it can't spin out of control if the AHK program crashes (see "Safety" below).
- Mouse look, handled entirely by the driver (Raw Input, so it has nothing to do with the AHK program).
- Moving the driver's remaining settings out of a `C:\` folder and into `%LOCALAPPDATA%\SkyrimVR Devkit` so there isn't just a new random folder in your C drive.
- A companion AHK-based front end (the "Devkit") that handles all of the setup, toggling, and in-game control so you never have to touch the driver files or SteamVR settings by hand.

This repo is just one part of the whole thing, and is mainly here so the AHK program can download the correct driver files. Figured adding some real info here wouldn't hurt though.

## The Basics

WASD, Space, Control, Shift, Alt and other miscellaneous keys still work natively in SkyrimVR, so movement, jumping, crouching, TAB, journal etc, all work exactly like they normally would. What you *can't* normally do is look around or move your controllers. No headset or controllers means no head or hand tracking, so the camera and controllers just sit there.

The modified null driver fixes that by turning the HMD and both controllers itself, every frame, emulating pitch and yaw. Practically, this means:

- **Arrow keys look up, down, left, and right** (rebindable in the Devkit, not every keyboard has them)
- **Mouse look:** right click in the game to turn it on, right click again to turn it off. While it's on the cursor is held in the middle of the game window and the mouse turns the view.
- Movement (WASD) and looking (arrows or mouse) are fully independent, so you can walk and look around at the same time like a normal game
- Looking up and down stops at straight up / straight down, like a neck
- Inventory, Opening the map, Journal, Settings, nearly every single vanilla keybind works, though they might be in odd spots. For example both Left Control and Left shift are crouch for some reason.
- If you need to get a closer look at something, such as the console, open Quick Commands and press **Move to Console View**. It puts the camera at a spot where the console is readable, and **Reset Camera** puts it back. There's also an optional "Auto console view" setting that does it for you whenever you open the console with `~`. (The old hold-Left-Alt free camera is gone, moving the camera directly tends to screw things up.)

## What The Devkit/AHK Program Actually Does

On top of the driver itself, the front-end tool handles:

- **Setup Checklist:** Opens by itself the first time and walks you through everything, turning each step green once it's done.
- **One-click driver toggle:** A single checkbox flips the null driver on/off in your `steamvr.vrsettings`
- **Auto-downloads and installs the driver:** When you click the Download/Update button it will download the correct files from this repo and install them into SteamVR's own folder (even if SteamVR lives in a second Steam library). It closes SteamVR for you if it needs to (SteamVR locks the driver file while it runs) and double checks that every file actually copied.
- **Movement Mode:** A dedicated toggle that intercepts the look keys, remaps `Q`/`E` to Skyrim's native menu-navigation numpad layout, and remaps Left Shift to Left Alt. Why does it do those things? First off, the only way to navigate specific between tabs in some menus is with Numpad8 and Numpad5, specifically the settings menu. It intercepts Left Shift and sends Left Alt because of what i said earlier. Left Shift is crouch, found out that Left Alt is sprint so i remapped that. Also we intercept E at all times while movement mode is enabled because the game will just crash if you press E. It pauses itself while SkyrimVR's own console is open so you can type in it.
- **Quick console commands:** 20 customizable one click buttons for common testing commands (god mode, noclip, speed changes, teleporting, a janky ass infinite candlelight toggle). You edit them right in the window (tick "Edit mode", or just right click a button), plus a console command box with history, for when you need something the buttons don't cover because trying to type in the console is a pain in the ass for VR, even with this driver.
- **Settings:** Turn sensitivity and speed (changes apply live, no SteamVR restart), mouse sensitivity / invert Y / an off switch for mouse look, rebindable keys, and the virtual headset's render resolution and frame rate (Quest 2/3, Index, Reverb G2 etc, or a custom size). All of it is saved between launches.
- **Update check (optional):** Lets you know when there's a new Devkit release or driver. It asks the first time, and it only reads dates, nothing about you is sent.
- **Copy Diagnostics:** One button that copies everything useful for a bug report, with your Windows user name scrubbed out.
- **A consent screen:** On first run, since the tool does download files, read/write settings, press keys on its own (the ghost keys), briefly touch your clipboard when sending console commands, and the driver watches your mouse for mouse look, i figured adding a consent screen would be nice. Everything is all clearly disclosed up front.

It's basically how you communicate with the driver without a headset or controllers.

### Safety

The look and interact keys are *held* keys, and Windows never releases a key that a program pressed if that program dies. So the Devkit also flips a "heartbeat" ghost key about every 100 ms, and the driver ignores held keys if the heartbeat stops. Close or crash the Devkit and the camera just stops. Mouse look works the same way: it switches itself off and gives your cursor back if the heartbeat stops, if SkyrimVR loses focus, or if the driver unloads, so it can't trap your mouse.

### Limitations

There's only one real limitation right now. Because of how SkyrimVR's console actually processes input, sending a command still needs the in-game console to be open for a moment while it happens, but it's fast enough that it isn't too disruptive. The Devkit also entirely locks down the keyboard while a command is being sent to prevent any issues.

## Building It Yourself

Built in **Visual Studio Community 2022** against **[OpenVR 1.26.7](https://github.com/ValveSoftware/openvr/releases#release-v1.26.7)**, load up `driver_sample.sln`, set the configuration to **Release | x64** and add the OpenVR headers file as a directory (the project expects `C:\SDKs\OpenVR\openvr-1.26.7\headers`, change the include path in `driver_sample.vcxproj` if yours is elsewhere). The DLL it builds gets renamed `driver_null.dll` and goes in `null\bin\win64\` next to a `devkit_version.txt` that matches the Devkit's expected driver version. Almost all of the Devkit-specific code lives in one header, `devkit_input.h`.

---

*"Wow! I don't have to put the damn headset on every time I want to test a Papyrus script change!!!!"*

---

Note: Older releases includes a portable, renamed copy of the AutoHotkey interpreter engine, which is distributed under the GNU General Public License v2. 

The exact matching source code for this engine version (v2.0.27) is included as a zip archive directly inside our older compiled release packages, but can also be found at "https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.27"
