#Requires AutoHotkey v2.0
#SingleInstance Force

DllCall("winmm\timeBeginPeriod", "UInt", 1)
OnExit((*) => DllCall("winmm\timeEndPeriod", "UInt", 1))

TurnSpeed  := 216.0
TurnSensitivity := 1.0
LookTickMs := 16.66
ConsoleMS  := 25

MenuActions     := ["MoveUp", "MoveDown"]
ControlActions  := ["LookUp", "LookDown", "LookLeft", "LookRight", "Interact"]
AllBindActions  := []
for action in MenuActions
    AllBindActions.Push(action)
for action in ControlActions
    AllBindActions.Push(action)

GhostKeys := Map("LookUp", "F16", "LookDown", "F17", "LookLeft", "F18", "LookRight", "F19", "Interact", "F20")
GhostHeld := Map("LookUp", false, "LookDown", false, "LookLeft", false, "LookRight", false, "Interact", false)
GhostReposition := "F21"
GhostReset      := "F22"
GhostHeartbeat  := "F23"
HeartbeatEveryMs := 100
HeartbeatState := false
HeartbeatLastMs := 0
HeartbeatSent := 0
MovementKeyLabels := Map(
    "MoveUp",      "Menu Right",
    "MoveDown",    "Menu Left",
    "LookUp",      "Look Up",
    "LookDown",    "Look Down",
    "LookLeft",    "Look Left",
    "LookRight",   "Look Right",
    "Interact",    "Interact"
)
MovementKeyDefaults := Map(
    "MoveUp",      "sc012", ; E
    "MoveDown",    "sc010", ; Q
    "LookUp",      "sc148", ; Up arrow
    "LookDown",    "sc150", ; Down arrow
    "LookLeft",    "sc14B", ; Left arrow
    "LookRight",   "sc14D", ; Right arrow
    "Interact",    "sc013"  ; R
)
MovementKeyBinds := Map()

ActionDir    := ""
ControlsFile := ""

MovementModeRequested := false
MovementMode := false
ConsoleDialogOpen := false
ConsoleDialogHwnd := 0
SetupInstalledVer := ""
GameConsoleOpen := false 
AutoConsoleView := false


MouseLookEnabled := true
MouseSensitivity := 1.0
MouseBaseSens := 0.05
MouseInvertY := false
DownloadBusy := false

SetupGui := ""
SetupRows := Map()
SetupOrder := ["steam", "oc", "mde", "driver", "enabled", "steamvr", "game", "move"]

RenderPresets := [
    {Name: "Quest 2 (devkit default)",       W: 1832, H: 1920},
    {Name: "Quest 3",                         W: 2064, H: 2208},
    {Name: "Quest Pro",                       W: 1800, H: 1920},
    {Name: "Valve Index / HTC Vive Pro",      W: 1440, H: 1600},
    {Name: "HTC Vive / Oculus Rift CV1",      W: 1080, H: 1200},
    {Name: "HP Reverb G2 / Pico 4",           W: 2160, H: 2160},
    {Name: "PlayStation VR2",                 W: 2000, H: 2040},
    {Name: "HTC Vive Pro 2",                  W: 2448, H: 2448}
]
FpsOptions := [30, 45, 60, 72, 80, 90, 120, 144]
UpdateLiveMovementMode()

RepoURL := "https://github.com/DubiousDuo/VR-Emulator-Driver---SkyrimVR-Devkit/raw/main/null%20driver.zip"

; This is NOT a build/release version for the AHK tool itself, this is for the driver. For anyone reading this, PLEASE don't touch these, this is for the tool to make sure things aren't fucked.
ExpectedDriverVersion := "2.0.1"

ScriptVersion := "2.0.1" ; Same as the other one, except for the Frontend only.

CandlelightOn := false

DefaultCommands := [
    {Label: "TP Inside Whiterun",    Command: "coc whiterunorigin"},
    {Label: "TP To Whiterun Bridge", Command: "coc whiterun"},
    {Label: "Toggle God Mode",       Command: "tgm"},
    {Label: "Toggle Noclip",         Command: "tcl"},
    {Label: "Super Speed",           Command: "player.setav speedmult 400"},
    {Label: "Normal Speed",          Command: "player.setav speedmult 100"},
    {Label: "Toggle Combat AI",      Command: "tcai"},
    {Label: "Toggle Candlelight",    Command: "@candlelight"},
    {Label: "Big Ass Fireball",      Command: "player.cast 0007A82B player right"}
]
CommandSlots := 20
CustomCommands := []
CommandsFile := ""

RunConsoleSlot(command, *) {
    SendConsoleCommand(command)
}

WriteDefaultCommandsFile() {
    global CommandsFile, DefaultCommands, CommandSlots
    try {
        FileAppend("; SkyrimVR Devkit quick commands. Edit Label / Command for each slot, save, then close and reopen the Quick Commands window.`n; Commands are console commands without the opening ~ (use lowercase). A blank Command makes that button do nothing.`n; Use Command=@candlelight for the candlelight toggle.`n`n", CommandsFile, "UTF-16")
        Loop CommandSlots {
            def := A_Index <= DefaultCommands.Length ? DefaultCommands[A_Index] : {Label: "Command " A_Index, Command: ""}
            IniWrite(def.Label, CommandsFile, "Slot" A_Index, "Label")
            IniWrite(def.Command, CommandsFile, "Slot" A_Index, "Command")
        }
    } catch as e {
        LogError("WriteDefaultCommandsFile failed: " e.Message)
    }
}

LoadCustomCommands() {
    global CustomCommands, CommandsFile, CommandSlots
    if !FileExist(CommandsFile)
        WriteDefaultCommandsFile()

    CustomCommands := []
    Loop CommandSlots {
        label   := Trim(IniRead(CommandsFile, "Slot" A_Index, "Label", "Command " A_Index))
        command := Trim(IniRead(CommandsFile, "Slot" A_Index, "Command", ""))
        if label = ""
            label := "Command " A_Index
        action := (command = "@candlelight") ? ToggleCandlelight : RunConsoleSlot.Bind(command)
        CustomCommands.Push({Label: label, Action: action})
    }
}

OpenCommandsFile(*) {
    global CommandsFile
    if !FileExist(CommandsFile)
        LoadCustomCommands()
    Run('notepad.exe "' CommandsFile '"')
}


ToggleCandlelight(*) {
    global CandlelightOn
    if CandlelightOn {
        SetTimer(RefreshCandlelight, 0)
        SetTimer(RetryCandlelight, 0)
        CandlelightOn := false
        SendConsoleCommand("player.dispel 00043324")
    } else if SendConsoleCommand("player.cast 00043324 player right") {
        SetTimer(RefreshCandlelight, 59000) ; refresh every 59s, 1s before it peters out
        CandlelightOn := true
    }
}

RefreshCandlelight() {
    global ConsoleCommandBusy
    if ConsoleCommandBusy {
        SetTimer(RetryCandlelight, -1500)
        return
    }
    SendConsoleCommand("player.cast 00043324 player right")
}

RetryCandlelight() {
    global CandlelightOn
    if CandlelightOn
        RefreshCandlelight()
}

HowToSections := [
    {Title: "Getting Started", Body:
    (
        "Just a quick little guide on how to get this up and running.`n`n"
		"MOST IMPORTANT STEP IS DISABLING OPEN COMPOSITE IN YOUR SKYRIMVR INSTALL IF YOU HAVE IT!!!!`n`n"
		"OpenComposite bypasses the entirety of SteamVR which is REALLY bad because it's how the null driver even works. So please, disable it temporarily. Also yeah if you don't have SteamVR installed you kinda need that.`n`n"
		"Same goes for Movement Dialogue Enabler: disable it in your modlist while you're using the devkit.`n`n"
		"The 'Setup Checklist...' button opens a list of every step below and turns each one green when it's done. It opens by itself the first time, so you can just follow that if you'd like.`n`n"
		"Step 0.5 is making sure steam is actually detected, if it's not you're going to have to set the path to your steam folder manually (Settings > General > 'Set / Change Steam Folder...'). The tool should have asked you to do that already, but it never hurts to check.`n`n"
        "First thing you're gonna want to do is open 'Settings...' and press 'Download / Update Null Driver from GitHub' on the General tab.`n`n"
        "After that's all done, you can go ahead and tick the 'Enable Null Driver in SteamVR' checkbox on the main window.`n`n"
		"Then finally, if you want to test if that all worked, you can click 'Launch SteamVR' and if it launches without complaining you don't have a headset, then you're good to go!`n`n"
		"Once SkyrimVR is running, click its window and turn on 'Movement Mode' on the main window (see the Movement Mode section)."
    )},
    {Title: "Null Driver", Body:
    (
        "This section explains a bit on how the whole Null Driver thing works.`n`n"
		"Basically, the null driver is an OpenVR driver made by Valve that tricks SteamVR and games into thinking you're wearing a VR headset.`n`n"
		"Normally this doesnt have very many uses because the only thing you can do is just launch the game, with my modifed version of it that allows us to do a lot more.`n`n"
		"If you want to read more, you can read more on my GitHub, this menu is meant to be more in depth about the actual devkit itself and what it does.`n`n"
		"Anyways, there are a few things that the Devkit does in regards to the Null Driver.`n`n"
		"The 'Enable Null Driver in SteamVR' checkbox is quite simple. Through some trial and error i found that there is a specific file you can edit to essentially flip the null driver on and off. That's what the checkbox does. After the first install when you click 'Download / Update', the checkbox is how we control when and when not the null driver loads.`n`n"
        "It's quite simple how to use it. If you want to use the devkit, tick the checkbox, and if you dont' want to, untick it and you're back to normal SteamVR.`n`n"
		"IMPORTANT: SteamVR already comes with its OWN null driver folder built in, for Valve's own testing. That one is NOT the same as this devkit's, and it will NOT let you move around or use console commands. 'Download / Update' checks for this tool's own version marker, and if what's installed isn't ours (or is out of date) it automatically replaces it with the devkit's driver.`n`n"
		"Steam and SteamVR keep the driver file locked while they're running, so before replacing the driver the devkit shows a 'Please close Steam' window and waits until both are fully closed (it never closes them for you, so nothing you have open gets interrupted). Close them from the system tray and it carries on by itself; Cancel stops the install and changes nothing. After installing, 'Download / Update' also checks that the driver file really is the devkit's and offers 'Update / Repair Driver' if Steam or an update put SteamVR's own file back. If SteamVR is installed on a second drive (another Steam library) that's found automatically.`n`n"
		"Settings > Display changes the virtual headset's render resolution and frame rate (pick a headset preset or a custom size). Restart SteamVR after applying."
    )},
	{Title: "Moving Around", Body:
    (
        "This section explains how to move, look around and do things.`n`n"
		"It's quite simple to be fair. You move around with WASD, look around with the arrow keys, navigate system menus with Q/E, interact with objects by pressing R, sprint by using Left Shift. No arrow keys on your keyboard (or they don't work)? Open Settings > Keybinds and rebind look, interact and the menu keys to whatever you like.`n`n"
		"Most stock Skyrim keys work. TAB opens the cross menu, ESC opens the settings menu, J opens the journal, etc.`n`n"
		"If you need to look at something more closey, such as a menu or the console to read data off of it, open 'Quick Commands...' and press 'Move to Console View', which puts the camera at a spot where the console is readable ('Reset Camera' puts it back). If you'd rather not do that by hand, tick 'Auto console view' in Settings > Controls and the camera moves in when you open the game console with ~ and back when you close it. There's no free camera movement any more, because moving the camera directly tends to screw things up.`n`n"
			"MOUSE LOOK: you can also look around with the mouse. While Movement Mode is live and SkyrimVR is focused, RIGHT-CLICK in the game to turn mouse look on; the cursor gets held in the middle of the window and moving the mouse turns the view. Right-click again to turn it off and get your cursor back. It turns itself off, within about half a second, whenever Movement Mode pauses (console open, you click away from the game, the devkit closes), so you'll never be stuck without a cursor. Sensitivity, invert Y and an off switch are in Settings > Controls. This is done by the null driver, so it needs the v2.0 driver."
    )},
    {Title: "Movement Mode", Body:
    (
        "This section explains what 'Movement Mode' does.`n`n"
        "The main thing you want to do when you load up SkyrimVR is to enable 'Movement Mode'. Movement mode is a toggle we use to know when you actually want to use your keyboard as we take the liberty to intercept multiple keys on your keyboard when movement mode is enabled so they dont screw with other things.`n`n"
        "'Movement Mode: ON' means we intercept your look keys (the 4 arrow keys by default, including when Shift is pressed), your interact key (R), Left Shift and Left Alt, plus your Menu Right / Menu Left keys (E and Q by default). It pauses itself while SkyrimVR's own console (the ~ key) is open so you can type in it, and picks back up when you close it. If it ever gets out of sync, toggling Movement Mode off and on fixes it.`n`n"
		"The 'Live:' line under the button tells you what's going on. ACTIVE means it's working, 'waiting' means SkyrimVR isn't the focused window, and 'paused' means a console is open (the game's or the devkit's). It also tells you if the devkit's driver is missing or out of date.`n`n"
		"'Movement Mode: OFF' means that you have full control over your keyboard once again. It's a simple toggle that also vanishes if you close the program. So you're always in full control over when your keys are getting intercepted.`n`n"
		"We mostly do this because SkyrimVR's keys are really weird, one of them is just confirmed to be an instant CTD and also because this Devkit is quite complicated in what it does. We have to remap many keys to different functions because we are essentially recreating the normal Skyrim movement but in VR, things are gonna get janky."
    )},
    {Title: "Console Commands", Body:
    (
        "This section explains what the Quick Commands do and how we manipulate the Console for our use cases.`n`n"
        "The Quick Commands are quite simple, they are just predetermined commands or commands you set yourself that get exected when you click the button to do so.`n`n"
        "Biggest thing about this is that your ENTIRE keyboard is blocked from being used while we execute console commands. It's for a very short time, under 350ms. We do this because we can't directly inject console commands into the game without a companion SKSE mod and that was out of the scope of this tool. If someone wants to make that then go right ahead. Anyways, that means we have to manually 'type' out the console commands and if you happen to press a key as the window is open the command just fails, which we don't want.`n`n"
		"The 'Send Console Command' button is exactly what it says. You click it, type in a console command and it executes it in game. Why is it there? Because as you will come to learn, you can't see jack SHIT when trying to read the console in VR. Comes in handy when you're trying to type out console commands since you can actually see what you're typing.`n`n"
		"Another time we intercept your full keyboard is exactly every 59 seconds when you use the 'Toggle Candlelight' button I don't think there is a way to modify how long a spell lasts via commands. So we recast the spell VIA console commands right before it runs out.`n`n"
		"If commands fail on a slower PC, raise 'Console Command Delay' in Settings > Controls. And if the game console is already open when a command is sent, the devkit just pastes into it and leaves it open.`n`n"
		"You can add your own Quick Commands right in the 'Quick Commands...' window: tick 'Edit mode' and click any of the 20 buttons (or just right-click a button) to change its label and command. Your changes are saved straight away and kept when the devkit updates. If you'd rather edit the raw file, it's in Settings > 'Edit Quick Commands File...' (save it, then close and reopen the Quick Commands window)."
    )},
    {Title: "Troubleshooting", Body:
    (
        "This section is for troubleshooting tips.`n`n"
		"Can't look around or use console commands at all, even though the driver loaded fine? Open Settings and click 'Download / Update Null Driver from GitHub' again. SteamVR ships its own placeholder null driver, and if the download failed or never finished, that's almost certainly what's loaded instead of this devkit's.`n`n"
        "Movement Mode says ON but nothing happens? Look at the 'Live:' line under the button. It has to say ACTIVE, which needs SkyrimVR to be the focused window and no console open.`n`n"
		"Mouse stuck, or mouse look won't turn off? Turn Movement Mode off (or click away from the game) and the driver gives the cursor back within half a second. If it ever doesn't, close the devkit. Mouse look can be switched off for good in Settings > Controls.`n`n"
        "Still stuck? Open Settings and click 'Copy Diagnostics' on the General tab, paste the result wherever you're asking for help, and it'll save a lot of back and forth."
    )}
]


NullDriverKey  := "driver_null"
NullDriverAddonIdk := '`t"driver_null" : {`n`t`t"enable" : true,`n`t`t"id" : "Null Driver",`n`t`t"windowHeight" : 1080,`n`t`t"windowWidth" : 1920`n`t}'


ScriptDir := A_ScriptDir

OldRoot := EnvGet("PROGRAMDATA") "\SkyrimVR Devkit"
Root    := EnvGet("LOCALAPPDATA") "\SkyrimVR Devkit"
ErrorLogFile := Root "\error_log.txt"

CleanSlateLegacySeen := DirExist(OldRoot) || FileExist(Root "\steam_location.ini")

MigratedFromOldLocation := false
if !DirExist(Root) && DirExist(OldRoot) {
    try {
        DirMove(OldRoot, Root, 2)
        MigratedFromOldLocation := true
    } catch as e {
        LogError("Migration from ProgramData failed: " e.Message)
    }
}

if !DirExist(Root)
    DirCreate(Root)
BootstrapFile := Root "\steam_location.ini"
CommandsFile  := Root "\commands.ini"

LoadControlSettings() {
    global TurnSpeed, TurnSensitivity, ConsoleMS, BootstrapFile, AutoConsoleView
    global MouseLookEnabled, MouseSensitivity, MouseInvertY
    AutoConsoleView := (IniRead(BootstrapFile, "Controls", "AutoConsoleView", "0") = "1")
    MouseLookEnabled := (IniRead(BootstrapFile, "Controls", "MouseLookEnabled", "1") = "1")
    MouseInvertY := (IniRead(BootstrapFile, "Controls", "MouseInvertY", "0") = "1")
    v := IniRead(BootstrapFile, "Controls", "MouseSensitivity", "")
    if IsNumber(v) && v > 0
        MouseSensitivity := ClampNum(v, 0.1, 3.0)
    v := IniRead(BootstrapFile, "Controls", "TurnSpeed", "")
    if IsNumber(v) && v > 0
        TurnSpeed := ClampNum(v, 10.0, 1000.0)
    v := IniRead(BootstrapFile, "Controls", "TurnSensitivity", "")
    if IsNumber(v) && v > 0
        TurnSensitivity := ClampNum(v, 0.1, 3.0)
    v := IniRead(BootstrapFile, "Controls", "ConsoleMS", "")
    if IsNumber(v) && v >= 5
        ConsoleMS := ClampNum(v, 5, 500)
}

SaveControlSettings() {
    global TurnSpeed, TurnSensitivity, ConsoleMS, BootstrapFile, AutoConsoleView
    global MouseLookEnabled, MouseSensitivity, MouseInvertY
    try {
        IniWrite(AutoConsoleView ? "1" : "0", BootstrapFile, "Controls", "AutoConsoleView")
        IniWrite(MouseLookEnabled ? "1" : "0", BootstrapFile, "Controls", "MouseLookEnabled")
        IniWrite(Format("{:.2f}", MouseSensitivity), BootstrapFile, "Controls", "MouseSensitivity")
        IniWrite(MouseInvertY ? "1" : "0", BootstrapFile, "Controls", "MouseInvertY")
        IniWrite(Format("{:.1f}", TurnSpeed), BootstrapFile, "Controls", "TurnSpeed")
        IniWrite(Format("{:.2f}", TurnSensitivity), BootstrapFile, "Controls", "TurnSensitivity")
        IniWrite(String(ConsoleMS), BootstrapFile, "Controls", "ConsoleMS")
    }
    WriteDriverControls()
}

WriteDriverControls() {
    global TurnSpeed, TurnSensitivity, ControlsFile
    global MouseLookEnabled, MouseSensitivity, MouseBaseSens, MouseInvertY
    if ControlsFile = ""
        return
    speed := Min(TurnSpeed * TurnSensitivity, 1800.0)
    text := "turn_speed " Format("{:.1f}", speed) "`n"
          . "mouse_enabled " (MouseLookEnabled ? 1 : 0) "`n"
          . "mouse_sens " Format("{:.4f}", MouseBaseSens * MouseSensitivity) "`n"
          . "mouse_invert_y " (MouseInvertY ? 1 : 0) "`n"
    try {
        f := FileOpen(ControlsFile, "w")
        f.Write(text)
        f.Close()
    } catch as e {
        LogError("WriteDriverControls failed: " e.Message)
    }
}

QueueSaveControlSettings() {
    SetTimer(SaveControlSettings, -400)
}

OnAutoConsoleViewChanged(ctrl, *) {
    global AutoConsoleView
    AutoConsoleView := ctrl.Value = 1
    QueueSaveControlSettings()
}

OnMouseLookChanged(ctrl, *) {
    global MouseLookEnabled
    MouseLookEnabled := ctrl.Value = 1
    QueueSaveControlSettings()
}

OnMouseInvertChanged(ctrl, *) {
    global MouseInvertY
    MouseInvertY := ctrl.Value = 1
    QueueSaveControlSettings()
}

OnMouseSensChange(ctrl, *) {
    global MouseSensitivity, MouseSensLabel
    MouseSensitivity := ctrl.Value / 100.0
    MouseSensLabel.Text := Format("{:.2f}x", MouseSensitivity)
    QueueSaveControlSettings()
}

LoadControlSettings()
LoadCustomCommands()


;Globals
SteamDir    := ""
DevkitDir   := ""
StagingDir  := ""
StagingFile := ""
ConfigFile  := ""
LivePath    := ""
Active      := "Original"

;Figure out where Steam is
SteamDir := DetectSteamDir()
if SteamDir = ""
    SteamDir := IniRead(BootstrapFile, "Paths", "SteamDir", "")
EnsureDevkitPaths()

OfferCleanSlate()

if MigratedFromOldLocation
    MsgBox("This tool's settings folder moved to a new location:`n`n" Root "`n`n(previously: " OldRoot ")`n`nYour Steam path, console history, and other settings were carried over automatically. This is a one-time message.", "Settings Moved", "Iconi")

ShowConsentDisclaimerIfNeeded()


;GUI
DarkBG     := 0x1E1E1E
DarkBGStr  := "1E1E1E"
DarkFG     := 0xE0E0E0
DarkFGStr  := "E0E0E0"
DarkCtrlBG := 0x000000
InputFGStr := "E0E0E0"

ApplyDarkTitlebar(guiObj) {
    attr := Buffer(4, 0)
    NumPut("Int", 1, attr)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", guiObj.Hwnd, "Int", 20, "Ptr", attr, "Int", 4)
}

MainGui := Gui("+Resize", "SkyrimVR Devkit")
MainGui.BackColor := DarkBGStr
MainGui.SetFont("s10 c" DarkFGStr)
MainGui.MarginX := 15
MainGui.MarginY := 15
ApplyDarkTitlebar(MainGui)

MainGui.AddButton("w420", "Launch SteamVR").OnEvent("Click", (*) => Run("steam://rungameid/250820"))

MainGui.AddButton("w420 y+8", "Setup Checklist...").OnEvent("Click", ShowSetupChecklist)

MainGui.AddButton("w420 y+8", "How To").OnEvent("Click", ShowHowTo)

MainGui.AddButton("w420 y+8", "Settings...").OnEvent("Click", OpenSettings)

MainGui.AddText("w420 y+18", "Currently active:")
StatusText := MainGui.AddText("w420 cWhite y+2", "")

ChkDriverEnabled := MainGui.AddCheckBox("w420 y+10", "Enable Null Driver in SteamVR")
ChkDriverEnabled.OnEvent("Click", ToggleDriverEnabled)

;Movement section
MainGui.AddText("x15 y+22 w420", "Check 'How To' for information")

BtnMovement := MainGui.AddButton("x15 y+8 w420 h32", "Movement Mode: OFF  (Keys work normally.)")
BtnMovement.OnEvent("Click", ToggleMovementMode)

MovementLiveText := MainGui.AddText("x15 y+4 w420 cSilver", "Live: off")

OnSensitivityChange(ctrl, *) {
    global TurnSensitivity
    TurnSensitivity := ctrl.Value / 100.0
    SensLabel.Text := Format("{:.2f}x", TurnSensitivity)
    QueueSaveControlSettings()
}

;Quick Commands popout toggle
QuickCommandsGui := ""
QuickEditMode := false
SlotEditorGui := ""

CloseQuickCommandsWindow(*) {
    global QuickCommandsGui, QuickEditMode, SlotEditorGui
    try SlotEditorGui.Destroy()
    SlotEditorGui := ""
    try QuickCommandsGui.Destroy()
    QuickCommandsGui := ""
    QuickEditMode := false
}
CloseHowToWindow(*) {
    global HowToGui
    try HowToGui.Destroy()
    HowToGui := ""
}

FocusWindow(g) {
    try {
        if WinGetMinMax(g.Hwnd) = -1
            WinRestore(g.Hwnd)
        WinActivate(g.Hwnd)
        return true
    }
    return false ; window is already gone
}

ShowQuickCommands(*) {
    global QuickCommandsGui
    if IsObject(QuickCommandsGui) {
        if FocusWindow(QuickCommandsGui)
            return
        QuickCommandsGui := ""
    }
    BuildQuickCommandsWindow()
}

BuildQuickCommandsWindow(x := "", y := "") {
    global QuickCommandsGui, CustomCommands, QuickEditMode, DarkBGStr, DarkFGStr

    LoadCustomCommands()
    QuickCommandsGui := Gui("+Resize", QuickEditMode ? "Quick Commands (edit mode)" : "Quick Commands")
    QuickCommandsGui.BackColor := DarkBGStr
    QuickCommandsGui.SetFont("s10 c" DarkFGStr)
    QuickCommandsGui.MarginX := 15
    QuickCommandsGui.MarginY := 15
    ApplyDarkTitlebar(QuickCommandsGui)

    BtnCloseDash := QuickCommandsGui.AddButton("x15 y15 w200 h28", "Close Dashboard")
    BtnCloseDash.OnEvent("Click", (*) => TestPulse("F13"))

    BtnNudge := QuickCommandsGui.AddButton("x235 y15 w200 h28", "Move to Console View")
    BtnNudge.OnEvent("Click", MoveToConsoleView)

    BtnResetCam := QuickCommandsGui.AddButton("x15 y+8 w200 h28", "Reset Camera")
    BtnResetCam.OnEvent("Click", ResetCameraView)

    chkEdit := QuickCommandsGui.AddCheckBox("x235 yp+4 w200", "Edit mode (click a button to edit it)")
    chkEdit.Value := QuickEditMode ? 1 : 0
    chkEdit.OnEvent("Click", OnEditModeToggle)

    quickText := QuickCommandsGui.AddText("x15 y+18 w420", "Quick Commands (right-click a button to edit it):")
    quickText.GetPos(&qx, &qy, &qw, &qh)

    btnW := 200, btnH := 30, gapX := 20, gapY := 8
    gridX := qx
    gridY := qy + qh + 8

    for index, cmd in CustomCommands {
        row := (index - 1) // 2
        col := Mod(index - 1, 2)
        bx := gridX + col * (btnW + gapX)
        by := gridY + row * (btnH + gapY)
        btn := QuickCommandsGui.AddButton("x" bx " y" by " w" btnW " h" btnH, cmd.Label)
        btn.OnEvent("Click", OnQuickSlotClick.Bind(index))
        btn.OnEvent("ContextMenu", OnQuickSlotRightClick.Bind(index))
    }

    QuickCommandsGui.OnEvent("Close", CloseQuickCommandsWindow)
    QuickCommandsGui.Show(x != "" ? "x" x " y" y : "")
}

OnQuickSlotClick(index, *) {
    global QuickEditMode, CustomCommands
    if QuickEditMode
        ShowSlotEditor(index)
    else
        CustomCommands[index].Action()
}

OnQuickSlotRightClick(index, *) {
    ShowSlotEditor(index)
}

OnEditModeToggle(ctrl, *) {
    global QuickEditMode, QuickCommandsGui
    QuickEditMode := (ctrl.Value = 1)
    QuickCommandsGui.Title := QuickEditMode ? "Quick Commands (edit mode)" : "Quick Commands"
}

RefreshQuickCommandsWindow() {
    global QuickCommandsGui
    if !IsObject(QuickCommandsGui)
        return
    try {
        QuickCommandsGui.GetPos(&x, &y)
        QuickCommandsGui.Destroy()
    } catch {
        QuickCommandsGui := ""
        return
    }
    QuickCommandsGui := ""
    BuildQuickCommandsWindow(x, y)
}

ShowSlotEditor(index) {
    global SlotEditorGui, QuickCommandsGui, CommandsFile, DarkBGStr, DarkFGStr, DarkCtrlBG, InputFGStr

    if IsObject(SlotEditorGui) {
        if FocusWindow(SlotEditorGui)
            return
        SlotEditorGui := ""
    }

    label   := Trim(IniRead(CommandsFile, "Slot" index, "Label", "Command " index))
    command := Trim(IniRead(CommandsFile, "Slot" index, "Command", ""))

    opts := "+AlwaysOnTop"
    if IsObject(QuickCommandsGui)
        opts .= " +Owner" QuickCommandsGui.Hwnd
    editor := Gui(opts, "Edit Quick Command " index)
    SlotEditorGui := editor
    editor.BackColor := DarkBGStr
    editor.SetFont("s10 c" DarkFGStr)
    editor.MarginX := 15
    editor.MarginY := 15
    ApplyDarkTitlebar(editor)

    editor.AddText("w400", "Button label:")
    labelEdit := editor.AddEdit("w400 Background" DarkCtrlBG " c" InputFGStr, label)
    editor.AddText("x15 y+12 w400", "Console command:")
    cmdEdit := editor.AddEdit("w400 Background" DarkCtrlBG " c" InputFGStr, command)
    editor.AddText("x15 y+8 w400 cSilver", "Lowercase, without the opening ~ (for example: tgm). Use @candlelight for the candlelight toggle. A blank command makes the button do nothing.")

    BtnSave  := editor.AddButton("x15 y+14 w125 h30 Default", "Save")
    BtnClear := editor.AddButton("x+10 yp w125 h30", "Clear fields")
    BtnCancel := editor.AddButton("x+10 yp w125 h30", "Cancel")

    CloseEditor(*) {
        global SlotEditorGui
        SlotEditorGui := ""
        editor.Destroy()
    }

    ClearFields(*) {
        labelEdit.Text := "Command " index
        cmdEdit.Text := ""
        labelEdit.Focus()
    }

    SaveSlot(*) {
        newLabel := Trim(RegExReplace(labelEdit.Text, "[\r\n]+", " "))
        newCmd   := Trim(RegExReplace(cmdEdit.Text, "[\r\n]+", " "))
        if newLabel = ""
            newLabel := "Command " index
        try {
            IniWrite(newLabel, CommandsFile, "Slot" index, "Label")
            IniWrite(newCmd, CommandsFile, "Slot" index, "Command")
        } catch as e {
            LogError("Saving quick command slot " index " failed: " e.Message)
            MsgBox("Couldn't save to:`n" CommandsFile "`n`n" e.Message, "Save Failed", "IconX")
            return
        }
        CloseEditor()
        RefreshQuickCommandsWindow()
    }

    BtnSave.OnEvent("Click", SaveSlot)
    BtnClear.OnEvent("Click", ClearFields)
    BtnCancel.OnEvent("Click", CloseEditor)
    editor.OnEvent("Close", CloseEditor)
    editor.OnEvent("Escape", CloseEditor)
    editor.Show("w430")
    labelEdit.Focus()
}

BtnQuickCommands := MainGui.AddButton("x15 y+22 w420 h32", "Quick Commands...")
BtnQuickCommands.OnEvent("Click", ShowQuickCommands)

;How To popout toggle
HowToGui := ""
ShowHowTo(*) {
    global HowToGui, HowToSections, DarkBGStr, DarkFGStr, DarkCtrlBG, InputFGStr

    if IsObject(HowToGui) {
        if FocusWindow(HowToGui)
            return
        HowToGui := ""
    }

    HowToGui := Gui("+Resize", "SkyrimVR Devkit - How To")
    HowToGui.BackColor := DarkBGStr
    HowToGui.SetFont("s10 c" DarkFGStr)
    HowToGui.MarginX := 15
    HowToGui.MarginY := 15
    ApplyDarkTitlebar(HowToGui)

    tabTitles := []
    for section in HowToSections
        tabTitles.Push(section.Title)

    HowToTabs := HowToGui.AddTab3("x15 y15 w550 h420", tabTitles)

    for index, section in HowToSections {
        HowToTabs.UseTab(index)
        HowToGui.AddEdit("x35 y55 w510 h370 ReadOnly -E0x200 Background" DarkCtrlBG " c" InputFGStr, section.Body)
    }
    HowToTabs.UseTab()

    BtnCloseHowTo := HowToGui.AddButton("x15 y450 w550 h30", "Close")
    BtnCloseHowTo.OnEvent("Click", CloseHowToWindow)

    HowToGui.OnEvent("Close", CloseHowToWindow)
    HowToGui.Show()
}

SettingsGui := ""

OpenSettings(*) {
    global SettingsGui, DarkBGStr, DarkFGStr, DarkCtrlBG, InputFGStr
    global SteamDir, LivePath, TurnSensitivity, TurnSpeed, ConsoleMS, AutoConsoleView
    global MouseLookEnabled, MouseSensitivity, MouseInvertY, MouseSensLabel
    global SteamEdit, LiveEdit, BtnDownload, SensLabel, SensSlider, BootstrapFile
    global MenuActions, ControlActions, MovementKeyLabels, MovementKeyBinds, MovementKeyDefaults
    global RenderPresets, FpsOptions, DispPresetDDL, DispWEdit, DispHEdit, DispFpsDDL, DispStatus

    if IsObject(SettingsGui) {
        if FocusWindow(SettingsGui)
            return
        SettingsGui := ""
    }

    SettingsGui := Gui("+Resize", "SkyrimVR Devkit - Settings")
    SettingsGui.BackColor := DarkBGStr
    SettingsGui.SetFont("s10 c" DarkFGStr)
    SettingsGui.MarginX := 15
    SettingsGui.MarginY := 15
    ApplyDarkTitlebar(SettingsGui)

    SettingsTabs := SettingsGui.AddTab3("x15 y15 w460 h500", ["General", "Controls", "Keybinds", "Display"])

    SettingsTabs.UseTab(1)
    SettingsGui.AddText("x35 y55 w420", "Steam install folder:")
    SteamEdit := SettingsGui.AddEdit("x35 y+4 w420 ReadOnly Background" DarkCtrlBG " c" InputFGStr, SteamDir ? SteamDir : "(not detected - click below to choose it)")
    SettingsGui.AddButton("x35 y+8 w420", "Set / Change Steam Folder...").OnEvent("Click", SetSteamDir)

    SettingsGui.AddText("x35 y+18 w420", "Live SteamVR settings file:")
    LiveEdit := SettingsGui.AddEdit("x35 y+4 w420 ReadOnly Background" DarkCtrlBG " c" InputFGStr, LivePath ? LivePath : "(set your Steam folder first)")

    BtnDownload := SettingsGui.AddButton("x35 y+18 w420", "Download / Update Null Driver from GitHub")
    BtnDownload.OnEvent("Click", DownloadDriver)

    SettingsGui.AddButton("x35 y+8 w420", "Edit Quick Commands File...").OnEvent("Click", OpenCommandsFile)

    SettingsGui.AddButton("x35 y+8 w420", "Copy Diagnostics").OnEvent("Click", CopyDiagnostics)

    chkUpdates := SettingsGui.AddCheckBox("x35 y+12 w420", "Check GitHub for updates when this starts")
    chkUpdates.Value := (IniRead(BootstrapFile, "Updates", "Enabled", "") = "1") ? 1 : 0
    chkUpdates.OnEvent("Click", ToggleUpdateCheck)

    SettingsTabs.UseTab(2)
    SettingsGui.AddText("x35 y55 w300", "Turn Sensitivity")
    SensLabel := SettingsGui.AddText("x355 yp w100 Right", Format("{:.2f}x", TurnSensitivity))
    SensSlider := SettingsGui.AddSlider("x35 y+4 w420 Range10-300 ToolTip", Round(TurnSensitivity * 100))
    SensSlider.OnEvent("Change", OnSensitivityChange)

    SettingsGui.AddText("x35 y+18 w300", "Base Turn Speed (degrees per second)")
    TurnSpeedEdit := SettingsGui.AddEdit("x355 yp-4 w100 Right Background" DarkCtrlBG " c" InputFGStr, Format("{:.0f}", TurnSpeed))
    TurnSpeedEdit.OnEvent("LoseFocus", OnTurnSpeedChanged)

    SettingsGui.AddText("x35 y+14 w300", "Console Command Delay (ms)")
    ConsoleMsEdit := SettingsGui.AddEdit("x355 yp-4 w100 Right Background" DarkCtrlBG " c" InputFGStr, String(ConsoleMS))
    ConsoleMsEdit.OnEvent("LoseFocus", OnConsoleMsChanged)

    chkAutoView := SettingsGui.AddCheckBox("x35 y+16 w420", "Auto console view (move the camera when the game console opens / closes)")
    chkAutoView.Value := AutoConsoleView ? 1 : 0
    chkAutoView.OnEvent("Click", OnAutoConsoleViewChanged)

    chkMouse := SettingsGui.AddCheckBox("x35 y+22 w420", "Mouse look (right-click in the game to turn it on / off)")
    chkMouse.Value := MouseLookEnabled ? 1 : 0
    chkMouse.OnEvent("Click", OnMouseLookChanged)
    SettingsGui.AddText("x35 y+10 w300", "Mouse Sensitivity")
    MouseSensLabel := SettingsGui.AddText("x355 yp w100 Right", Format("{:.2f}x", MouseSensitivity))
    MouseSensSlider := SettingsGui.AddSlider("x35 y+4 w420 Range10-300 ToolTip", Round(MouseSensitivity * 100))
    MouseSensSlider.OnEvent("Change", OnMouseSensChange)
    chkInvert := SettingsGui.AddCheckBox("x35 y+8 w420", "Invert mouse Y")
    chkInvert.Value := MouseInvertY ? 1 : 0
    chkInvert.OnEvent("Click", OnMouseInvertChanged)

    SettingsGui.AddText("x35 y+18 w420 cSilver", "Turning is done by the driver: your turn speed is the base speed times the sensitivity above, and changes apply live (no SteamVR restart). The console delay is how long the console paste sequence waits between steps - raise it if commands fail on a slower system. Mouse look needs the v2. driver: it holds the cursor in the middle of the game window while it's on, and lets go (within about half a second) whenever Movement Mode pauses.")

    SettingsTabs.UseTab(3)
    SettingsGui.AddText("x35 y55 w420 cSilver", "Click a key button, then press the key you want. Escape cancels. Left Shift (sprint) and Left Alt are fixed, and keys the devkit uses internally (F13-F24, Numpad 5 / 8) can't be bound.")

    KeybindButtons := Map()
    SettingsGui.AddText("x35 y110 w200 cSilver", "Menu navigation")
    SettingsGui.AddText("x250 y110 w200 cSilver", "Look and interact")
    y := 140
    for action in MenuActions {
        SettingsGui.AddText("x35 y" y " w95", MovementKeyLabels[action])
        btn := SettingsGui.AddButton("x130 y" (y - 4) " w95", StrUpper(GetKeyName(MovementKeyBinds[action])))
        btn.OnEvent("Click", RebindMovementKey.Bind(action))
        KeybindButtons[action] := btn
        y += 36
    }
    y := 140
    for action in ControlActions {
        SettingsGui.AddText("x250 y" y " w85", MovementKeyLabels[action])
        btn := SettingsGui.AddButton("x335 y" (y - 4) " w100", StrUpper(GetKeyName(MovementKeyBinds[action])))
        btn.OnEvent("Click", RebindMovementKey.Bind(action))
        KeybindButtons[action] := btn
        y += 36
    }
    SettingsGui.AddButton("x35 y" (140 + 5 * 36 + 6) " w400", "Reset All to Defaults").OnEvent("Click", (*) => ResetKeyBindsToDefaults(KeybindButtons))
    SettingsTabs.UseTab(4)
    SettingsGui.AddText("x35 y55 w420 cSilver", "These change the devkit's virtual headset. Restart SteamVR after applying. This isn't a benchmark, SteamVR on a desktop is a rough baseline only.")

    SettingsGui.AddText("x35 y+14 w420", "Render resolution (per eye)")
    presetNames := []
    for preset in RenderPresets
        presetNames.Push(preset.Name " - " preset.W "x" preset.H)
    presetNames.Push("Custom...")
    DispPresetDDL := SettingsGui.AddDropDownList("x35 y+4 w420", presetNames)
    DispPresetDDL.OnEvent("Change", OnPresetChange)

    SettingsGui.AddText("x35 y+10 w60", "Width")
    DispWEdit := SettingsGui.AddEdit("x95 yp-4 w90 Number Background" DarkCtrlBG " c" InputFGStr)
    SettingsGui.AddText("x215 yp+4 w60", "Height")
    DispHEdit := SettingsGui.AddEdit("x275 yp-4 w90 Number Background" DarkCtrlBG " c" InputFGStr)

    SettingsGui.AddText("x35 y+18 w420", "Display frequency (FPS limit)")
    fpsNames := []
    for fps in FpsOptions
        fpsNames.Push(fps " FPS")
    DispFpsDDL := SettingsGui.AddDropDownList("x35 y+4 w420", fpsNames)

    SettingsGui.AddButton("x35 y+18 w420", "Apply to Null Driver").OnEvent("Click", OnApplyDisplay)
    DispStatus := SettingsGui.AddText("x35 y+10 w420 cSilver", "")
    RefreshDisplayTab()

    SettingsTabs.UseTab()

    SettingsGui.AddButton("x15 y530 w460 h30", "Close").OnEvent("Click", CloseSettingsWindow)
    SettingsGui.OnEvent("Close", CloseSettingsWindow)
    SettingsGui.Show()
}

CloseSettingsWindow(*) {
    global SettingsGui
    try SettingsGui.Destroy()
    SettingsGui := ""
}

WipePathLooksRight(path, requiredEnding) {
    path := RTrim(path, "\")
    if StrLen(path) < 12 || SubStr(path, 2, 1) != ":"
        return false
    return StrLower(SubStr(path, -StrLen(requiredEnding))) = StrLower(requiredEnding)
}

SteamVRDir() {
    global SteamDir
    static cached := "", cachedFor := "", lastCheck := -100000
    if SteamDir = ""
        return ""
    if cachedFor = SteamDir && A_TickCount - lastCheck < 5000
        return cached
    cachedFor := SteamDir
    lastCheck := A_TickCount

    libraries := [SteamDir]
    try {
        vdf := FileRead(SteamDir "\steamapps\libraryfolders.vdf", "UTF-8")
        for pattern in ['"path"\s+"([^"]+)"', '"\d+"\s+"([A-Za-z]:[^"]*)"'] {
            pos := 1
            while pos := RegExMatch(vdf, pattern, &m, pos) {
                libraries.Push(StrReplace(m[1], "\\", "\"))
                pos += StrLen(m[0])
            }
        }
    }

    cached := SteamDir "\steamapps\common\SteamVR"
    for requireBin in [true, false] {
        for lib in libraries {
            candidate := RTrim(lib, "\") "\steamapps\common\SteamVR"
            if DirExist(requireBin ? candidate "\bin" : candidate) {
                cached := candidate
                return cached
            }
        }
    }
    return cached
}

SteamVRDriverDir() {
    svr := SteamVRDir()
    return svr != "" ? svr "\drivers\null" : ""
}

SteamOwnedProcesses(steamDir, onlySteamVR := false) {
    found := []
    svr := SteamVRDir()
    prefixes := []
    if !onlySteamVR {
        prefixes.Push(steamDir "\steam.exe")
        prefixes.Push(steamDir "\bin\")
    }
    if svr != ""
        prefixes.Push(svr "\")
    try {
        for proc in ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, ExecutablePath FROM Win32_Process") {
            path := proc.ExecutablePath
            if !path
                continue
            for prefix in prefixes {
                if StrLower(SubStr(path, 1, StrLen(prefix))) = StrLower(prefix) {
                    found.Push(proc.ProcessId)
                    break
                }
            }
        }
    }
    return found
}

ShutDownSteam(steamDir) {
    if SteamOwnedProcesses(steamDir).Length = 0
        return true

    steamExe := StrLower(steamDir "\steam.exe")
    Loop {
        for pid in SteamOwnedProcesses(steamDir, true)
            try ProcessClose(pid)

        steamRunning := false
        for pid in SteamOwnedProcesses(steamDir) {
            try {
                if StrLower(ProcessGetPath(pid)) = steamExe
                    steamRunning := true
            }
        }
        if steamRunning && FileExist(steamDir "\steam.exe")
            try Run('"' steamDir '\steam.exe" -shutdown', steamDir, "Hide")

        deadline := A_TickCount + 20000
        while A_TickCount < deadline {
            if SteamOwnedProcesses(steamDir).Length = 0
                return true
            Sleep(500)
        }

        answer := MsgBox("Steam is still open.`n`nIf it's busy with something (an update, syncing), wait for it to finish and it should close by itself. Otherwise, close it yourself from the system tray (right-click the Steam icon, then Exit).`n`nClick Retry once it has closed, or Cancel to stop and leave everything as it is.", "Steam Is Still Open", "RetryCancel Icon!")
        if answer != "Retry"
            return false
    }
}

WipeFolder(path) {
    if !DirExist(path)
        return "not found (nothing to delete)"
    Loop 10 {
        try DirDelete(path, true)
        if !DirExist(path)
            return "deleted"
        Sleep(500)
    }
    try RunWait('cmd.exe /c rmdir /s /q "' path '"', , "Hide")
    Sleep(300)
    return DirExist(path) ? "FAILED (something still has it open)" : "deleted"
}

CleanSlateRun(targets, wipeDriver, keepCommands := false) {
    global SteamDir, Root, CommandsFile, MovementModeRequested

    MovementModeRequested := false
    ReleaseSprintAlt()
    ReleaseGhostKeys()

    if wipeDriver && SteamDir != "" && !ShutDownSteam(SteamDir)
        return ""

    kept := ""
    if keepCommands && FileExist(CommandsFile) {
        kept := A_Temp "\skyrimvr_devkit_commands_keep.ini"
        try {
            FileCopy(CommandsFile, kept, true)
        } catch {
            kept := ""
        }
    }

    report := ""
    for t in targets
        report .= t.Label ": " WipeFolder(t.Path) "`n  " t.Path "`n"

    if kept != "" {
        try {
            DirCreate(Root)
            FileCopy(kept, CommandsFile, true)
            FileDelete(kept)
            report .= "Kept your Quick Commands (commands.ini).`n"
        } catch {
            report .= "Couldn't put your Quick Commands (commands.ini) back; a copy is at " kept "`n"
        }
    }
    return report
}

OfferCleanSlate() {
    global Root, OldRoot, SteamDir, BootstrapFile, ExpectedDriverVersion, CleanSlateLegacySeen

    if IniRead(BootstrapFile, "Migration", "CleanSlateV2", "") != ""
        return

    DriverDir := SteamVRDriverDir()
    installed := DriverDir != "" ? GetInstalledDriverVersion(DriverDir) : ""
    oldDriver := (DriverIsOlder(installed)
                  && WipePathLooksRight(DriverDir, "\steamapps\common\SteamVR\drivers\null"))

    if !CleanSlateLegacySeen && !oldDriver {
        IniWrite("new", BootstrapFile, "Migration", "CleanSlateV2")
        return
    }

    targets := []
    if WipePathLooksRight(Root, "\SkyrimVR Devkit")
        targets.Push({Label: "Devkit settings and data", Path: Root})
    if DirExist(OldRoot) && WipePathLooksRight(OldRoot, "\SkyrimVR Devkit")
        targets.Push({Label: "Old devkit folder (ProgramData)", Path: OldRoot})
    if oldDriver
        targets.Push({Label: "Outdated null driver (version " installed ")", Path: DriverDir})
    if targets.Length = 0
        return

    list := ""
    for t in targets
        list .= "  - " t.Path "`n"
    steps := "This one-time step will:`n`n"
    if oldDriver
        steps .= "  1. Close Steam and SteamVR (the old driver can't be removed while they run).`n  2. Delete these folders:`n"
    else
        steps .= "  - Delete these folders:`n"
    steps .= list

    answer := MsgBox("Welcome to SkyrimVR Devkit 2.0!`n`nThis version changed how the devkit and its null driver work together, and files left over from older versions can cause problems or fail to carry over. To start v2 cleanly:`n`n" steps
        . "`nYour Quick Commands (commands.ini) are kept. Everything else (settings, key bindings, console history) goes back to defaults, and the devkit restarts like a first launch."
        . (oldDriver ? " The Setup Checklist will then help you download the v2 driver." : "")
        . "`n`nClose SkyrimVR first if it's running." (oldDriver ? " Steam stays closed afterwards; start it again when you're ready." : "") "`n`nDo this now? (Choosing No skips it for good and leaves everything as it is.)",
        "SkyrimVR Devkit - One-Time Clean Slate", "YesNo Icon! Default2")

    if answer != "Yes" {
        IniWrite("declined", BootstrapFile, "Migration", "CleanSlateV2")
        return
    }

    if ProcessExist("SkyrimVR.exe") {
        MsgBox("SkyrimVR is running. Close the game first (closing Steam would take it down), then open the devkit again; this will be offered again.", "Close the Game First", "IconX")
        return
    }

    report := CleanSlateRun(targets, oldDriver, true)
    if report = "" {
        MsgBox("Nothing was deleted. This will be offered again the next time you open the devkit.", "Clean Slate Cancelled", "Iconi")
        return
    }

    if InStr(report, "FAILED") {
        MsgBox("Clean slate finished with a problem:`n`n" report "`nSomething still has the folder(s) marked FAILED open. Close SteamVR and Steam (and anything else using them), then open the devkit again to finish; the Setup Checklist will show if the driver still needs replacing. The devkit will close now.", "Clean Slate Incomplete", "IconX")
        ExitApp()
    }

    try {
        DirCreate(Root)
        IniWrite("done", BootstrapFile, "Migration", "CleanSlateV2")
    }
    MsgBox("Clean slate done:`n`n" report "`nThe devkit will restart now like a first launch." (oldDriver ? " Start Steam again yourself when you're ready." : ""), "Clean Slate Finished", "Iconi")
    Reload()
}

ClampNum(val, lo, hi) {
    val += 0
    if val < lo
        return lo
    if val > hi
        return hi
    return val
}

OnTurnSpeedChanged(ctrl, *) {
    global TurnSpeed
    val := ctrl.Text
    if IsNumber(val) && val > 0
        TurnSpeed := ClampNum(val, 10.0, 1000.0)
    else
        MsgBox("Turn speed must be a number greater than 0. Reverting to the last valid value.", "Invalid Value", "IconX")
    ctrl.Text := Format("{:.0f}", TurnSpeed)
    QueueSaveControlSettings()
}

OnConsoleMsChanged(ctrl, *) {
    global ConsoleMS
    val := ctrl.Text
    if IsNumber(val) && val >= 5
        ConsoleMS := ClampNum(val, 5, 500)
    else
        MsgBox("Console delay must be a number of at least 5 (ms). Reverting to the last valid value.", "Invalid Value", "IconX")
    ctrl.Text := String(ConsoleMS)
    QueueSaveControlSettings()
}

BuildRebindCandidateKeys() {
    keys := []
    Loop 26
        keys.Push(Chr(96 + A_Index)) ; a-z
    Loop 10
        keys.Push(String(A_Index - 1)) ; 0-9
    Loop 24
        keys.Push("F" A_Index) ; F1-F24
    Loop 10
        keys.Push("Numpad" (A_Index - 1)) ; Numpad0-9
    for extra in ["NumpadAdd", "NumpadSub", "NumpadMult", "NumpadDiv", "NumpadDot", "NumpadEnter"]
        keys.Push(extra)
    for extra in ["Tab", "CapsLock", "Enter", "Space", "Backspace", "Insert", "Delete",
                  "Home", "End", "PgUp", "PgDn", "Up", "Down", "Left", "Right",
                  "LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin",
                  "-", "=", "[", "]", "\", ";", "'", ",", ".", "/", "``"]
        keys.Push(extra)

    reserved := Map("lshift", 1, "lalt", 1, "numpad8", 1, "numpad5", 1)
    Loop 12
        reserved["f" (12 + A_Index)] := 1
    filtered := []
    for k in keys {
        if !reserved.Has(StrLower(k))
            filtered.Push(k)
    }
    return filtered
}

RebindMovementKey(action, ctrl, *) {
    global MovementKeyBinds, AllBindActions, MovementKeyLabels, SettingsGui

    original := ctrl.Text
    try {
        ctrl.Text := "Press a key... (Esc cancels)"
        ctrl.Enabled := false
        if IsObject(SettingsGui)
            SettingsGui.Opt("+Disabled")

        candidates := BuildRebindCandidateKeys()

        releaseDeadline := A_TickCount + 2000
        loop {
            stillDown := false
            for k in candidates {
                if GetKeyState(k, "P") {
                    stillDown := true
                    break
                }
            }
            if !stillDown || A_TickCount > releaseDeadline
                break
            Sleep(10)
        }

        pressedKey := ""
        escaped := false
        captureDeadline := A_TickCount + 10000
        while A_TickCount < captureDeadline {
            if GetKeyState("Escape", "P") {
                escaped := true
                break
            }
            for k in candidates {
                if GetKeyState(k, "P") {
                    pressedKey := k
                    break
                }
            }
            if pressedKey != ""
                break
            Sleep(10)
        }

        if IsObject(SettingsGui)
            SettingsGui.Opt("-Disabled")
        ctrl.Enabled := true

        if escaped || pressedKey = "" {
            ctrl.Text := original
            return
        }

        newSc := Format("sc{:03X}", GetKeySC(pressedKey))

        if newSc = "sc029" {
            MsgBox("That key is reserved for opening the console. Pick a different key.", "Key Reserved", "IconX")
            ctrl.Text := original
            return
        }

        for otherAction in AllBindActions {
            if otherAction != action && MovementKeyBinds[otherAction] = newSc {
                MsgBox(StrUpper(GetKeyName(newSc)) " is already bound to " MovementKeyLabels[otherAction] ". Pick a different key, or rebind that action first.", "Key Already Bound", "IconX")
                ctrl.Text := original
                return
            }
        }

        oldBinds := MovementKeyBinds.Clone()
        MovementKeyBinds[action] := newSc
        RegisterMovementHotkeys(oldBinds)
        SaveKeyBind(action, newSc)
        ctrl.Text := StrUpper(GetKeyName(newSc))
    } catch as e {
        try {
            if IsObject(SettingsGui)
                SettingsGui.Opt("-Disabled")
            ctrl.Enabled := true
            ctrl.Text := original
        }
        LogError("RebindMovementKey failed for '" action "': " e.Message)
    }
}

ResetKeyBindsToDefaults(KeybindButtons) {
    global MovementKeyBinds, AllBindActions, MovementKeyDefaults
    oldBinds := MovementKeyBinds.Clone()
    for action in AllBindActions {
        MovementKeyBinds[action] := MovementKeyDefaults[action]
        SaveKeyBind(action, MovementKeyDefaults[action])
    }
    RegisterMovementHotkeys(oldBinds)
    for action in AllBindActions
        KeybindButtons[action].Text := StrUpper(GetKeyName(MovementKeyDefaults[action]))
}

TestPulse(key) {
    GhostSend(key, true)
    Sleep(300)
    GhostSend(key, false)
}

GhostSend(ghost, down) {
    SetKeyDelay(-1, -1)
    SendEvent("{" ghost (down ? " down}" : " up}"))
}

SyncGhostKeys() {
    global MovementMode, MovementKeyBinds, GhostKeys, GhostHeld
    global GhostHeartbeat, HeartbeatEveryMs, HeartbeatState, HeartbeatLastMs, HeartbeatSent

    static interactDownTick := 0
    for action, ghost in GhostKeys {
        want := MovementMode && GetKeyState(MovementKeyBinds[action], "P")
        if action = "Interact" {
            if want && !GhostHeld[action]
                interactDownTick := A_TickCount
            else if !want && GhostHeld[action] && MovementMode && A_TickCount - interactDownTick < 60
                want := true
        }
        if want != GhostHeld[action] || want != GetKeyState(ghost) {
            GhostSend(ghost, want)
            GhostHeld[action] := want
        }
    }

    if MovementMode {
        if A_TickCount - HeartbeatLastMs >= HeartbeatEveryMs {
            HeartbeatState := !HeartbeatState
            GhostSend(GhostHeartbeat, HeartbeatState)
            HeartbeatSent += 1
            HeartbeatLastMs := A_TickCount
        }
    } else if HeartbeatState || GetKeyState(GhostHeartbeat) {
        GhostSend(GhostHeartbeat, false)
        HeartbeatState := false
    }
}

FreeStuckMouseClip() {
    rc := Buffer(16, 0)
    if DllCall("GetClipCursor", "Ptr", rc) && NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int") <= 1
        && NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int") <= 1
        DllCall("ClipCursor", "Ptr", 0)
}

ReleaseGhostKeys(*) {
    global GhostKeys, GhostHeld, GhostHeartbeat, HeartbeatState
    FreeStuckMouseClip()
    for action, ghost in GhostKeys {
        if GhostHeld[action] || GetKeyState(ghost) {
            GhostSend(ghost, false)
            GhostHeld[action] := false
        }
    }
    if HeartbeatState || GetKeyState(GhostHeartbeat) {
        GhostSend(GhostHeartbeat, false)
        HeartbeatState := false
    }
}

ReleaseGhostKeysOnExit(*) {
    ReleaseGhostKeys()
    return 0
}
OnExit(ReleaseGhostKeysOnExit)

MoveToConsoleView(*) {
    global GhostReposition
    TestPulse(GhostReposition)
}
ResetCameraView(*) {
    global GhostReset
    TestPulse(GhostReset)
}

BtnConsole := MainGui.AddButton("x15 y+8 w420 h32", "Send Console Command...")
BtnConsole.OnEvent("Click", ShowConsoleDialog)
UpdateNoteURL := ""
UpdateNote := MainGui.AddText("x15 y+10 w420 h1 Hidden cFFD166", "")
UpdateNote.OnEvent("Click", OnUpdateNoteClick)

CopyDiagnostics(*) {
    global SteamDir, LivePath, Active, ActionDir, ControlsFile, MovementMode, MovementModeRequested
    global ScriptVersion, ExpectedDriverVersion, Root, ErrorLogFile, BootstrapFile, AutoConsoleView, HeartbeatSent
    global MouseLookEnabled, MouseSensitivity, MouseInvertY

    DriverDir  := SteamVRDriverDir()
    installedDriverVersion := DriverDir != "" ? GetInstalledDriverVersion(DriverDir) : "(Steam folder not set)"
    focusWin := "(none)"
    layoutLangId := 0
    try {
        focusWin := WinGetProcessName("A")
        hwnd := WinExist("A")
        threadId := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
        layoutId := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
        layoutLangId := layoutId & 0xFFFF
    }

    text := "=== SkyrimVR Devkit Diagnostics ===`n"
    text .= "Script version: " ScriptVersion "`n"
    text .= "Expected driver version: " ExpectedDriverVersion "`n"
    text .= "Installed driver version: " (installedDriverVersion = "" ? "(none / SteamVR stock driver)" : installedDriverVersion) "`n"
    text .= "Running as admin: " (A_IsAdmin ? "Yes" : "No") "`n"
    text .= "Keyboard layout langID: 0x" Format("{:04X}", layoutLangId) "`n"
    text .= "OS: " A_OSVersion "`n`n"

    text .= "Steam folder: " (SteamDir != "" ? SteamDir : "(not set)") "`n"
    text .= "SteamVR settings file: " (LivePath != "" ? LivePath : "(not set)") "`n"
    svrDir := SteamVRDir()
    text .= "SteamVR folder: " (svrDir = "" ? "(not set)" : svrDir (DirExist(svrDir) ? "" : "  (NOT FOUND in any Steam library)")) "`n"
    text .= "Driver folder: " (DriverDir != "" ? DriverDir : "(not set)") "`n"
    text .= "Driver folder exists: " (DriverDir != "" && DirExist(DriverDir) ? "Yes" : "No") "`n"
    dllPath := DriverDir != "" ? DriverDir "\bin\win64\driver_null.dll" : ""
    if dllPath = "" || !FileExist(dllPath)
        text .= "Driver DLL: (missing)`n"
    else
        text .= "Driver DLL: " (DriverDllIsDevkit(dllPath) ? "the devkit's" : "NOT the devkit's (SteamVR's own?)") ", " FileGetSize(dllPath) " bytes, SHA-256 check: " DriverDllHashState(dllPath) "`n"
    text .= "Tracked 'Active' state (config.ini): " Active "`n`n"

    text .= "Actions folder: " ActionDir "`n"
    writable := "unknown"
    try {
        f := FileOpen(ControlsFile, "a")
        if IsObject(f) {
            f.Close()
            writable := "writable"
        } else {
            writable := "NOT writable"
        }
    } catch as e {
        writable := "NOT writable (" e.Message ")"
    }
    text .= "  controls.txt: " ControlsFile " - " writable "`n"
    try text .= "  contents: " Trim(FileRead(ControlsFile), " `t`r`n") "`n"

    viewFile := ActionDir "\console_view.txt"
    try text .= "  console_view.txt: " StrReplace(Trim(FileRead(viewFile), " `t`r`n"), "`n", " | ") "`n"
    catch
        text .= "  console_view.txt: (not created yet, driver defaults in use)`n"

    st := ReadDriverStatus(&statusAge, &statusRaw)
    if !IsObject(st) {
        text .= "Driver status: (no driver_status.txt: SteamVR hasn't run this driver yet, or the installed driver is an older build that doesn't report it)`n"
    } else {
        text .= "Driver status (" (statusAge > 5 ? "STALE, " statusAge " s old: SteamVR is closed or the driver stopped" : "live, " statusAge " s old") "):`n"
        for line in StrSplit(Trim(statusRaw, " `t`r`n"), "`n", "`r")
            text .= "  " line "`n"
    }
    text .= "Frontend heartbeat flips sent: " HeartbeatSent "`n"
    text .= "Setup completed flag: " IniRead(BootstrapFile, "Setup", "Completed", "0") "`n"
    text .= "Auto console view: " (AutoConsoleView ? "on" : "off") "`n"
    text .= "Mouse look: " (MouseLookEnabled ? "enabled" : "disabled") ", sensitivity " Format("{:.2f}", MouseSensitivity) "x" (MouseInvertY ? ", Y inverted" : "") "`n"

    text .= "`nMovement Mode requested: " (MovementModeRequested ? "Yes" : "No") "`n"
    text .= "Movement Mode live/active: " (MovementMode ? "Yes" : "No") "`n"
    text .= "Focused window process: " focusWin "`n"

    text .= "`nKeybinds:"
    for action in AllBindActions
        text .= " " action "=" StrUpper(GetKeyName(MovementKeyBinds[action])) "(" MovementKeyBinds[action] ")"
    text .= "`n"
    if ReadDisplaySettings(&dw, &dh, &dfps)
        text .= "Driver display settings: " dw "x" dh " at " dfps " FPS`n"
    else
        text .= "Driver display settings: (not readable)`n"

    text .= "`nRecent error log (" ErrorLogFile "):`n"
    try {
        logText := FileRead(ErrorLogFile, "UTF-8")
        lines := StrSplit(logText, "`n")
        startIdx := Max(1, lines.Length - 19)
        loop lines.Length - startIdx + 1 {
            line := lines[startIdx + A_Index - 1]
            if Trim(line) != ""
                text .= "  " line "`n"
        }
    } catch {
        text .= "  (no log file yet)`n"
    }

    A_Clipboard := ScrubUserName(text)
    MsgBox("Diagnostics copied to your clipboard. Paste them wherever you're reporting the issue.`n`n(Your Windows user name was replaced with USER in every file path.)", "Copied", "Iconi")
}

ScrubUserName(text) {
    profile := EnvGet("USERPROFILE")
    if profile != "" && InStr(profile, "\") {
        parent := RegExReplace(profile, "\\[^\\]+$", "")
        text := StrReplace(text, profile, parent "\USER")
    }
    return RegExReplace(text, "im)([A-Za-z]:\\Users\\)[^\\\r\n]+(?=\\|\r?$)", "${1}USER")
}

ConsoleCommandHistory := []
ConsoleHistoryFile := Root "\console_history.ini"

LoadConsoleHistory() {
    global ConsoleCommandHistory, ConsoleHistoryFile
    ConsoleCommandHistory := []
    if !FileExist(ConsoleHistoryFile)
        return
    Loop Read, ConsoleHistoryFile
    {
        line := Trim(A_LoopReadLine)
        if line != ""
            ConsoleCommandHistory.Push(line)
    }
}

SaveConsoleHistory() {
    global ConsoleCommandHistory, ConsoleHistoryFile
    text := ""
    for cmd in ConsoleCommandHistory
        text .= cmd "`n"
    try {
        if FileExist(ConsoleHistoryFile)
            FileDelete(ConsoleHistoryFile)
        FileAppend(text, ConsoleHistoryFile, "UTF-8")
    }
}

AddToConsoleHistory(cmd) {
    global ConsoleCommandHistory
    for index, existing in ConsoleCommandHistory {
        if existing = cmd {
            ConsoleCommandHistory.RemoveAt(index)
            break
        }
    }
    ConsoleCommandHistory.InsertAt(1, cmd)
    if ConsoleCommandHistory.Length > 20
        ConsoleCommandHistory.RemoveAt(ConsoleCommandHistory.Length)
    SaveConsoleHistory()
}

ShowConsoleDialog(*) {
    global ConsoleCommandHistory, ConsoleDialogOpen, ConsoleDialogHwnd
    if ConsoleDialogOpen && ConsoleDialogHwnd && WinExist("ahk_id " ConsoleDialogHwnd) {
        WinActivate("ahk_id " ConsoleDialogHwnd)
        return
    }
    LoadConsoleHistory()
    ConsoleDialogOpen := true

    ConsoleGui := Gui("+AlwaysOnTop", "Send Console Command")
    ConsoleGui.BackColor := DarkBGStr
    ConsoleGui.SetFont("s10 c" DarkFGStr)
    ConsoleGui.MarginX := 15
    ConsoleGui.MarginY := 15
    ApplyDarkTitlebar(ConsoleGui)

    ConsoleGui.AddText("w400", "Enter Console Command:")
    CmdEdit := ConsoleGui.AddEdit("w400 vCmdText Background" DarkCtrlBG " c" InputFGStr)

    ConsoleGui.AddText("x15 y+10 w400", "Recent commands:")
    HistoryDDL := ConsoleGui.AddDropDownList("x15 y+4 w400", ConsoleCommandHistory)
    HistoryDDL.OnEvent("Change", (*) => CmdEdit.Text := (HistoryDDL.Value > 0 ? ConsoleCommandHistory[HistoryDDL.Value] : ""))

    BtnSend := ConsoleGui.AddButton("x15 y+12 w190 h30 Default", "Send")
    BtnCancel := ConsoleGui.AddButton("x+20 yp w190 h30", "Cancel")

    ConsoleDialogHwnd := ConsoleGui.Hwnd

    CloseConsoleDialog(*) {
        global ConsoleDialogOpen, ConsoleDialogHwnd
        ConsoleDialogOpen := false
        ConsoleDialogHwnd := 0
        ConsoleGui.Destroy()
    }

    SendCommand(*) {
        cmd := Trim(CmdEdit.Text)
        CloseConsoleDialog()
        if cmd = ""
            return
        AddToConsoleHistory(cmd)
        SendConsoleCommand(cmd)
    }

    BtnSend.OnEvent("Click", SendCommand)
    ConsoleGui.OnEvent("Close", CloseConsoleDialog)
    BtnCancel.OnEvent("Click", CloseConsoleDialog)
    ConsoleGui.OnEvent("Escape", CloseConsoleDialog)
    ConsoleGui.Show("w430")
    CmdEdit.Focus()
}

MainGui.OnEvent("Close", (*) => ExitApp())
MainGui.Show("w450")

UpdateStatus()

if IniRead(BootstrapFile, "Setup", "Completed", "0") != "1" {
    if SetupOneTimeStepsDone(SetupStepStates())
        MarkSetupComplete()
    else
        ShowSetupChecklist()
}

SetTimer(CheckForUpdates, -1500)

WriteDriverControls()

SprintAlt(down) {
    SetKeyDelay(-1, -1)
    SendEvent("{LAlt " (down ? "down}" : "up}"))
}

ReleaseSprintAlt() {
    if GetKeyState("LAlt") && !GetKeyState("LAlt", "P")
        SprintAlt(false)
}

UpdateLiveMovementMode() {
    global MovementModeRequested, MovementMode, ConsoleDialogOpen, MovementLiveText, GameConsoleOpen
    validFocus := WinActive("ahk_exe SkyrimVR.exe") || WinActive("ahk_exe vrcompositor.exe")
    if GameConsoleOpen && !ProcessExist("SkyrimVR.exe")
        GameConsoleOpen := false ; the game closed, so its console certainly did
    wasActive := MovementMode
    MovementMode := MovementModeRequested && !ConsoleDialogOpen && !GameConsoleOpen && validFocus
    if wasActive && !MovementMode {
        ReleaseSprintAlt()
        ReleaseGhostKeys()
    }
		
    if !IsSet(MovementLiveText) || !IsObject(MovementLiveText)
        return

    if !MovementModeRequested
        MovementLiveText.Text := "Live: off"
    else if ConsoleDialogOpen
        MovementLiveText.Text := "Live: paused (console dialog open)"
    else if GameConsoleOpen
        MovementLiveText.Text := "Live: paused (game console open; already closed? toggle Movement Mode)"
    else if !validFocus
        MovementLiveText.Text := "Live: waiting (SkyrimVR window isn't focused)"
    else if DriverProblem() != ""
        MovementLiveText.Text := "Live: ACTIVE, but the devkit driver is missing, outdated or damaged (see Setup Checklist)"
    else if DriverKeysProblem() != ""
        MovementLiveText.Text := "Live: ACTIVE, but the driver isn't getting the devkit's keys (use Copy Diagnostics)"
    else
        MovementLiveText.Text := "Live: ACTIVE"
}
SetTimer(UpdateLiveMovementMode, 50)

MainTick() {
    global MovementMode
    SyncGhostKeys()

    if MovementMode && !GetKeyState("LShift", "P")
        ReleaseSprintAlt()
}
SetTimer(MainTick, LookTickMs)

LoadKeyBinds() {
    global MovementKeyBinds, AllBindActions, MovementKeyDefaults, ConfigFile, BootstrapFile

    forbidden := Map("SC029", 1, "SC02A", 1, "SC038", 1, "SC064", 1, "SC065", 1, "SC066", 1,
                     "SC067", 1, "SC068", 1, "SC069", 1, "SC06A", 1, "SC06B", 1, "SC06C", 1,
                     "SC06D", 1, "SC06E", 1, "SC076", 1, "SC048", 1, "SC04C", 1)

    for action in AllBindActions {
        sc := MovementKeyDefaults[action]
        saved := IniRead(BootstrapFile, "KeyBinds", action, "")
        if saved = "" && ConfigFile != ""
            saved := IniRead(ConfigFile, "KeyBinds", action, "")
        if saved != "" {
            if RegExMatch(saved, "i)^sc[0-9a-f]{3}$") && !forbidden.Has(StrUpper(saved)) && GetKeyName(saved) != ""
                sc := saved
            else
                LogError("LoadKeyBinds: ignoring invalid saved key '" saved "' for " action ", using the default.")
        }
        MovementKeyBinds[action] := sc
    }

    seen := Map()
    for action in AllBindActions {
        key := StrUpper(MovementKeyBinds[action])
        if seen.Has(key) {
            LogError("LoadKeyBinds: two actions share key '" key "', resetting all keybinds to defaults.")
            for other in AllBindActions
                MovementKeyBinds[other] := MovementKeyDefaults[other]
            break
        }
        seen[key] := true
    }
}

SaveKeyBind(action, scancode) {
    global BootstrapFile
    try IniWrite(scancode, BootstrapFile, "KeyBinds", action)
}

SwallowMovementKey(*) {
    return
}

RemapMoveUp(*) {
    SetKeyDelay(-1, -1)
    SendEvent("{Numpad8}")
}
RemapMoveDown(*) {
    SetKeyDelay(-1, -1)
    SendEvent("{Numpad5}")
}

MovementOnlyContext(*) {
    global MovementMode
    return MovementMode
}

RegisterMovementHotkeys(oldBinds := "") {
    global MenuActions, ControlActions, MovementKeyBinds

    if IsObject(oldBinds) {
        HotIf(MovementOnlyContext)
        for action in MenuActions
            try Hotkey("*" oldBinds[action], , "Off")
        for action in ControlActions
            try Hotkey("*" oldBinds[action], , "Off")
        try Hotkey("*sc012", , "Off")
        HotIf()
    }

    HotIf(MovementOnlyContext)
    Hotkey("*" MovementKeyBinds["MoveUp"],   RemapMoveUp,   "On")
    Hotkey("*" MovementKeyBinds["MoveDown"], RemapMoveDown, "On")

    for action in ControlActions
        Hotkey("*" MovementKeyBinds[action], SwallowMovementKey, "On")

    if MovementKeyBinds["MoveUp"] != "sc012" && MovementKeyBinds["MoveDown"] != "sc012"
        Hotkey("*sc012", SwallowMovementKey, "On")

    HotIf()
}

LoadKeyBinds()
RegisterMovementHotkeys()

;  KEY INTERCEPTION
#HotIf MovementMode
#InputLevel 1
$LShift::SprintAlt(true)
$LShift Up::SprintAlt(false)
$LAlt::return
$LAlt Up::return
#InputLevel 0
#HotIf

GameConsoleKeyContext() {
    global ConsoleCommandBusy
    if IsSet(ConsoleCommandBusy) && ConsoleCommandBusy
        return false
    return WinActive("ahk_exe SkyrimVR.exe") || WinActive("ahk_exe vrcompositor.exe")
}

ToggleGameConsole(*) {
    global GameConsoleOpen, AutoConsoleView
    GameConsoleOpen := !GameConsoleOpen
    if AutoConsoleView
        SetTimer(GameConsoleOpen ? MoveToConsoleView : ResetCameraView, -1)
    KeyWait("sc029", "T2") ; one toggle per physical press, even if the key auto-repeats
}

#HotIf GameConsoleKeyContext()
~sc029::ToggleGameConsole()
#HotIf

LogError(msg) {
    global ErrorLogFile
    try {
        if FileExist(ErrorLogFile) && FileGetSize(ErrorLogFile) > 262144
            FileDelete(ErrorLogFile)
        line := FormatTime(, "yyyy-MM-dd HH:mm:ss") " - " msg "`n"
        FileAppend(line, ErrorLogFile, "UTF-8")
    }
}

ReadDriverStatus(&age, &raw := "") {
    global ActionDir
    age := -1
    raw := ""
    file := ActionDir "\driver_status.txt"
    if ActionDir = "" || !FileExist(file)
        return ""
    try {
        age := DateDiff(A_Now, FileGetTime(file, "M"), "Seconds")
        raw := FileRead(file, "UTF-8")
    } catch {
        return ""
    }
    st := Map()
    for line in StrSplit(raw, "`n", "`r") {
        parts := StrSplit(line, " ", , 2)
        if parts.Length = 2
            st[parts[1]] := Trim(parts[2])
    }
    return st
}

DriverKeysProblem() {
    static lastRead := 0, badSince := 0, cached := ""
    if A_TickCount - lastRead < 1000
        return cached
    if A_TickCount - lastRead > 3000
        badSince := 0 ; not asked for a while (Movement Mode wasn't live): start the timing afresh
    lastRead := A_TickCount
    st := ReadDriverStatus(&age)
    bad := IsObject(st) && age >= 0 && age <= 3 && st.Has("heartbeat_alive") && st["heartbeat_alive"] = "0"
    if !bad {
        badSince := 0
        cached := ""
        return ""
    }
    if badSince = 0
        badSince := A_TickCount
    cached := (A_TickCount - badSince >= 2500) ? "keys" : ""
    return cached
}

DriverProblem(forceFresh := false) {
    global SteamDir, ExpectedDriverVersion
    static cached := "", lastCheck := -100000
    if !forceFresh && A_TickCount - lastCheck < 5000
        return cached
    lastCheck := A_TickCount
    cached := ""
    if SteamDir != "" {
        installed := GetInstalledDriverVersion(SteamVRDriverDir())
        if installed = ""
            cached := "missing"
        else if DriverIsOlder(installed)
            cached := "outdated (installed " installed ", needs " ExpectedDriverVersion ")"
        else if (dllProblem := DriverDllProblem(SteamVRDriverDir())) != ""
            cached := "damaged (" dllProblem ")"
    }
    return cached
}

WarnIfDriverProblem() {
    static warned := false
    problem := DriverProblem(true)
    if problem = "" || warned
        return
    warned := true
    if problem = "missing"
        what := "The devkit's null driver doesn't look installed (no version marker was found), so SteamVR is probably running its own built-in null driver instead."
    else
        what := "The devkit's null driver is " problem "."
    answer := MsgBox(what "`n`nWith the wrong driver, the look keys, interact and 'Close Dashboard' will not work, even though Movement Mode says it's on.`n`nOpen the Setup Checklist to fix it?", "Devkit Driver Needed", "YesNo Icon!")
    if answer = "Yes"
        ShowSetupChecklist()
}

ToggleMovementMode(*) {
    global MovementModeRequested, BtnMovement, GameConsoleOpen
    MovementModeRequested := !MovementModeRequested
    GameConsoleOpen := false
    if MovementModeRequested {
        BtnMovement.Text := "Movement Mode: ON  (Specific keys intercepted.)"
        SetTimer(WarnIfDriverProblem, -1)
    } else {
        BtnMovement.Text := "Movement Mode: OFF  (Keys work normally.)"
        ReleaseGhostKeys()
    }
}


CompareVersions(a, b) {
    pa := StrSplit(a, ".")
    pb := StrSplit(b, ".")
    Loop Max(pa.Length, pb.Length) {
        x := (A_Index <= pa.Length && IsInteger(pa[A_Index])) ? Integer(pa[A_Index]) : 0
        y := (A_Index <= pb.Length && IsInteger(pb[A_Index])) ? Integer(pb[A_Index]) : 0
        if x != y
            return x < y ? -1 : 1
    }
    return 0
}

DriverIsOlder(installed) {
    global ExpectedDriverVersion
    return installed != "" && CompareVersions(installed, ExpectedDriverVersion) < 0
}

DriverDllIsDevkit(dllPath) {
    static cacheKey := "", cacheVal := false
    if !FileExist(dllPath)
        return false
    key := dllPath "|" FileGetSize(dllPath) "|" FileGetTime(dllPath, "M")
    if key = cacheKey
        return cacheVal
    sig := "SkyrimVR Devkit/Actions"
    n := StrLen(sig)
    needle := Buffer(n)
    Loop n
        NumPut("UChar", Ord(SubStr(sig, A_Index, 1)), needle, A_Index - 1)
    found := false
    try {
        buf := FileRead(dllPath, "RAW")
        p := buf.Ptr
        last := buf.Ptr + buf.Size - n
        while p <= last {
            q := DllCall("msvcrt\memchr", "Ptr", p, "Int", Ord("S"), "UPtr", last - p + 1, "Ptr")
            if !q
                break
            if DllCall("ntdll\RtlCompareMemory", "Ptr", q, "Ptr", needle, "UPtr", n, "UPtr") = n {
                found := true
                break
            }
            p := q + 1
        }
    } catch {
        return true ; couldn't read it (locked?): can't tell, so don't raise a false alarm
    }
    cacheKey := key
    cacheVal := found
    return found
}

DriverDllProblem(driverDir) {
    dll := driverDir "\bin\win64\driver_null.dll"
    if !FileExist(dll)
        return "driver_null.dll is missing"
    if !DriverDllIsDevkit(dll)
        return "driver_null.dll is SteamVR's own, not the devkit's"
    if DriverDllHashState(dll) = "MISMATCH"
        return "driver_null.dll isn't the file this driver version shipped with (SHA-256 doesn't match)"
    return ""
}

FileSha256(path) {
    static cacheKey := "", cacheVal := ""
    if !FileExist(path)
        return ""
    key := path "|" FileGetSize(path) "|" FileGetTime(path, "M")
    if key = cacheKey
        return cacheVal
    tmp := A_Temp "\skyrimvr_devkit_hash.txt"
    result := ""
    try {
        try FileDelete(tmp)
        RunWait('cmd.exe /c certutil -hashfile "' path '" SHA256 > "' tmp '" 2>&1', , "Hide")
        if RegExMatch(FileRead(tmp), "im)^\s*((?:[0-9a-f]{2}\s?){32})\s*$", &m)
            result := StrLower(RegExReplace(m[1], "\s"))
        try FileDelete(tmp)
    }
    if StrLen(result) != 64
        result := ""
    cacheKey := key
    cacheVal := result
    return result
}

DriverDllHashState(dll) {
    shaFile := dll ".sha256"
    if !FileExist(shaFile)
        return "none"
    expected := ""
    try {
        if RegExMatch(FileRead(shaFile), "i)\b([0-9a-f]{64})\b", &m)
            expected := StrLower(m[1])
    }
    if expected = ""
        return "none"
    actual := FileSha256(dll)
    if actual = ""
        return "unknown"
    return actual = expected ? "ok" : "MISMATCH"
}

GetInstalledDriverVersion(DriverDir) {
    verFile := DriverDir "\devkit_version.txt"
    if !FileExist(verFile)
        return ""
    try
        return Trim(FileRead(verFile, "UTF-8"), " `t`r`n")
    return ""
}

SetDownloadButton(enabled, text := "Download / Update Null Driver from GitHub") {
    global BtnDownload
    try {
        BtnDownload.Enabled := enabled
        BtnDownload.Text := text
    }
}

DownloadDriver(*) {
    global SteamDir, RepoURL, ExpectedDriverVersion, DownloadBusy

    if DownloadBusy
        return
    if SteamDir = "" {
        MsgBox("Please set your Steam folder first.", "Steam folder not set", "IconX")
        return
    }

    SteamVRPath := SteamVRDir()
    if !DirExist(SteamVRPath) {
        MsgBox("Couldn't find SteamVR in any of your Steam libraries (looked in the main Steam folder and every library listed in Steam's libraryfolders.vdf).`n`nInstall SteamVR from Steam first (it's a free tool), or, if it's installed, make sure the Steam folder in Settings is the right one.", "SteamVR Not Found", "IconX")
        return
    }
    DriversDir := SteamVRPath "\drivers"
    DriverDir  := DriversDir "\null"
    TempZip    := A_Temp "\skyrimvr_devkit_null.zip"
    TempExtract := A_Temp "\skyrimvr_devkit_extract"

    installedVersion := GetInstalledDriverVersion(DriverDir)

    dllProblem := installedVersion != "" ? DriverDllProblem(DriverDir) : ""
    if dllProblem != "" {
        MsgBox("The devkit's version marker says the driver is installed, but " dllProblem ". That usually means Steam updated or verified SteamVR and put its own file back (or an earlier install couldn't replace a locked file).`n`nIt will now be reinstalled.", "Repairing Driver", "Iconi")
    } else if (installedVersion != "" && !DriverIsOlder(installedVersion)) {
        result := MsgBox("The devkit's null driver (version " installedVersion ") is already installed at:`n" DriverDir "`n`nThis devkit needs version " ExpectedDriverVersion " or newer, so it's up to date.`n`nReinstall it anyway?", "Already up to date", "YesNo Iconi")
        if result = "No"
            return
    } else if (installedVersion != "") {
        MsgBox("Updating the devkit's null driver from version " installedVersion " to " ExpectedDriverVersion ".", "Updating Driver", "Iconi")
    } else if DirExist(DriverDir) {
        MsgBox("SteamVR already has a built-in 'null' driver folder at:`n" DriverDir "`n`nThis is very likely SteamVR's own placeholder driver, not the one this tool needs - it will NOT support movement or console commands if left in place.`n`nIt will now be replaced with the devkit's null driver.", "Replacing SteamVR's Stock Driver", "Iconi")
    }

    DownloadBusy := true
    try {
        InstallDriverFromZip(RepoURL, TempZip, TempExtract, DriversDir, DriverDir)
    } finally {
        DownloadBusy := false
        SetDownloadButton(true)
    }
}

DriverFilesProblem(srcDir, destDir) {
    total := 0, badCount := 0, bad := ""
    Loop Files, srcDir "\*", "FR" {
        total += 1
        rel := SubStr(A_LoopFileFullPath, StrLen(srcDir) + 2)
        dest := destDir "\" rel
        if !FileExist(dest) || FileGetSize(dest) != A_LoopFileSize {
            badCount += 1
            if badCount <= 3
                bad .= (bad = "" ? "" : ", ") rel
        }
    }
    if total = 0
        return "the downloaded driver folder was empty."
    if badCount = 0
        return ""
    return badCount " of " total " files are missing or incomplete (" bad (badCount > 3 ? ", ..." : "") ")."
}

SteamOpenSummary() {
    global SteamDir
    names := Map()
    for pid in SteamOwnedProcesses(SteamDir)
        try names[StrLower(ProcessGetName(pid))] := true
    out := ""
    for name in names
        out .= (out = "" ? "" : ", ") name
    return out
}

WaitForSteamClosed() {
    global SteamDir, DarkBGStr, DarkFGStr
    if SteamOwnedProcesses(SteamDir).Length = 0
        return true

    state := {result: ""}

    dlg := Gui("+AlwaysOnTop", "Please Close Steam")
    dlg.BackColor := DarkBGStr
    dlg.SetFont("s10 c" DarkFGStr)
    dlg.MarginX := 20
    dlg.MarginY := 18
    ApplyDarkTitlebar(dlg)

    dlg.SetFont("s14 bold")
    dlg.AddText("w460", "Please close Steam")
    dlg.SetFont("s10 norm")
    dlg.AddText("w460 y+8", "Steam and SteamVR keep the driver file locked, so it can't be replaced while they're open. The install can't continue until both are fully closed.")
    dlg.AddText("w460 y+10", "Close Steam yourself: right-click the Steam icon in the system tray, then Exit. Close SteamVR too if it's open.")
    statusText := dlg.AddText("w460 y+14", "")
    dlg.AddText("w460 y+6", "This continues by itself as soon as everything has closed.")

    btnCancel := dlg.AddButton("x20 y+16 w460 h32", "Cancel install")
    btnCancel.OnEvent("Click", (*) => state.result := "cancel")
    dlg.OnEvent("Close", (*) => state.result := "cancel")
    dlg.Show("AutoSize")

    quiet := 0
    while state.result = "" {
        open := SteamOpenSummary()
        if open = "" {
            quiet += 1
            statusText.Text := "Everything is closed. Continuing..."
            if quiet >= 3
                state.result := "done"
        } else {
            quiet := 0
            statusText.Text := "Still open: " open
        }
        if state.result = ""
            Sleep(400)
    }
    dlg.Destroy()

    if state.result != "done"
        return false
    Sleep(1500)
    return true
}

InstallDriverFromZip(url, TempZip, TempExtract, DriversDir, DriverDir) {
    global ExpectedDriverVersion, BootstrapFile

    SetDownloadButton(false, "Downloading zip...")

    ; Download the zip
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(10000, 10000, 30000, 60000)
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "SkyrimVR-Devkit-AHK")
        http.Send()
        if http.Status != 200
            throw Error("HTTP " http.Status)

        stream := ComObject("ADODB.Stream")
        stream.Type := 1
        stream.Open()
        stream.Write(http.ResponseBody)
        stream.SaveToFile(TempZip, 2)
        stream.Close()
    } catch as e {
        MsgBox("Download failed:`n" e.Message "`n`nCheck your internet connection.", "Download Failed", "IconX")
        return
    }

    SetDownloadButton(false, "Extracting...")

    zipBytes := 0
    try zipBytes := FileGetSize(TempZip)
    srcNull := TempExtract "\null"

    try {
        if DirExist(TempExtract)
            DirDelete(TempExtract, true)
        DirCreate(TempExtract)
        psZip := StrReplace(TempZip, "'", "''")
        psExtract := StrReplace(TempExtract, "'", "''")
        exitCode := RunWait('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath `'' psZip '`' -DestinationPath `'' psExtract '`' -Force"', , "Hide")
        if exitCode != 0
            throw Error("Expand-Archive exited with code " exitCode ".")
        if !DirExist(srcNull) {
            Loop Files, TempExtract "\*", "D" {
                if DirExist(A_LoopFileFullPath "\null") {
                    srcNull := A_LoopFileFullPath "\null"
                    break
                }
            }
        }
        if !DirExist(srcNull) {
            top := ""
            Loop Files, TempExtract "\*", "FD"
                top .= (top = "" ? "" : ", ") A_LoopFileName
            throw Error("null folder not found in the zip.`n`nDownloaded " zipBytes " bytes from:`n" url "`n`nTop level of the zip: " (top = "" ? "(empty)" : top) "`n`n(GitHub can serve a previous version of a file for up to 5 minutes after an upload. If you just uploaded it, wait a few minutes and try again.)")
        }
    } catch as e {
        LogError("DownloadDriver: extraction failed: " e.Message)
        MsgBox("Extraction failed:`n" e.Message, "Extract Failed", "IconX")
        return
    }

    try {
        if !DirExist(DriversDir)
            DirCreate(DriversDir)
        Loop {
            SetDownloadButton(false, "Waiting for Steam to close...")
            if !WaitForSteamClosed() {
                try FileDelete(TempZip)
                try DirDelete(TempExtract, true)
                return
            }
            SetDownloadButton(false, "Copying files...")
            if !InStr(WipeFolder(DriverDir), "FAILED")
                break
            LogError("DownloadDriver: couldn't remove the old driver folder (a file is in use).")
            answer := MsgBox("Steam and SteamVR are closed, but something still has a file in the old driver folder open:`n" DriverDir "`n`n(Antivirus or a file explorer window can do this.) Close anything that might be using it, then click Retry. Cancel stops the install and leaves things as they are.", "Old Driver In Use", "RetryCancel IconX")
            if answer != "Retry"
                return
        }
        Sleep(200)
        exitCode := RunWait('cmd.exe /c xcopy /S /E /I /Y "' srcNull '\*" "' DriverDir '"', , "Hide")

        problem := exitCode != 0 ? "xcopy reported error code " exitCode "." : DriverFilesProblem(srcNull, DriverDir)
        if problem != "" {
            try FileDelete(DriverDir "\devkit_version.txt")
            LogError("DownloadDriver: copy incomplete: " problem)
            MsgBox("The driver files didn't copy completely:`n`n" problem "`n`nMake sure SteamVR is closed (and Steam, if it keeps happening), then click Download / Update again.", "Copy Incomplete", "IconX")
            return
        }
    } catch as e {
        MsgBox("Failed to copy driver files:`n" e.Message "`n`nTry running as administrator.", "Copy Failed", "IconX")
        return
    }

    ; Clean up temp files
    try {
        FileDelete(TempZip)
    }
    try {
        DirDelete(TempExtract, true)
    }

    newVersion := GetInstalledDriverVersion(DriverDir)
    if (newVersion != "" && !DriverIsOlder(newVersion) && (dllProblem := DriverDllProblem(DriverDir)) != "") {
        LogError("DownloadDriver: " dllProblem " after the copy.")
        MsgBox("The copy finished, but " dllProblem ". Something is still holding the old driver file (usually SteamVR; sometimes Steam itself).`n`nClose SteamVR, and Steam as well if that isn't enough, then click Download / Update again.", "Verification Failed", "IconX")
        return
    }
    if (newVersion = "" || DriverIsOlder(newVersion)) {
        LogError("DownloadDriver: post-install version mismatch, got '" newVersion "' expected '" ExpectedDriverVersion "'")
        MsgBox("The copy finished, but '" DriverDir "\devkit_version.txt' doesn't show the expected version (found: '" (newVersion = "" ? "none" : newVersion) "', expected: '" ExpectedDriverVersion "').`n`nSomething may have gone wrong during the copy - try running as administrator, make sure SteamVR isn't running, and try again. Use 'Copy Diagnostics' and send it to me if it keeps happening.", "Verification Failed", "IconX")
        return
    }

    try IniWrite(A_NowUTC, BootstrapFile, "Updates", "DriverInstalled")
    ReapplySavedDisplaySettings()
    RefreshUpdateNote()

    MsgBox("Null driver (version " ExpectedDriverVersion ") installed to:`n" DriverDir "`n`nStart Steam and SteamVR again to load the new driver.", "Done", "Iconi")
}

ConsoleCommandBusy := false

SendConsoleCommand(cmd) {
    global MovementModeRequested, MovementMode, ConsoleCommandBusy, ConsoleMS, GameConsoleOpen
    if cmd = ""
        return false
    if ConsoleCommandBusy
        return false

    if !WinExist("ahk_exe SkyrimVR.exe") {
        MsgBox("Couldn't find SkyrimVR.exe - is the game running?", "Not Found", "IconX")
        return false
    }

    ConsoleCommandBusy := true
    wasRequested := MovementModeRequested
    consoleWasOpen := GameConsoleOpen
    prevMode := A_SendMode
    try {
        MovementModeRequested := false
        MovementMode := false
        ReleaseSprintAlt()
        ReleaseGhostKeys()

        WinActivate("ahk_exe SkyrimVR.exe")
        if !WinWaitActive("ahk_exe SkyrimVR.exe", , 2) {
            MsgBox("SkyrimVR window didn't come to the front in time.", "Focus Failed", "IconX")
            return false
        }
        Sleep(150)

        prevClip := ClipboardAll()

        A_Clipboard := cmd
        if !ClipWait(1) {
            MsgBox("Clipboard didn't update in time - command not sent.", "Clipboard Failed", "IconX")
            A_Clipboard := prevClip
            return false
        }

        BlockInput("On")
        try {
            SendMode("Event")
            if !consoleWasOpen {
                Send("{sc029}")
                Sleep(ConsoleMS)
            }
            Send("{Ctrl down}")
            Sleep(ConsoleMS)
            Send("{sc02F down}")
            Sleep(ConsoleMS)
            Send("{sc02F up}")
            Sleep(ConsoleMS)
            Send("{Ctrl up}")
            Sleep(ConsoleMS)
            Send("{Enter}")
            Sleep(ConsoleMS)
            if !consoleWasOpen
                Send("{sc029}")
        } finally {
            BlockInput("Off")
            Send("{Ctrl up}")
            ; This chunk restores your clipboard properly.
            Sleep(50)
            A_Clipboard := prevClip
        }
        return true
    } finally {
        SendMode(prevMode)
        MovementModeRequested := wasRequested
        ConsoleCommandBusy := false
        GameConsoleOpen := consoleWasOpen
    }
}

MouseConsentBullet() {
    return "• MOUSE CAPTURE: The null driver (not this script) watches your mouse movement and right clicks. Only while mouse look is switched on in the game (right-click) does it hold your cursor in the middle of the SkyrimVR window and turn the view; nothing is recorded or sent anywhere, and it lets go within about half a second of Movement Mode pausing. You can switch it off in Settings > Controls."
}

ShowConsentDisclaimerIfNeeded() {
    global BootstrapFile, MouseLookEnabled
    currentVersion := 2
    alreadyAgreed := IniRead(BootstrapFile, "Consent", "Agreed", "0")
    if alreadyAgreed = "1" {
        agreedVersion := IniRead(BootstrapFile, "Consent", "Version", "1")
        if IsInteger(agreedVersion) && agreedVersion >= currentVersion
            return
        answer := MsgBox("This version adds something new that needs your consent:`n`n" MouseConsentBullet() "`n`nAllow mouse look?`n(No keeps the devkit working exactly as before. You can change this any time in Settings > Controls.)", "SkyrimVR Devkit - New Consent", "YesNo Icon!")
        MouseLookEnabled := (answer = "Yes")
        SaveControlSettings() ; also tells the driver straight away
        IniWrite(String(currentVersion), BootstrapFile, "Consent", "Version")
        return
    }

    disclaimerText :=
    (
        "SkyrimVR Devkit needs your consent for a few things before it runs:`n`n"
        "• INTERNET ACCESS: It can download files (the null driver) from GitHub when you click the download button. If you allow it, it also checks GitHub for newer releases when it starts (it only reads dates, nothing about you is sent).`n`n"
        "• FILESYSTEM ACCESS: It reads, writes, and moves files on your system - your SteamVR settings file, driver files, small text files it uses to talk to the driver, and another few small text files it uses to store information.`n`n"
        "• CLIPBOARD ACCESS: When sending console commands, it briefly places the command text on your clipboard, sends it to the game, then restores whatever you had copied before. Your existing clipboard contents are saved and put back automatically. Yes this includes image and video files.`n`n"
		"• KEY INTERCEPTION: When doing specific things, such as sending console commands, we temporarily block all keyboard inputs so you don't accidently press keys and screw up sending console commands.`n`n"
		"• SIMULATED KEY PRESSES: While Movement Mode is on, it presses keys that no physical keyboard has (F13 to F23) to tell the null driver what you're doing, and while sending console commands it types the console key, Ctrl+V and Enter into SkyrimVR. Software that reacts to those F-keys (macro pads, streaming tools) may notice them.`n`n"
		MouseConsentBullet() "`n`n"
		"You can read over what everything does VIA my Github at https://github.com/DubiousDuo/VR-Emulator-Driver---SkyrimVR-Devkit `n`n"
        "Do you consent to this and want to continue?"
    )

    result := MsgBox(disclaimerText, "SkyrimVR Devkit - Consent Required", "YesNo Icon!")
    if result = "Yes" {
        IniWrite("1", BootstrapFile, "Consent", "Agreed")
        IniWrite(String(currentVersion), BootstrapFile, "Consent", "Version")
    } else {
        MsgBox("The devkit cannot run without this consent. Exiting.", "Consent Declined", "IconX")
        ExitApp()
    }
}

DetectSteamDir() { 
    try {
        path := RegRead("HKCU\Software\Valve\Steam", "SteamPath")
        path := StrReplace(path, "/", "\")
        if DirExist(path)
            return path
    }
    return ""
}

EnsureDevkitPaths() {
    global SteamDir, DevkitDir, StagingDir, StagingFile, ConfigFile, LivePath, Active
    global ActionDir, ControlsFile
    global Root

    ActionDir := Root "\Actions"
    if !DirExist(ActionDir)
        DirCreate(ActionDir)

    ControlsFile := ActionDir "\controls.txt"

    for oldFile in ["headset_position_changes.txt", "headset_rotation_changes.txt", "controller1_position_changes.txt", "controller1_rotation_changes.txt", "controller2_position_changes.txt", "controller2_rotation_changes.txt"]
        try FileDelete(ActionDir "\" oldFile)

    if SteamDir = "" {
        DevkitDir := "", StagingDir := "", StagingFile := "", ConfigFile := "", LivePath := ""
        return
    }

    DevkitDir  := SteamDir "\config\SkyrimVR Devkit"
    StagingDir := DevkitDir "\Staging"
    ConfigFile := DevkitDir "\config.ini"
    LivePath   := SteamDir "\config\steamvr.vrsettings"

    if !DirExist(DevkitDir)
        DirCreate(DevkitDir)
    if !DirExist(StagingDir)
        DirCreate(StagingDir)

    StagingFile := StagingDir "\steamvr.vrsettings.bak"
    Active := IniRead(ConfigFile, "State", "Active", "Original")
}

SetSteamDir(*) {
    global SteamDir, LivePath, SteamEdit, LiveEdit, BootstrapFile
    startDir := SteamDir ? SteamDir : "C:\Program Files (x86)\Steam"
    selected := DirSelect(startDir, 3, "Select your Steam install folder (the one containing 'config' and 'steamapps')")
    if selected = ""
        return

    candidate := selected "\config\steamvr.vrsettings"
    if !FileExist(candidate) {
        result := MsgBox("Couldn't find:`n" candidate "`n`nUse this folder anyway?", "File not found", "YesNo IconX")
        if result = "No"
            return
    }

    SteamDir := selected
    IniWrite(SteamDir, BootstrapFile, "Paths", "SteamDir")
    EnsureDevkitPaths()
    try SteamEdit.Text := SteamDir
    try LiveEdit.Text  := LivePath
    UpdateStatus()
}

SetNullDriverEnabled(content, enabled) {
    global NullDriverKey, NullDriverAddonIdk

    keyPos := InStr(content, '"' NullDriverKey '"')
    if keyPos {
        enablePos := InStr(content, '"enable"', , keyPos)
        if !enablePos
            return false

        colonPos := InStr(content, ":", , enablePos)
        if !colonPos
            return false

        valueStart := colonPos + 1
        while (valueStart <= StrLen(content)) && InStr(" `t`r`n", SubStr(content, valueStart, 1))
            valueStart += 1

        valueEnd := valueStart
        while (valueEnd <= StrLen(content)) && !InStr(", `t`r`n}", SubStr(content, valueEnd, 1))
            valueEnd += 1

        before := SubStr(content, 1, valueStart - 1)
        after := SubStr(content, valueEnd)
        return before (enabled ? "true" : "false") after
    }

    trimmed := RTrim(content, " `t`r`n")
    if SubStr(trimmed, -1) != "}"
        return false
    beforeBrace := RTrim(SubStr(trimmed, 1, StrLen(trimmed) - 1), " `t`r`n")
    blockText := StrReplace(NullDriverAddonIdk, '"enable" : true', '"enable" : ' (enabled ? "true" : "false"))
    return beforeBrace ",`n" blockText "`n}`n"
}

InstallModded(*) {
    global LivePath, StagingFile, ConfigFile, Active
    if !ValidateLivePath()
        return
    if Active = "Modded" {
        MsgBox("Null driver is already active.", "Nothing to do", "Iconi")
        return
    }

    try {
        content := FileRead(LivePath, "UTF-8")
    } catch as e {
        MsgBox("Couldn't read the live file:`n" e.Message, "Error", "IconX")
        return
    }

    try {
        FileCopy(LivePath, StagingFile, true)
    } catch as e {
        MsgBox("Couldn't create a backup, aborting:`n" e.Message, "Error", "IconX")
        return
    }

    newContent := SetNullDriverEnabled(content, true)
    if newContent = false {
        MsgBox("Couldn't safely edit the driver_null block. Nothing was changed.", "Error", "IconX")
        return
    }

    try {
        WriteFileUtf8(LivePath, newContent)
    } catch as e {
        MsgBox("Couldn't write the modified file:`n" e.Message "`n`nTry running as administrator.", "Error", "IconX")
        return
    }

    Active := "Modded"
    IniWrite(Active, ConfigFile, "State", "Active")
    UpdateStatus()
    MsgBox("Null Driver enabled. Restart SteamVR if it's already running.", "Done", "Iconi")
}

RestoreOriginal(*) {
    global LivePath, StagingFile, ConfigFile, Active
    if !ValidateLivePath()
        return
    if Active = "Original" {
        MsgBox("Your original settings are already active.", "Nothing to do", "Iconi")
        return
    }

    try {
        content := FileRead(LivePath, "UTF-8")
    } catch as e {
        MsgBox("Couldn't read the live file:`n" e.Message, "Error", "IconX")
        return
    }

    newContent := SetNullDriverEnabled(content, false)
    if newContent = false {
        MsgBox("Couldn't safely edit the SteamVR settings file. Nothing was changed.", "Error", "IconX")
        return
    }

    try {
        WriteFileUtf8(LivePath, newContent)
    } catch as e {
        MsgBox("Couldn't write the modified file:`n" e.Message "`n`nTry running as administrator.", "Error", "IconX")
        return
    }

    Active := "Original"
    IniWrite(Active, ConfigFile, "State", "Active")
    UpdateStatus()
    MsgBox(
        "Null Driver disabled. Restart SteamVR if it's already running.`n`n"
		)
}

WriteFileUtf8(path, text) {
    tmp := path ".devkit_tmp"
    try FileDelete(tmp)
    f := FileOpen(tmp, "w", "UTF-8-RAW")
    if !IsObject(f)
        throw Error("Could not open file for writing: " tmp)
    f.Write(text)
    f.Close()
    FileMove(tmp, path, true)
}

ValidateLivePath() {
    global LivePath
    if LivePath = "" {
        MsgBox("Please set your Steam folder first.", "Steam folder not set", "IconX")
        return false
    }
    if !FileExist(LivePath) {
        MsgBox("Live file not found at:`n" LivePath, "File not found", "IconX")
        return false
    }
    return true
}

ReadNullDriverEnabled(content) {
    global NullDriverKey
    keyPos := InStr(content, '"' NullDriverKey '"')
    if !keyPos
        return ""
    enablePos := InStr(content, '"enable"', , keyPos)
    if !enablePos
        return ""
    colonPos := InStr(content, ":", , enablePos)
    if !colonPos
        return ""
    valueStart := colonPos + 1
    while (valueStart <= StrLen(content)) && InStr(" `t`r`n", SubStr(content, valueStart, 1))
        valueStart += 1
    valueEnd := valueStart
    while (valueEnd <= StrLen(content)) && !InStr(", `t`r`n}", SubStr(content, valueEnd, 1))
        valueEnd += 1
    value := SubStr(content, valueStart, valueEnd - valueStart)
    return (value = "true")
}

UpdateStatus(*) {
    global StatusText, Active, ChkDriverEnabled, StagingFile, LivePath, ConfigFile
    if (LivePath != "" && FileExist(LivePath)) {
        try {
            content := FileRead(LivePath, "UTF-8")
            actualEnabled := ReadNullDriverEnabled(content)
            if (actualEnabled != "") {
                actualActive := actualEnabled ? "Modded" : "Original"
                if (actualActive != Active) {
                    Active := actualActive
                    IniWrite(Active, ConfigFile, "State", "Active")
                }
            }
        }
    }

    StatusText.Text := (Active = "Modded") ? "Null driver" : "Original settings"
    ChkDriverEnabled.Value := (Active = "Modded") ? 1 : 0
}

ToggleDriverEnabled(ctrl, *) {
    global StagingFile
    if ctrl.Value {
        InstallModded()
    } else {
        hasBackup := (StagingFile != "" && FileExist(StagingFile)) ? true : false
        if !hasBackup {
            ctrl.Value := 1
            MsgBox("No backup of your original SteamVR settings was found, so this can't be turned off yet. Check the box again after it's been turned on at least once (that's what creates the backup).", "Can't Disable", "IconX")
            return
        }
        RestoreOriginal()
    }
    UpdateStatus()
}

RepoApi := "https://api.github.com/repos/DubiousDuo/VR-Emulator-Driver---SkyrimVR-Devkit"
UpdateCheckEveryHours := 6

UpdateFetch := Map()
UpdateFetchBusy := false

AsyncHttpGet(url) {
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(3000, 3000, 5000, 5000)
        http.Open("GET", url, true)
        http.SetRequestHeader("User-Agent", "SkyrimVR-Devkit-AHK")
        http.SetRequestHeader("Accept", "application/vnd.github+json")
        http.Send()
        return http
    }
    return ""
}

StartUpdateFetch() {
    global UpdateFetch, UpdateFetchBusy, RepoApi
    if UpdateFetchBusy
        return
    UpdateFetchBusy := true
    UpdateFetch := Map(
        "rel", AsyncHttpGet(RepoApi "/releases/latest"),
        "com", AsyncHttpGet(RepoApi "/commits?path=null%20driver.zip&per_page=1"),
        "relText", "", "comText", "", "start", A_TickCount)
    SetTimer(PollUpdateFetch, 200)
}

PollUpdateFetch() {
    global UpdateFetch, UpdateFetchBusy
    pending := false
    for key in ["rel", "com"] {
        req := UpdateFetch[key]
        if !IsObject(req)
            continue
        done := false
        try {
            done := req.WaitForResponse(0)
        } catch {
            done := true
        }
        timedOut := A_TickCount - UpdateFetch["start"] > 15000
        if !done && !timedOut {
            pending := true
            continue
        }
        if done {
            try {
                if req.Status = 200
                    UpdateFetch[key "Text"] := req.ResponseText
            }
        } else {
            try req.Abort()
        }
        UpdateFetch[key] := ""
    }
    if pending
        return
    SetTimer(PollUpdateFetch, 0)
    UpdateFetchBusy := false
    ApplyUpdateResults(UpdateFetch["relText"], UpdateFetch["comText"])
    RefreshUpdateNote()
}

ApplyUpdateResults(rel, com) {
    global BootstrapFile
    gotAny := false
    if RegExMatch(rel, '"published_at"\s*:\s*"([^"]+)"', &m) {
        IniWrite(IsoToStamp(m[1]), BootstrapFile, "Updates", "LatestFrontend")
        gotAny := true
    }
    if RegExMatch(rel, '"html_url"\s*:\s*"([^"]+)"', &m)
        IniWrite(m[1], BootstrapFile, "Updates", "FrontendURL")
    if RegExMatch(com, '"committer"\s*:\s*\{[^}]*?"date"\s*:\s*"([^"]+)"', &m) {
        IniWrite(IsoToStamp(m[1]), BootstrapFile, "Updates", "LatestDriver")
        gotAny := true
    }
    if gotAny
        IniWrite(A_NowUTC, BootstrapFile, "Updates", "LastCheckUTC")
}

IsoToStamp(iso) {
    return RegExReplace(iso, "\D", "")
}

CheckForUpdates() {
    global BootstrapFile, UpdateCheckEveryHours

    enabled := IniRead(BootstrapFile, "Updates", "Enabled", "")
    if enabled = "" {
        answer := MsgBox("Check GitHub for new devkit releases and null driver updates when this starts?`n`nIt only reads the date of the latest release and of the driver file - nothing about you is sent. You can change this later in Settings.", "Check for Updates?", "YesNo Iconi")
        enabled := (answer = "Yes") ? "1" : "0"
        IniWrite(enabled, BootstrapFile, "Updates", "Enabled")
    }
    if enabled != "1" {
        RefreshUpdateNote()
        return
    }

    stale := true
    lastCheck := IniRead(BootstrapFile, "Updates", "LastCheckUTC", "")
    if lastCheck != "" {
        try stale := DateDiff(A_NowUTC, lastCheck, "Hours") >= UpdateCheckEveryHours
    }

    RefreshUpdateNote()
    if stale
        StartUpdateFetch()
}

RefreshUpdateNote() {
    global BootstrapFile, SteamDir, ExpectedDriverVersion, UpdateNote, UpdateNoteURL, MainGui

    lines := []
    UpdateNoteURL := ""

    if IniRead(BootstrapFile, "Updates", "Enabled", "") = "1" {
        latestF := IniRead(BootstrapFile, "Updates", "LatestFrontend", "")
        seenF   := IniRead(BootstrapFile, "Updates", "SeenFrontend", "")
        if latestF != "" {
            if seenF = "" {
                IniWrite(latestF, BootstrapFile, "Updates", "SeenFrontend")
            } else if latestF > seenF {
                UpdateNoteURL := IniRead(BootstrapFile, "Updates", "FrontendURL", "https://github.com/DubiousDuo/VR-Emulator-Driver---SkyrimVR-Devkit/releases")
                lines.Push("A new devkit release is out - click here to open it (and dismiss this).")
            }
        }
        DriverDir := SteamVRDriverDir()
        installedVer := DriverDir != "" ? GetInstalledDriverVersion(DriverDir) : ""
        if installedVer != "" {
            latestD    := IniRead(BootstrapFile, "Updates", "LatestDriver", "")
            installedD := IniRead(BootstrapFile, "Updates", "DriverInstalled", "")
            if DriverIsOlder(installedVer) {
                lines.Push("Your null driver (" installedVer ") is older than this version expects (" ExpectedDriverVersion "). Settings > Download / Update.")
            } else if (dllProblem := DriverDllProblem(DriverDir)) != "" {
                lines.Push("Your null driver looks damaged (" dllProblem "). Settings > Download / Update to repair it.")
            } else if latestD != "" {
                if installedD = ""
                    IniWrite(latestD, BootstrapFile, "Updates", "DriverInstalled")
                else if latestD > installedD
                    lines.Push("A newer null driver is available. Settings > Download / Update.")
            }
        }
    }

    text := ""
    for line in lines
        text .= (text = "" ? "" : "`n") line

    try {
        if text = "" {
            if UpdateNote.Visible {
                UpdateNote.Visible := false
                UpdateNote.Move(, , , 1)
                MainGui.Show("AutoSize")
            }
        } else if !UpdateNote.Visible || UpdateNote.Text != text {
            UpdateNote.Text := text
            UpdateNote.Move(, , , 44 * lines.Length)
            UpdateNote.Visible := true
            MainGui.Show("AutoSize")
        }
    }
}

OnUpdateNoteClick(*) {
    global BootstrapFile, UpdateNoteURL
    if UpdateNoteURL = ""
        return
    Run(UpdateNoteURL)
    IniWrite(IniRead(BootstrapFile, "Updates", "LatestFrontend", ""), BootstrapFile, "Updates", "SeenFrontend")
    RefreshUpdateNote()
}

ToggleUpdateCheck(ctrl, *) {
    global BootstrapFile
    IniWrite(ctrl.Value ? "1" : "0", BootstrapFile, "Updates", "Enabled")
    if ctrl.Value
        SetTimer(CheckForUpdates, -200)
    else
        RefreshUpdateNote()
}

GetDriverSettingsFile() {
    global SteamDir
    if SteamDir = ""
        return ""
    dir := SteamVRDriverDir() "\resources\settings"
    Loop Files, dir "\*.vrsettings"
        return A_LoopFileFullPath
    return ""
}

ReadDisplaySettings(&w, &h, &fps) {
    file := GetDriverSettingsFile()
    if file = ""
        return false
    try text := FileRead(file, "UTF-8")
    catch
        return false
    if !RegExMatch(text, '"renderWidth"\s*:\s*(\d+)', &mw)
        return false
    if !RegExMatch(text, '"renderHeight"\s*:\s*(\d+)', &mh)
        return false
    if !RegExMatch(text, '"displayFrequency"\s*:\s*([\d.]+)', &mf)
        return false
    w := Integer(mw[1])
    h := Integer(mh[1])
    fps := Round(Number(mf[1]))
    return true
}

ApplyDisplaySettings(w, h, fps, silent := false) {
    global BootstrapFile
    file := GetDriverSettingsFile()
    if file = "" {
        if !silent
            MsgBox("The devkit's null driver isn't installed yet (or its settings file wasn't found). Install it from the General tab first.", "Driver Not Found", "IconX")
        return false
    }
    try {
        text := FileRead(file, "UTF-8")
        text := RegExReplace(text, '("renderWidth"\s*:\s*)[\d.]+', "${1}" w, &c1)
        text := RegExReplace(text, '("renderHeight"\s*:\s*)[\d.]+', "${1}" h, &c2)
        text := RegExReplace(text, '("displayFrequency"\s*:\s*)[\d.]+', "${1}" Format("{:.1f}", fps), &c3)
        if !(c1 && c2 && c3)
            throw Error("couldn't find renderWidth / renderHeight / displayFrequency in the file.")
        WriteFileUtf8(file, text)
    } catch as e {
        LogError("ApplyDisplaySettings failed: " e.Message)
        if !silent
            MsgBox("Couldn't update the driver's settings file:`n" e.Message "`n`nTry running as administrator, and make sure SteamVR is closed.", "Apply Failed", "IconX")
        return false
    }
    try {
        IniWrite(String(w), BootstrapFile, "Display", "Width")
        IniWrite(String(h), BootstrapFile, "Display", "Height")
        IniWrite(String(fps), BootstrapFile, "Display", "Fps")
    }
    return true
}

ReapplySavedDisplaySettings() {
    global BootstrapFile
    w   := IniRead(BootstrapFile, "Display", "Width", "")
    h   := IniRead(BootstrapFile, "Display", "Height", "")
    fps := IniRead(BootstrapFile, "Display", "Fps", "")
    if IsInteger(w) && IsInteger(h) && IsNumber(fps)
        ApplyDisplaySettings(Integer(w), Integer(h), Number(fps), true)
}

OnPresetChange(*) {
    global RenderPresets, DispPresetDDL, DispWEdit, DispHEdit
    idx := DispPresetDDL.Value
    custom := (idx = 0 || idx > RenderPresets.Length)
    if !custom {
        DispWEdit.Text := RenderPresets[idx].W
        DispHEdit.Text := RenderPresets[idx].H
    }
    DispWEdit.Enabled := custom
    DispHEdit.Enabled := custom
}

RefreshDisplayTab() {
    global RenderPresets, FpsOptions, DispPresetDDL, DispWEdit, DispHEdit, DispFpsDDL, DispStatus
    if !ReadDisplaySettings(&w, &h, &fps) {
        DispStatus.Text := "Install the devkit's null driver (General tab) to use these options."
        DispPresetDDL.Choose(1)
        OnPresetChange()
        DispFpsDDL.Choose(1)
        return
    }
    sel := RenderPresets.Length + 1
    for i, preset in RenderPresets {
        if preset.W = w && preset.H = h {
            sel := i
            break
        }
    }
    DispPresetDDL.Choose(sel)
    DispWEdit.Text := w
    DispHEdit.Text := h
    DispWEdit.Enabled := (sel > RenderPresets.Length)
    DispHEdit.Enabled := (sel > RenderPresets.Length)

    fpsSel := 0
    for i, option in FpsOptions {
        if option = fps {
            fpsSel := i
            break
        }
    }
    if fpsSel
        DispFpsDDL.Choose(fpsSel)
    DispStatus.Text := "Current driver settings: " w "x" h " per eye at " fps " FPS."
}

OnApplyDisplay(*) {
    global FpsOptions, DispWEdit, DispHEdit, DispFpsDDL, DispStatus
    w := DispWEdit.Text
    h := DispHEdit.Text
    if !IsInteger(w) || !IsInteger(h) || w < 320 || w > 8192 || h < 320 || h > 8192 {
        MsgBox("Width and height must be whole numbers between 320 and 8192.", "Invalid Resolution", "IconX")
        return
    }
    fpsIdx := DispFpsDDL.Value
    if fpsIdx = 0 {
        MsgBox("Pick a frame rate first.", "Frame Rate", "IconX")
        return
    }
    if ApplyDisplaySettings(Integer(w), Integer(h), FpsOptions[fpsIdx]) {
        RefreshDisplayTab()
        MsgBox("Saved. Restart SteamVR for the new resolution and frame rate to take effect.", "Applied", "Iconi")
    }
}

LaunchSteamVR(*) {
    Run("steam://rungameid/250820")
}

ToggleOpenComposite(*) {
    global BootstrapFile
    done := IniRead(BootstrapFile, "Setup", "OpenCompositeOff", "0") = "1"
    IniWrite(done ? "0" : "1", BootstrapFile, "Setup", "OpenCompositeOff")
    RefreshChecklist()
}

ToggleMovementDialogueEnabler(*) {
    global BootstrapFile
    done := IniRead(BootstrapFile, "Setup", "MovementDialogueEnablerOff", "0") = "1"
    IniWrite(done ? "0" : "1", BootstrapFile, "Setup", "MovementDialogueEnablerOff")
    RefreshChecklist()
}

SetupStepStates() {
    global SteamDir, Active, MovementModeRequested, ExpectedDriverVersion, BootstrapFile, SetupInstalledVer

    DriverDir := SteamVRDriverDir()
    SetupInstalledVer := DriverDir != "" ? GetInstalledDriverVersion(DriverDir) : ""

    done := Map()
    done["steam"]   := (SteamDir != "")
    done["oc"]      := (IniRead(BootstrapFile, "Setup", "OpenCompositeOff", "0") = "1")
    done["mde"]     := (IniRead(BootstrapFile, "Setup", "MovementDialogueEnablerOff", "0") = "1")
    done["driver"]  := (SetupInstalledVer != "" && !DriverIsOlder(SetupInstalledVer) && DriverDllProblem(DriverDir) = "")
    done["enabled"] := (Active = "Modded")
    done["steamvr"] := ProcessExist("vrserver.exe") ? true : false
    done["game"]    := ProcessExist("SkyrimVR.exe") ? true : false
    done["move"]    := MovementModeRequested ? true : false
    return done
}

SetupOneTimeStepsDone(done) {
    return done["steam"] && done["oc"] && done["mde"] && done["driver"] && done["enabled"]
}

MarkSetupComplete() {
    global BootstrapFile
    if IniRead(BootstrapFile, "Setup", "Completed", "0") != "1"
        IniWrite("1", BootstrapFile, "Setup", "Completed")
}

ChecklistEnableDriver(*) {
    InstallModded()
    UpdateStatus()
    RefreshChecklist()
}

ChecklistToggleMovement(*) {
    ToggleMovementMode()
    RefreshChecklist()
}

ChecklistDownload(*) {
    DownloadDriver()
    RefreshChecklist()
}

ChecklistSetSteam(*) {
    SetSteamDir()
    RefreshChecklist()
}

CloseSetupChecklist(*) {
    global SetupGui
    SetTimer(RefreshChecklist, 0)
    if IsObject(SetupGui)
        SetupGui.Destroy()
    SetupGui := ""
}

ShowSetupChecklist(*) {
    global SetupGui, SetupRows, DarkBGStr, DarkFGStr

    if IsObject(SetupGui) {
        if FocusWindow(SetupGui)
            return
        SetupGui := ""
    }

    SetupGui := Gui("+Resize", "SkyrimVR Devkit - Setup Checklist")
    SetupGui.BackColor := DarkBGStr
    SetupGui.SetFont("s10 c" DarkFGStr)
    SetupGui.MarginX := 15
    SetupGui.MarginY := 15
    ApplyDarkTitlebar(SetupGui)

    SetupGui.AddText("x15 y15 w600", "Work down the list. Each step turns green by itself once it's done.")

    steps := [
        {Key: "steam",   Label: "Steam folder found",                                          Btn: "Set Folder...",      Fn: ChecklistSetSteam},
        {Key: "oc",      Label: "OpenComposite turned OFF for SkyrimVR (tick it yourself)",    Btn: "I did this",         Fn: ToggleOpenComposite},
        {Key: "mde",     Label: "Movement Dialogue Enabler disabled in your modlist (tick it yourself)", Btn: "I did this", Fn: ToggleMovementDialogueEnabler},
        {Key: "driver",  Label: "Devkit null driver installed",                                Btn: "Download / Install", Fn: ChecklistDownload},
        {Key: "enabled", Label: "Null driver enabled in SteamVR",                              Btn: "Enable",             Fn: ChecklistEnableDriver},
        {Key: "steamvr", Label: "SteamVR running",                                             Btn: "Launch SteamVR",     Fn: LaunchSteamVR},
        {Key: "game",    Label: "SkyrimVR running (start it from your MO2 modlist or Steam)",  Btn: "",                   Fn: ""},
        {Key: "move",    Label: "Movement Mode ON (click it once the game window is focused)", Btn: "Toggle",             Fn: ChecklistToggleMovement}
    ]

    SetupRows := Map()
    y := 55
    for step in steps {
        st  := SetupGui.AddText("x15 y" y " w24 Center", "○")
        lbl := SetupGui.AddText("x45 y" y " w410", step.Label)
        btn := SetupGui.AddButton("x465 y" (y - 5) " w150 h28", step.Btn)
        if IsObject(step.Fn)
            btn.OnEvent("Click", step.Fn)
        else
            btn.Enabled := false
        SetupRows[step.Key] := {St: st, Lbl: lbl, Btn: btn, State: ""}
        y += 44
    }

    SetupGui.AddButton("x15 y" (y + 10) " w300 h30", "Open How To...").OnEvent("Click", ShowHowTo)
    SetupGui.AddButton("x315 y" (y + 10) " w300 h30", "Close").OnEvent("Click", CloseSetupChecklist)
    SetupGui.OnEvent("Close", CloseSetupChecklist)
    SetupGui.OnEvent("Escape", CloseSetupChecklist)

    RefreshChecklist()
    SetTimer(RefreshChecklist, 1000)
    SetupGui.Show("w630")
}

RefreshChecklist() {
    global SetupGui, SetupRows, SetupOrder, ExpectedDriverVersion, SetupInstalledVer

    if !IsObject(SetupGui) {
        SetTimer(RefreshChecklist, 0)
        return
    }

    done := SetupStepStates()
    if SetupOneTimeStepsDone(done)
        MarkSetupComplete()

    firstUndone := ""
    for key in SetupOrder {
        if !done[key] {
            firstUndone := key
            break
        }
    }

    for key, row in SetupRows {
        state := done[key] ? "done" : (key = firstUndone ? "next" : "todo")
        if key = "driver" && SetupInstalledVer != "" && !done["driver"]
            state .= "-old" ; installed, but older than needed or damaged
        if row.State = state
            continue
        row.State := state
        glyph := done[key] ? "✔" : (key = firstUndone ? "▶" : "○")
        color := done[key] ? "cLime" : (key = firstUndone ? "cFFD166" : "c909090")
        row.St.Text := glyph
        row.St.SetFont(color)
        row.Lbl.SetFont(done[key] ? "cE0E0E0" : color)
        if key = "oc" || key = "mde"
            row.Btn.Text := done[key] ? "Undo" : "I did this"
        else if key = "driver"
            row.Btn.Text := InStr(state, "-old") ? "Update / Repair Driver" : "Download / Install"
    }
}
