// devkit_input.h

#pragma once

#include <windows.h>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <locale>
#include <fstream>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>

namespace DevkitInput {

constexpr int kKeyLookUp     = VK_F16;
constexpr int kKeyLookDown   = VK_F17;
constexpr int kKeyLookLeft   = VK_F18;
constexpr int kKeyLookRight  = VK_F19;
constexpr int kKeyInteract   = VK_F20;
constexpr int kKeyReposition = VK_F21;
constexpr int kKeyReset      = VK_F22;
constexpr int kKeyHeartbeat  = VK_F23;
constexpr unsigned kRightGripBit = 1u << 16;
constexpr unsigned kLeftTrackpadClickBit = 1u << 12;
constexpr unsigned kLeftTrackpadTouchBit = 1u << 13;
constexpr wchar_t kButtonMappingName[] = L"Local\\SkyrimVRDevkit.ControllerButtons.v1";
constexpr int kKeyButtonA    = VK_F24; // Select: the right controller's A and trigger, held as long as the key is (SteamVR's dashboard)

constexpr double kHeartbeatTimeout   = 0.4;   // seconds without a heartbeat change = frontend gone
constexpr double kButtonANoHeartbeat = 2.0;   // A held without the heartbeat counts this long at most
constexpr double kInteractTouchGap   = 0.010; // touch, then click this long after
constexpr double kInteractClickHold  = 0.100; // hold the click this long, then release both (SteamVR only accepts clicks if the touchpad is being touched and clicked at the same time, since it's impossible to do one without the other IRL)
constexpr double kDefaultTurnSpeed   = 216.0; // degrees per second
constexpr double kMaxFrameDt         = 0.1;   // a hitch longer than this doesn't cause a turn jump
constexpr double kMaxPitch           = 89.0;  // look up/down stops here, like a neck
constexpr double kDefaultMouseSens   = 0.05;  // degrees per mouse count (the frontend sends this times its slider)
constexpr const char* kDriverBuild   = "2.0.1"; // reported in driver_status.txt
constexpr double kMaxMouseStep       = 90.0;  // most the mouse can turn in one frame, so a burst can't spin the view

struct Pose {
    double px = 0, py = 0, pz = 0;
    double ow = 1, ox = 0, oy = 0, oz = 0;
};

struct Keys {
    bool lookUp = false, lookDown = false, lookLeft = false, lookRight = false;
    bool interact = false, reposition = false, reset = false, heartbeat = false;
    unsigned buttonWord = 0;
    bool buttonMappingValid = false;
    bool buttonA = false;

    // Mouse, collected by the Raw Input thread since the last frame.
    long mouseDx = 0, mouseDy = 0;
    int  mouseToggles = 0;
    bool gameFocused = false;
};

struct ButtonMapping {
    HANDLE handle = nullptr;
    volatile LONG* view = nullptr;
    double nextOpen = -1;

    void Close() {
        if (view) UnmapViewOfFile(const_cast<LONG*>(view));
        if (handle) CloseHandle(handle);
        view = nullptr;
        handle = nullptr;
        nextOpen = -1;
    }

    ~ButtonMapping() { Close(); }

    bool Read(double t, unsigned& word) {
        word = 0;
        if (!view && t >= nextOpen) {
            nextOpen = t + 1.0;
            handle = OpenFileMappingW(FILE_MAP_READ | FILE_MAP_WRITE, FALSE, kButtonMappingName);
            if (handle) {
                view = static_cast<volatile LONG*>(MapViewOfFile(handle, FILE_MAP_READ | FILE_MAP_WRITE, 0, 0, sizeof(LONG)));
                if (!view) {
                    CloseHandle(handle);
                    handle = nullptr;
                }
            }
        }
        if (!view) return false;
        const unsigned value = static_cast<unsigned>(InterlockedCompareExchange(view, 0, 0));
        if (value & 0xf0000000u) return false;
        word = value;
        return true;
    }
};

struct Shared {
    std::mutex m;
    Pose pose;
    double pitchDeg = 0; // total pitch applied so far, tracked so it can be clamped
    double yawDeg = 0;

    bool   initialized = false;
    double lastUpdate = 0;

    // heartbeat tracking
    bool   hbSeen = false;
    bool   hbState = false;
    double hbChange = 0;

    // edge detection
    bool prevInteract = false, prevReposition = false, prevReset = false;

    // interact sequence: 0 idle, 1 touching (waiting to click), 2 clicking
    int    interactState = 0;
    double interactT = 0;
    bool   trackpadTouch = false, trackpadClick = false;
    ButtonMapping buttonMapping;
    bool buttonMappingValid = false;
    bool rightGripRaw = false, rightGrip = false, rightGripEverSeen = false;
    unsigned leftTrackpadRaw = 0, leftTrackpad = 0, leftTrackpadEverSeen = 0;
    bool   buttonA = false, prevButtonA = false;
    double buttonADown = 0;

    // The game's process id from <Actions>/game_pid.txt (written by the frontend), 0 if none
    DWORD  gamePid = 0;
    double lastPidCheck = -1;
    std::string gameMatch = "none"; // how the focused window was recognised, for driver_status.txt

    // settings
    double turnSpeed = kDefaultTurnSpeed;
    double lastCfgCheck = -1;
    bool   mouseEnabled = true;            // master switch
    double mouseSens = kDefaultMouseSens;
    bool   mouseInvertY = false;

    bool   mouseLook = false;
    bool   mouseGrab = false;
    double viewX = -0.4, viewY = -0.3, viewZ = 0;
    bool   viewRotate = true;

    // Reported in driver_status.txt (so a bug report can show what the driver actually sees)
    long long frames = 0;          // frames the driver has processed
    bool      alive = false;       // heartbeat alive at the last frame
    long      hbChanges = 0;       // how many times the heartbeat key has flipped
    unsigned  seenMask = 0;        // bit per ghost key (look up/down/left/right, interact, reposition, reset, heartbeat) ever seen down
    unsigned  heldMask = 0;        // same bits, held right now
    bool      cfgFound = false;    // controls.txt was found and read
    double    lastStatusWrite = -10;
};

inline Shared& S()
{
    static Shared s;
    return s;
}

inline std::string ActionsDir()
{
    static std::string cached;
    if (!cached.empty()) {
        return cached;
    }

    std::string base;
    char* localAppData = nullptr;
    size_t len = 0;
    if (_dupenv_s(&localAppData, &len, "LOCALAPPDATA") == 0 && localAppData != nullptr) {
        base = localAppData;
        free(localAppData);
    }
    else {
        char* userProfile = nullptr;
        if (_dupenv_s(&userProfile, &len, "USERPROFILE") == 0 && userProfile != nullptr) {
            base = std::string(userProfile) + "\\AppData\\Local";
            free(userProfile);
        }
    }
    cached = base + "/SkyrimVR Devkit/Actions/";
    return cached;
}

inline double NowSeconds()
{
    static const LARGE_INTEGER freq = [] { LARGE_INTEGER f; QueryPerformanceFrequency(&f); return f; }();
    LARGE_INTEGER c;
    QueryPerformanceCounter(&c);
    return static_cast<double>(c.QuadPart) / static_cast<double>(freq.QuadPart);
}

inline bool KeyDown(int vk)
{
    return (GetAsyncKeyState(vk) & 0x8000) != 0;
}

inline void QuatMultiply(
    double aw, double ax, double ay, double az,
    double bw, double bx, double by, double bz,
    double& rw, double& rx, double& ry, double& rz)
{
    rw = aw * bw - ax * bx - ay * by - az * bz;
    rx = aw * bx + ax * bw + ay * bz - az * by;
    ry = aw * by - ax * bz + ay * bw + az * bx;
    rz = aw * bz + ax * by - ay * bx + az * bw;
}

inline void ApplyRotation(Pose& p, double pitchDeg, double yawDeg)
{
    if (pitchDeg == 0 && yawDeg == 0) {
        return;
    }
    const double kPi = 3.14159265358979323846;
    const double halfPitch = pitchDeg * kPi / 180.0 * 0.5;
    const double halfYaw = yawDeg * kPi / 180.0 * 0.5;

    const double yw = cos(halfYaw), yx = 0.0, yy = sin(halfYaw), yz = 0.0;
    const double pw = cos(halfPitch), px = sin(halfPitch), py = 0.0, pz = 0.0;

    double tw, tx, ty, tz;
    QuatMultiply(p.ow, p.ox, p.oy, p.oz, pw, px, py, pz, tw, tx, ty, tz);
    QuatMultiply(yw, yx, yy, yz, tw, tx, ty, tz, p.ow, p.ox, p.oy, p.oz);

    const double len = sqrt(p.ow * p.ow + p.ox * p.ox + p.oy * p.oy + p.oz * p.oz);
    if (len > 0) {
        p.ow /= len; p.ox /= len; p.oy /= len; p.oz /= len;
    }
}

inline void Step(Shared& s, const Keys& k, double t)
{
    double dt = s.initialized ? (t - s.lastUpdate) : 0.0;
    if (dt < 0) dt = 0;
    if (dt > kMaxFrameDt) dt = kMaxFrameDt;
    s.lastUpdate = t;
    s.initialized = true;
    s.frames++;

    // Heartbeat: "alive" while the key's state has changed within the timeout. The very first
    // observation only records the state and counts as DEAD: if the driver starts while a previous
    // frontend died holding keys down (including the heartbeat key), nothing may move until a real
    // change is seen. Just a saftey feature because who doesn't love how Windows handles things!!!!
    if (!s.hbSeen) {
        s.hbSeen = true;
        s.hbState = k.heartbeat;
        s.hbChange = t - kHeartbeatTimeout - 1.0;
    }
    else if (k.heartbeat != s.hbState) {
        s.hbState = k.heartbeat;
        s.hbChange = t;
        s.hbChanges++;
    }
    const bool alive = (t - s.hbChange) < kHeartbeatTimeout;
    s.alive = alive;
    s.heldMask = (k.lookUp ? 1u : 0u) | (k.lookDown ? 2u : 0u) | (k.lookLeft ? 4u : 0u) | (k.lookRight ? 8u : 0u)
               | (k.interact ? 16u : 0u) | (k.reposition ? 32u : 0u) | (k.reset ? 64u : 0u) | (k.heartbeat ? 128u : 0u);
    s.seenMask |= s.heldMask;

    s.buttonMappingValid = k.buttonMappingValid;
    s.rightGripRaw = k.buttonMappingValid && (k.buttonWord & kRightGripBit) != 0;
    s.rightGripEverSeen = s.rightGripEverSeen || s.rightGripRaw;
    s.rightGrip = alive && s.rightGripRaw;
    s.leftTrackpadRaw = k.buttonMappingValid ? k.buttonWord & (kLeftTrackpadClickBit | kLeftTrackpadTouchBit) : 0;
    s.leftTrackpadEverSeen |= s.leftTrackpadRaw;
    s.leftTrackpad = alive ? s.leftTrackpadRaw : 0;

    if (k.reposition && !s.prevReposition) {
        double x = s.viewX, z = s.viewZ;
        if (s.viewRotate) {
            const double rad = s.yawDeg * 3.14159265358979323846 / 180.0;
            const double c = cos(rad), sn = sin(rad);
            x = s.viewX * c + s.viewZ * sn;
            z = -s.viewX * sn + s.viewZ * c;
        }
        s.pose.px = x; s.pose.py = s.viewY; s.pose.pz = z;
    }
    if (k.reset && !s.prevReset) {
        s.pose.px = 0; s.pose.py = 0; s.pose.pz = 0;
    }
    s.prevReposition = k.reposition;
    s.prevReset = k.reset;

    if (!s.mouseEnabled || !alive || !k.gameFocused) {
        s.mouseLook = false;
    }
    else if ((k.mouseToggles & 1) != 0) {
        s.mouseLook = !s.mouseLook;
    }
    s.mouseGrab = s.mouseLook;
    double mouseYaw = 0, mousePitch = 0;
    if (s.mouseLook) {
        mouseYaw = -static_cast<double>(k.mouseDx) * s.mouseSens;
        mousePitch = -static_cast<double>(k.mouseDy) * s.mouseSens * (s.mouseInvertY ? -1.0 : 1.0);
        if (mouseYaw > kMaxMouseStep) mouseYaw = kMaxMouseStep;
        if (mouseYaw < -kMaxMouseStep) mouseYaw = -kMaxMouseStep;
        if (mousePitch > kMaxMouseStep) mousePitch = kMaxMouseStep;
        if (mousePitch < -kMaxMouseStep) mousePitch = -kMaxMouseStep;
    }

    {
        double pitchStep = mousePitch;
        double yawStep = mouseYaw;
        if (alive) {
            const double pitchAxis = (k.lookUp ? 1.0 : 0.0) - (k.lookDown ? 1.0 : 0.0);
            const double yawAxis   = (k.lookLeft ? 1.0 : 0.0) - (k.lookRight ? 1.0 : 0.0);
            pitchStep += pitchAxis * s.turnSpeed * dt;
            yawStep += yawAxis * s.turnSpeed * dt;
        }

        double newPitch = s.pitchDeg + pitchStep;
        if (newPitch > kMaxPitch) newPitch = kMaxPitch;
        if (newPitch < -kMaxPitch) newPitch = -kMaxPitch;
        pitchStep = newPitch - s.pitchDeg;
        s.pitchDeg = newPitch;
        s.yawDeg = fmod(s.yawDeg + yawStep, 360.0);
        ApplyRotation(s.pose, pitchStep, yawStep);
    }

    // Interact: R press -> trackpad touch, then click 10 ms later, released 100 ms after that. (Read above for why we do this. Not typing that shit out again.)
    const bool interact = alive && k.interact;
    if (!alive) {
        s.interactState = 0;
        s.trackpadTouch = false;
        s.trackpadClick = false;
    }
    else if (interact && !s.prevInteract && s.interactState == 0) {
        s.trackpadTouch = true;
        s.interactState = 1;
        s.interactT = t;
    }
    else if (s.interactState == 1 && (t - s.interactT) >= kInteractTouchGap) {
        s.trackpadClick = true;
        s.interactState = 2;
        s.interactT = t;
    }
    else if (s.interactState == 2 && (t - s.interactT) >= kInteractClickHold) {
        s.trackpadClick = false;
        s.trackpadTouch = false;
        s.interactState = 0;
    }
    s.prevInteract = interact;

    // A: held while its ghost key is held. Without the heartbeat (the frontend's own window has focus when its Select
    // button is clicked, which pauses Movement Mode) only for kButtonANoHeartbeat: a key the frontend pressed is never
    // released if it dies, and A must not stay held then.
    if (k.buttonA && !s.prevButtonA) {
        s.buttonADown = t;
    }
    s.prevButtonA = k.buttonA;
    s.buttonA = k.buttonA && (alive || (t - s.buttonADown) < kButtonANoHeartbeat);
}

inline void RefreshConfig(Shared& s, double t)
{
    if (s.lastCfgCheck >= 0 && (t - s.lastCfgCheck) < 0.5) return;
    s.lastCfgCheck = t;
    std::ifstream f(ActionsDir() + "controls.txt");
    if (!f.is_open()) { s.cfgFound = false; return; }
    s.cfgFound = true;
    std::string key, text;
    while (f >> key >> text) {
        char* end = nullptr;
        const double value = std::strtod(text.c_str(), &end);
        if (end == text.c_str() || *end != '\0' || !std::isfinite(value)) continue;
        if (key == "turn_speed" && value > 0 && value < 2000) s.turnSpeed = value;
        else if (key == "mouse_sens" && value > 0 && value < 10) s.mouseSens = value;
        else if (key == "mouse_invert_y") s.mouseInvertY = (value != 0);
        else if (key == "mouse_enabled") s.mouseEnabled = (value != 0);
    }
}

inline void RefreshViewFile(Shared& s)
{
    const std::string path = ActionsDir() + "console_view.txt";
    std::ifstream f(path);
    if (!f.is_open()) {
        std::ofstream out(path);
        if (out.is_open()) {
            out << "view_x " << s.viewX << "\n"
                << "view_y " << s.viewY << "\n"
                << "view_z " << s.viewZ << "\n"
                << "view_rotate " << (s.viewRotate ? 1 : 0) << "\n";
        }
        return;
    }
    std::string key;
    double value = 0;
    while (f >> key >> value) {
        if (value < -1000 || value > 1000) continue; //Safeguard for I don't remember. All I know is that when I remove this, sometimes something breaks.
        if (key == "view_x") s.viewX = value;
        else if (key == "view_y") s.viewY = value;
        else if (key == "view_z") s.viewZ = value;
        else if (key == "view_rotate") s.viewRotate = (value != 0);
    }
}

struct MouseIn {
    std::atomic<long> dx{0}, dy{0};
    std::atomic<int>  toggles{0};
    std::atomic<long long> rawEvents{0};   // mouse events the Raw Input thread has received (for driver_status.txt)
    std::atomic<long long> rightClicks{0};
    std::atomic<bool> started{false};
    std::atomic<bool> finished{false};
    std::atomic<HWND> hwnd{nullptr};
    std::thread th;
    bool clipped = false;
};

inline MouseIn& M()
{
    static MouseIn* m = new MouseIn;
    return *m;
}

inline LRESULT CALLBACK MouseSinkProc(HWND h, UINT msg, WPARAM wp, LPARAM lp)
{
    switch (msg) {
    case WM_INPUT: {
        UINT size = 0;
        if (GetRawInputData(reinterpret_cast<HRAWINPUT>(lp), RID_INPUT, nullptr, &size, sizeof(RAWINPUTHEADER)) == 0
            && size > 0 && size <= 512) {
            alignas(8) BYTE buf[512];
            if (GetRawInputData(reinterpret_cast<HRAWINPUT>(lp), RID_INPUT, buf, &size, sizeof(RAWINPUTHEADER)) == size) {
                const RAWINPUT* ri = reinterpret_cast<const RAWINPUT*>(buf);
                if (ri->header.dwType == RIM_TYPEMOUSE) {
                    const RAWMOUSE& rm = ri->data.mouse;
                    M().rawEvents++;
                    if (!(rm.usFlags & MOUSE_MOVE_ABSOLUTE)) {
                        M().dx += rm.lLastX;
                        M().dy += rm.lLastY;
                    }
                    if (rm.usButtonFlags & RI_MOUSE_RIGHT_BUTTON_DOWN) {
                        M().toggles++;
                        M().rightClicks++;
                    }
                }
            }
        }
        break;
    }
    case WM_CLOSE:
        DestroyWindow(h);
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(h, msg, wp, lp);
}

inline void MouseThreadMain()
{
    HMODULE self = nullptr; // our own DLL: the window class must not outlive it
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       reinterpret_cast<LPCWSTR>(&MouseSinkProc), &self);
    WNDCLASSW wc = {};
    wc.lpfnWndProc = MouseSinkProc;
    wc.hInstance = self;
    wc.lpszClassName = L"DevkitMouseSink";
    if (RegisterClassW(&wc) != 0) {
        HWND h = CreateWindowExW(0, wc.lpszClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, self, nullptr);
        if (h) {
            RAWINPUTDEVICE rid = {};
            rid.usUsagePage = 0x01;
            rid.usUsage = 0x02;
            rid.dwFlags = RIDEV_INPUTSINK;
            rid.hwndTarget = h;
            if (RegisterRawInputDevices(&rid, 1, sizeof(rid))) {
                M().hwnd = h;
                MSG msg;
                while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
                    TranslateMessage(&msg);
                    DispatchMessageW(&msg);
                }
                rid.dwFlags = RIDEV_REMOVE;
                rid.hwndTarget = nullptr;
                RegisterRawInputDevices(&rid, 1, sizeof(rid));
            }
            if (IsWindow(h)) {
                DestroyWindow(h);
            }
            M().hwnd = nullptr;
        }
        UnregisterClassW(wc.lpszClassName, self);
    }
    M().finished = true;
}

inline void EnsureMouseThread()
{
    MouseIn& m = M();
    if (!m.started.exchange(true)) {
        m.finished = false;
        m.th = std::thread(MouseThreadMain);
    }
}

inline void StopMouseThread()
{
    MouseIn& m = M();
    if (!m.started.load()) {
        return;
    }
    for (int i = 0; i < 100 && !m.hwnd.load() && !m.finished.load(); ++i) {
        Sleep(10); //Simple safeguard. 
    }
    const HWND h = m.hwnd.load();
    if (h) {
        PostMessageW(h, WM_CLOSE, 0, 0);
    }
    if (m.th.joinable()) {
        m.th.join();
    }
    m.dx = 0;
    m.dy = 0;
    m.toggles = 0;
    m.hwnd = nullptr;
    m.finished = false;
    m.started = false;
}

// The game runs as SkyrimVR.exe, or inside a launcher's own process: urSovngarde (the co-op mod, also under its old
// name SkyrimTogetherVR.exe) loads the game into itself, so the window belongs to the launcher.
inline bool IsGameExePath(const wchar_t* path)
{
    const wchar_t* base = wcsrchr(path, L'\\');
    base = base ? base + 1 : path;
    return _wcsicmp(base, L"SkyrimVR.exe") == 0 || _wcsicmp(base, L"vrcompositor.exe") == 0
        || _wcsicmp(base, L"urSovngarde.exe") == 0 || _wcsicmp(base, L"SkyrimTogetherVR.exe") == 0;
}

// Any other launcher: the frontend finds the game's window and writes its process id to <Actions>/game_pid.txt.
// Read at most once a second; a missing or empty file means no id.
inline void RefreshGamePid(Shared& s, double t)
{
    if (s.lastPidCheck >= 0 && (t - s.lastPidCheck) < 1.0) {
        return;
    }
    s.lastPidCheck = t;
    std::ifstream f(ActionsDir() + "game_pid.txt");
    unsigned long pid = 0;
    if (!f.is_open() || !(f >> pid)) {
        pid = 0;
    }
    s.gamePid = static_cast<DWORD>(pid);
}

inline HWND ForegroundGameWindow(Shared& st, double t)
{
    static HWND lastWnd = nullptr;
    static bool lastOk = false;
    static double lastT = -1;
    HWND h = GetForegroundWindow();
    if (!h) {
        lastWnd = nullptr;
        return nullptr;
    }
    if (h == lastWnd && (t - lastT) < 0.25) {
        return lastOk ? h : nullptr;
    }
    lastWnd = h;
    lastT = t;
    lastOk = false;
    st.gameMatch = "none";
    DWORD pid = 0;
    GetWindowThreadProcessId(h, &pid);
    if (pid != 0 && pid == st.gamePid) {
        lastOk = true;
        st.gameMatch = "pid";
    }
    else if (pid != 0) {
        HANDLE p = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
        if (p) {
            wchar_t buf[2 * MAX_PATH];
            DWORD n = static_cast<DWORD>(sizeof(buf) / sizeof(buf[0]));
            if (QueryFullProcessImageNameW(p, 0, buf, &n)) {
                lastOk = IsGameExePath(buf);
                if (lastOk) {
                    const wchar_t* base = wcsrchr(buf, L'\\');
                    base = base ? base + 1 : buf;
                    char name[MAX_PATH] = {};
                    WideCharToMultiByte(CP_UTF8, 0, base, -1, name, sizeof(name) - 1, nullptr, nullptr);
                    st.gameMatch = name;
                }
            }
            CloseHandle(p);
        }
    }
    return lastOk ? h : nullptr;
}

//This is where the cursor gets taken over. Tried to make it not sketchy, but in the end you're still locking a cursor.
inline void ApplyMouseGrab(Shared& s, HWND gameWnd)
{
    MouseIn& m = M();
    struct DpiScope {
        DPI_AWARENESS_CONTEXT old;
        DpiScope() : old(SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)) {}
        ~DpiScope() { if (old) SetThreadDpiAwarenessContext(old); }
    } dpiScope;
    if (s.mouseGrab && gameWnd && !IsIconic(gameWnd)) {
        RECT cr;
        if (GetClientRect(gameWnd, &cr)) {
            POINT c = { (cr.left + cr.right) / 2, (cr.top + cr.bottom) / 2 };
            ClientToScreen(gameWnd, &c);
            RECT want = { c.x, c.y, c.x + 1, c.y + 1 };
            RECT cur;
            const bool same = GetClipCursor(&cur) && cur.left == want.left && cur.top == want.top
                              && cur.right == want.right && cur.bottom == want.bottom;
            if (!same) {
                ClipCursor(&want);
                SetCursorPos(c.x, c.y);
            }
            m.clipped = true;
            return;
        }
    }
    if (m.clipped) {
        ClipCursor(nullptr);
        m.clipped = false;
    }
}

// ---- driver_status.txt ---------------------------------------------------------------------------------
// Once a second the driver writes what it currently sees to <Actions>/driver_status.txt. The frontend's Copy
// Diagnostics (and its "Live" line) read it, so a "look around doesn't work" report can say whether the driver
// is receiving the heartbeat and keys at all, and whether mouse input is arriving.
inline std::string KeyNames(unsigned mask)
{
    static const char* names[8] = { "F16", "F17", "F18", "F19", "F20", "F21", "F22", "F23" };
    std::string out;
    for (int i = 0; i < 8; ++i) {
        if (mask & (1u << i)) {
            out += (out.empty() ? "" : ",");
            out += names[i];
        }
    }
    return out.empty() ? "none" : out;
}

inline std::string BuildStatus(const Shared& s, double t, bool gameFocused)
{
    MouseIn& m = M();
    char num[64];
    std::ostringstream o;
    o.imbue(std::locale::classic());
    o << "driver_build " << kDriverBuild << "\n";
    o << "frames " << s.frames << "\n";
    o << "heartbeat_alive " << (s.alive ? 1 : 0) << "\n";
    o << "heartbeat_changes " << s.hbChanges << "\n";
    std::snprintf(num, sizeof(num), "%.1f", s.hbChanges > 0 ? (t - s.hbChange) : -1.0);
    o << "heartbeat_last_change_age " << num << "\n";
    o << "keys_ever_seen " << KeyNames(s.seenMask) << "\n";
    o << "keys_held_now " << KeyNames(s.heldMask) << "\n";
    o << "controller_buttons_mapping_valid " << (s.buttonMappingValid ? 1 : 0) << "\n";
    o << "right_grip_raw " << (s.rightGripRaw ? 1 : 0) << "\n";
    o << "right_grip " << (s.rightGrip ? 1 : 0) << "\n";
    o << "right_grip_ever_seen " << (s.rightGripEverSeen ? 1 : 0) << "\n";
    o << "left_trackpad_click_raw " << ((s.leftTrackpadRaw & kLeftTrackpadClickBit) ? 1 : 0) << "\n";
    o << "left_trackpad_touch_raw " << ((s.leftTrackpadRaw & kLeftTrackpadTouchBit) ? 1 : 0) << "\n";
    o << "left_trackpad_click " << ((s.leftTrackpad & kLeftTrackpadClickBit) ? 1 : 0) << "\n";
    o << "left_trackpad_touch " << ((s.leftTrackpad & kLeftTrackpadTouchBit) ? 1 : 0) << "\n";
    o << "left_trackpad_ever_seen " << s.leftTrackpadEverSeen << "\n";
    o << "game_focused " << (gameFocused ? 1 : 0) << "\n";
    o << "game_pid " << s.gamePid << "\n";
    o << "game_match " << s.gameMatch << "\n";
    o << "button_a " << (s.buttonA ? 1 : 0) << "\n";
    o << "controls_file_found " << (s.cfgFound ? 1 : 0) << "\n";
    o << "mouse_enabled " << (s.mouseEnabled ? 1 : 0) << "\n";
    o << "mouse_thread_running " << (m.hwnd.load() ? 1 : 0) << "\n";
    o << "mouse_raw_events " << m.rawEvents.load() << "\n";
    o << "mouse_right_clicks " << m.rightClicks.load() << "\n";
    o << "mouse_look " << (s.mouseLook ? 1 : 0) << "\n";
    std::snprintf(num, sizeof(num), "%.1f", s.yawDeg);
    o << "yaw_deg " << num << "\n";
    std::snprintf(num, sizeof(num), "%.1f", s.pitchDeg);
    o << "pitch_deg " << num << "\n";
    std::snprintf(num, sizeof(num), "%.1f", s.turnSpeed);
    o << "turn_speed " << num << "\n";
    return o.str();
}

// Written to a temp file and swapped in, so the frontend never reads half of it. Quietly does nothing if the
// Actions folder doesn't exist yet (the frontend creates it).
inline void WriteStatusFile(const std::string& text)
{
    const std::string path = ActionsDir() + "driver_status.txt";
    const std::string tmp = path + ".tmp";
    {
        std::ofstream f(tmp, std::ios::trunc);
        if (!f.is_open()) {
            return;
        }
        f << text;
    }
    MoveFileExA(tmp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING);
}

inline void Update()
{
    Shared& s = S();
    std::string status;
    {
    std::lock_guard<std::mutex> lock(s.m);

    const double t = NowSeconds();
    if (s.initialized && (t - s.lastUpdate) < 0.002) {
        return;
    }

    RefreshConfig(s, t);
    if (s.mouseEnabled) {
        EnsureMouseThread();
    }
    else {
        StopMouseThread();
    }
    RefreshGamePid(s, t);
    const HWND gameWnd = ForegroundGameWindow(s, t);

    Keys k;
    k.gameFocused = (gameWnd != nullptr);
    {
        MouseIn& m = M();
        k.mouseDx = m.dx.exchange(0);
        k.mouseDy = m.dy.exchange(0);
        k.mouseToggles = m.toggles.exchange(0);
    }
    k.lookUp = KeyDown(kKeyLookUp);
    k.lookDown = KeyDown(kKeyLookDown);
    k.lookLeft = KeyDown(kKeyLookLeft);
    k.lookRight = KeyDown(kKeyLookRight);
    k.interact = KeyDown(kKeyInteract);
    k.reposition = KeyDown(kKeyReposition);
    k.reset = KeyDown(kKeyReset);
    k.heartbeat = KeyDown(kKeyHeartbeat);
    k.buttonMappingValid = s.buttonMapping.Read(t, k.buttonWord);
    k.buttonA = KeyDown(kKeyButtonA);
    if (k.reposition && !s.prevReposition) {
        RefreshViewFile(s);
    }
    Step(s, k, t);
    ApplyMouseGrab(s, gameWnd);
    if (t - s.lastStatusWrite >= 1.0) {
        s.lastStatusWrite = t;
        status = BuildStatus(s, t, k.gameFocused);
    }
    }
    if (!status.empty()) {
        WriteStatusFile(status); // outside the lock: file I/O shouldn't hold up the poses
    }
}

// Called when the driver unloads: frees the cursor and stops the mouse thread.
inline void Shutdown()
{
    Shared& s = S();
    {
        std::lock_guard<std::mutex> lock(s.m);
        s.mouseLook = false;
        s.mouseGrab = false;
        ApplyMouseGrab(s, nullptr);
        s.rightGrip = false;
        s.leftTrackpad = 0;
        s.buttonMapping.Close();
    }
    StopMouseThread();
}

inline Pose Snapshot()
{
    Shared& s = S();
    std::lock_guard<std::mutex> lock(s.m);
    return s.pose;
}

inline void GetTrackpad(bool& touch, bool& click)
{
    Shared& s = S();
    std::lock_guard<std::mutex> lock(s.m);
    touch = s.trackpadTouch;
    click = s.trackpadClick;
}

inline bool GetRightGrip()
{
    Shared& s = S();
    std::lock_guard<std::mutex> lock(s.m);
    return s.rightGrip;
}

inline void GetLeftTrackpad(bool& touch, bool& click)
{
    Shared& s = S();
    std::lock_guard<std::mutex> lock(s.m);
    touch = (s.leftTrackpad & kLeftTrackpadTouchBit) != 0;
    click = (s.leftTrackpad & kLeftTrackpadClickBit) != 0;
}

inline bool GetButtonA()
{
    Shared& s = S();
    std::lock_guard<std::mutex> lock(s.m);
    return s.buttonA;
}

inline void SetConsoleView(double x, double y, double z)
{
    Shared& s = S();
    std::lock_guard<std::mutex> lock(s.m);
    s.viewX = x;
    s.viewY = y;
    s.viewZ = z;
}

} // namespace DevkitInput
