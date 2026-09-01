#Skyrim VR Modders Devkit Documentation

So uh... never really done github before, or C++... or anything about what i just made but somehow it all works.

Anyways it's quite simple. A while ago Valve released an "HMDless" driver for OpenVR called the "null driver". It's essentially a fully customizable virtual VR headset. Normal functionality of the driver is very limited, really only allowing for launching of VR games and nothing else. Using [ar-zadeh's modified null driver](https://github.com/ar-zadeh/VR-Emulator-Driver) and the source files they provided i was able to make my own version of the driver with a few changes. These mostly include foundational changes like modifying the way the HMD and controller positional and rotational data is read and written, along with changing all of the hardcoded keybinds.

This repo is just one part of the whole thing and is really only here so the AHK program i made can download the correct files.

Either way i figure adding some info here wouldn't hurt.

The basics are this. WASD, Space and Control still work natively in SkyrimVR, so those are untouched. You can move around, jump and crouch to your hearts content, but you can't look around. With the modified null driver you can inject HMD rotational data and emulate pitch, yaw and roll movement. Roll is mostly useless for this project but it still is an option.

I guess that's it tbh, idk what else to say besides "Wow! I don't have to put the damn headset on every time i want to test a papyrus script change!!!111!1!!!1!1"
