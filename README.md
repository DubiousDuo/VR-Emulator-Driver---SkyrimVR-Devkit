# SkyrimVR Modders Devkit Documentation


## What This Is

A while ago Valve released an "HMDless" driver for OpenVR called the **null driver**. It's essentially a fully customizable virtual VR headset. Normal functionality of the driver is very limited, really only allowing for launching of VR games and nothing else.

Using [ar-zadeh's modified null driver](https://github.com/ar-zadeh/VR-Emulator-Driver) and the source files they provided, I was able to make my own version of the driver with a bunch of changes. These include:

- Rewriting how HMD and controller positional/rotational data is read and written to use quaternion-based rotation instead of raw Euler angles, so there's no gimbal lock or other problems with turning.
- Remapping hardcoded keybinds to F13-F24 so we can have our own "virtual keyboard" since I don't think anyone has a 1980-1990s keyboard with all 24 function keys.
- Moving the driver's data files out of a `C:\` folder and into `%PROGRAMDATA%` so there isn't just a new random folder in your C drive.
- A companion AHK-based front end (the "Devkit") that handles all of the setup, toggling, and in-game control so you never have to touch the driver files or SteamVR settings by hand

This repo is just one part of the whole thing, and is mainly here so the AHK program can download the correct driver files. Figured adding some real info here wouldn't hurt though.

## The Basics

WASD, Space, Control, Shift, Alt and other miscellaneous keys still work natively in SkyrimVR, so movement, jumping, crouching, TAB, journal etc, all work exactly like they normally would. What you *can't* normally do is look around or move your controllers. No headset or controllers means no head or hand tracking, so the camera and controllers just sit there.

The modified null driver fixes that by injecting rotational data directly into the HMD's and controller's pose every frame, emulating pitch, yaw, and roll. Roll is mostly useless for this project but it's there if you want it. Practically, this means:

- **Arrow keys look up, down, left, and right**
- Movement (WASD) and looking (arrows) are fully independent, so you can walk and look around at the same time like a normal game
- Inventory, Opening the map, Journal, Settings, nearly every single vanilla keybind works, though they might be in odd spots. For example both Left Control and Left shift are crouch for some reason.

## What The Devkit/AHK Program Actually Does

On top of the driver itself, the front-end tool handles:

- **One-click driver toggle** — flips the null driver on/off in your `steamvr.vrsettings`
- **Auto-downloads and installs the driver** straight from this repo (when you click the button)
- **Movement Mode** — a dedicated toggle that intercepts arrow keys for looking, remaps `Q`/`E` to Skyrim's native menu-navigation numpad layout, and remaps Left Shift to Left Alt. Why does it do those things? First off, the only way to navigate specific between tabs in some menus is with Numpad8 and Numpad5, specifically the settings menu. It intercepts Left Shift and sends Left Alt because of what i said earlier. Left Shift is crouch, found out that Left Alt is sprint so i remapped that. Also we intercept E at all times while movement mode is enabled because the game will just crash if you press E.
- **Quick console commands** — a few customizable one click buttons for common testing commands (god mode, noclip, speed changes, teleporting, a janky ass infinite candlelight toggle), plus a  console command box with history, for when you need something the buttons don't cover because trying to type in the console is a pain in the ass for VR, even with this driver.
- **Adjustable turn sensitivity**, live, via a slider
- **A consent screen** on first run, since the tool does download files, read/write settings, and briefly touch your clipboard when sending console commands — all clearly disclosed up front, and only with a Yes/No you control every time

It's basically how you communicate with the driver without a headset or controllers.

There's only one real limitation right now. Because of how SkyrimVR's console actually processes input, sending a command still needs the in-game console to be open for a moment while it happens — but it's fast enough that it's not really disruptive.

## Building It Yourself

Built in **Visual Studio Community 2022** against **[OpenVR 1.26.7](https://github.com/ValveSoftware/openvr/releases#release-v1.26.7)**, load up the project file and add the OpenVR headers file as a directory.

---

*"Wow! I don't have to put the damn headset on every time I want to test a Papyrus script change!!!!"*
