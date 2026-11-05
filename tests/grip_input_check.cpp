// Run from a VS 2022 x64 developer shell:
// cl /nologo /std:c++17 /EHsc /MT /I. tests/grip_input_check.cpp /link user32.lib
// Then run grip_input_check.exe. This check uses anonymous memory and never injects desktop input.
#include "../devkit_input.h"
#include <cassert>
#include <iostream>

int main()
{
    using namespace DevkitInput;
    Shared state;
    Keys keys;
    keys.buttonMappingValid = true;
    keys.buttonWord = kRightGripBit;
    Step(state, keys, 0.0);
    assert(state.rightGripRaw && !state.rightGrip); // A held F23 at startup is not liveness.
    keys.heartbeat = true;
    Step(state, keys, 0.1);
    assert(state.rightGrip);
    keys.buttonWord = 0;
    Step(state, keys, 0.2);
    assert(!state.rightGrip && state.rightGripEverSeen);
    keys.buttonWord = kRightGripBit;
    Step(state, keys, 0.3);
    assert(state.rightGrip);
    Step(state, keys, 0.6);
    assert(!state.rightGrip && state.rightGripRaw); // F23 expiry clears a stuck mapped hold.
    keys.heartbeat = false;
    Step(state, keys, 0.7);
    assert(state.rightGrip);
    keys.buttonMappingValid = false;
    Step(state, keys, 0.8);
    assert(!state.rightGrip && !state.rightGripRaw);
    keys.buttonMappingValid = true;
    keys.buttonWord = 1u << 2; // Left Grip must not press Right Grip at this checkpoint.
    Step(state, keys, 0.9);
    assert(!state.rightGrip);
    keys.buttonWord = kRightGripBit;
    keys.heartbeat = true;
    Step(state, keys, 1.0);
    assert(state.rightGrip); // No second freshness timer or publisher phase is required.

    double t = 1.0;
    const unsigned leftBits = kLeftTrackpadClickBit | kLeftTrackpadTouchBit;
    for (unsigned combination = 0; combination != 8; ++combination) {
        keys.buttonWord = ((combination & 1) ? kLeftTrackpadClickBit : 0)
                        | ((combination & 2) ? kLeftTrackpadTouchBit : 0)
                        | ((combination & 4) ? kRightGripBit : 0);
        keys.heartbeat = !keys.heartbeat;
        t += 0.1;
        Step(state, keys, t);
        assert(state.leftTrackpad == (keys.buttonWord & leftBits));
        assert(state.rightGrip == ((combination & 4) != 0));
    }
    assert(state.leftTrackpadEverSeen == leftBits);
    Step(state, keys, t + 0.5);
    assert(state.leftTrackpad == 0 && !state.rightGrip);
    assert(state.leftTrackpadRaw == leftBits); // Timeout releases both while retaining raw/history.
    keys.heartbeat = !keys.heartbeat;
    keys.buttonMappingValid = false;
    Step(state, keys, t + 0.6);
    assert(state.leftTrackpadRaw == 0 && state.leftTrackpad == 0 && !state.rightGrip);

    // The original right Interact sequence remains independent of shared left-hand input.
    keys.interact = true;
    Step(state, keys, t + 0.61);
    assert(state.trackpadTouch && !state.trackpadClick && state.leftTrackpad == 0);
    Step(state, keys, t + 0.63);
    assert(state.trackpadTouch && state.trackpadClick && state.leftTrackpad == 0);
    Step(state, keys, t + 0.74);
    assert(!state.trackpadTouch && !state.trackpadClick && state.leftTrackpad == 0);

    ButtonMapping reader;
    reader.handle = CreateFileMappingW(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, 0, sizeof(LONG), nullptr);
    assert(reader.handle);
    reader.view = static_cast<volatile LONG*>(MapViewOfFile(reader.handle, FILE_MAP_READ | FILE_MAP_WRITE, 0, 0, sizeof(LONG)));
    assert(reader.view);
    unsigned word = 99;
    InterlockedExchange(reader.view, static_cast<LONG>(kRightGripBit));
    assert(reader.Read(0, word) && word == kRightGripBit);
    for (unsigned bit = 28; bit != 32; ++bit) {
        InterlockedExchange(reader.view, static_cast<LONG>(kRightGripBit | (1u << bit)));
        assert(!reader.Read(0, word) && word == 0); // All four reserved bits fail released.
    }
    InterlockedExchange(reader.view, 0);
    assert(reader.Read(0, word) && word == 0);
    reader.Close();
    reader.nextOpen = 100; // Model an absent mapping without touching the production named object.
    assert(!reader.Read(1, word) && word == 0);
    std::cout << "PASS: grip/left click-touch, F23 timing, and reserved-bit rejection\n";
}
