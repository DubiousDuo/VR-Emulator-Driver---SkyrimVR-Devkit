#include "csamplecontrollerdriver.h"
#include "basics.h"
#include <fstream>
#include <math.h>
#include <cstdlib>
#include <string>
#include "driverlog.h"
#include "vrmath.h"
#include "devkit_input.h"

using namespace vr;

CSampleControllerDriver::CSampleControllerDriver()
{
    m_unObjectId = vr::k_unTrackedDeviceIndexInvalid;
    m_ulPropertyContainer = vr::k_ulInvalidPropertyContainer;
}

void CSampleControllerDriver::SetControllerIndex(int32_t CtrlIndex)
{
    ControllerIndex = CtrlIndex;
}

CSampleControllerDriver::~CSampleControllerDriver()
{
}

vr::EVRInitError CSampleControllerDriver::Activate(vr::TrackedDeviceIndex_t unObjectId)
{
    m_unObjectId = unObjectId;
    m_ulPropertyContainer = vr::VRProperties()->TrackedDeviceToPropertyContainer(m_unObjectId);

    vr::VRProperties()->SetStringProperty(m_ulPropertyContainer, vr::Prop_ControllerType_String, "vive_controller");

    vr::VRProperties()->SetStringProperty(m_ulPropertyContainer, vr::Prop_ModelNumber_String, "ViveMV");
    vr::VRProperties()->SetStringProperty(m_ulPropertyContainer, vr::Prop_ManufacturerName_String, "HTC");
    vr::VRProperties()->SetStringProperty(m_ulPropertyContainer, vr::Prop_RenderModelName_String, "vr_controller_vive_1_5");

    vr::VRProperties()->SetStringProperty(m_ulPropertyContainer, Prop_TrackingSystemName_String, "VR Controller");
    vr::VRProperties()->SetInt32Property(m_ulPropertyContainer, Prop_DeviceClass_Int32, TrackedDeviceClass_Controller);

    switch (ControllerIndex) {
    case 1:
        vr::VRProperties()->SetStringProperty(m_ulPropertyContainer, Prop_SerialNumber_String, "CTRL1Serial");
        break;
    case 2:
        vr::VRProperties()->SetStringProperty(m_ulPropertyContainer, Prop_SerialNumber_String, "CTRL2Serial");
        break;
    }

    uint64_t supportedButtons = 0xFFFFFFFFFFFFFFFFULL;
    vr::VRProperties()->SetUint64Property(m_ulPropertyContainer, vr::Prop_SupportedButtons_Uint64, supportedButtons);

    // return a constant that's not 0 (invalid) or 1 (reserved for Oculus)
    //vr::VRProperties()->SetUint64Property( m_ulPropertyContainer, Prop_CurrentUniverseId_Uint64, 2 );

    // avoid "not fullscreen" warnings from vrmonitor
    //vr::VRProperties()->SetBoolProperty( m_ulPropertyContainer, Prop_IsOnDesktop_Bool, false );

    // our sample device isn't actually tracked, so set this property to avoid having the icon blink in the status window
    //vr::VRProperties()->SetBoolProperty( m_ulPropertyContainer, Prop_NeverTracked_Bool, false );

    // even though we won't ever track we want to pretend to be the right hand so binding will work as expected

    switch (ControllerIndex) {
    case 1:
        vr::VRProperties()->SetInt32Property(m_ulPropertyContainer, Prop_ControllerRoleHint_Int32, TrackedControllerRole_LeftHand);
        break;
    case 2:
        vr::VRProperties()->SetInt32Property(m_ulPropertyContainer, Prop_ControllerRoleHint_Int32, TrackedControllerRole_RightHand);
        break;
    }

    // this file tells the UI what to show the user for binding this controller as well as what default bindings should
    // be for legacy or other apps

    // Entirely pointless for this project as SkyrimVR understands OpenVR/SteamVR. Hence why the .json file is missing from the .zip file
    vr::VRProperties()->SetStringProperty(m_ulPropertyContainer, Prop_InputProfilePath_String, "{null}/input/mycontroller_profile.json");

    //  Buttons handles
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/system/click", &HButtons[0]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/application_menu/click", &HButtons[1]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/grip/click", &HButtons[2]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/dpad_left/click", &HButtons[3]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/dpad_up/click", &HButtons[4]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/dpad_right/click", &HButtons[5]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/dpad_down/click", &HButtons[6]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/a/click", &HButtons[7]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/b/click", &HButtons[8]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/x/click", &HButtons[9]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/y/click", &HButtons[10]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/trigger/click", &HButtons[11]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/trigger/value", &HButtons[12]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/trackpad/click", &HButtons[13]);
    vr::VRDriverInput()->CreateBooleanComponent(m_ulPropertyContainer, "/input/trackpad/touch", &HButtons[14]);

    // Analog handles
    vr::VRDriverInput()->CreateScalarComponent(
        m_ulPropertyContainer, "/input/trackpad/x", &HAnalog[0],
        vr::EVRScalarType::VRScalarType_Absolute, vr::EVRScalarUnits::VRScalarUnits_NormalizedTwoSided
    );
    vr::VRDriverInput()->CreateScalarComponent(
        m_ulPropertyContainer, "/input/trackpad/y", &HAnalog[1],
        vr::EVRScalarType::VRScalarType_Absolute, vr::EVRScalarUnits::VRScalarUnits_NormalizedTwoSided
    );
    vr::VRDriverInput()->CreateScalarComponent(
        m_ulPropertyContainer, "/input/trigger/value", &HAnalog[2],
        vr::EVRScalarType::VRScalarType_Absolute, vr::EVRScalarUnits::VRScalarUnits_NormalizedOneSided
    );

    vr::VRProperties()->SetInt32Property(m_ulPropertyContainer, vr::Prop_Axis0Type_Int32, vr::k_eControllerAxis_TrackPad);

    // create our haptic component
    vr::VRDriverInput()->CreateHapticComponent(m_ulPropertyContainer, "/output/haptic", &m_compHaptic);

    return VRInitError_None;
}

void CSampleControllerDriver::Deactivate()
{
    m_unObjectId = vr::k_unTrackedDeviceIndexInvalid;
}

void CSampleControllerDriver::EnterStandby()
{
}

void* CSampleControllerDriver::GetComponent(const char* pchComponentNameAndVersion)
{
    // override this to add a component to a driver
    return NULL;
}

void CSampleControllerDriver::PowerOff()
{
}

void CSampleControllerDriver::DebugRequest(const char* pchRequest, char* pchResponseBuffer, uint32_t unResponseBufferSize)
{
    if (unResponseBufferSize >= 1) {
        pchResponseBuffer[0] = 0;
    }
}

vr::DriverPose_t CSampleControllerDriver::GetPose()
{

    vr::DriverPose_t pose = { 0 };
    pose.poseIsValid = true;
    pose.result = vr::TrackingResult_Running_OK;
    pose.deviceIsConnected = true;
    pose.qWorldFromDriverRotation = HmdQuaternion_Init(1, 0, 0, 0);
    pose.qDriverFromHeadRotation = HmdQuaternion_Init(1, 0, 0, 0);

    // The pose is computed once per frame in DevkitInput::Update() and shared by the headset and both
    // controllers (everything turns and moves together, as it did when the frontend wrote the same
    // line to every device file). This is just a read.
    const DevkitInput::Pose p = DevkitInput::Snapshot();
    pose.qRotation.w = p.ow;
    pose.qRotation.x = p.ox;
    pose.qRotation.y = p.oy;
    pose.qRotation.z = p.oz;
    pose.vecPosition[0] = p.px;
    pose.vecPosition[1] = p.py;
    pose.vecPosition[2] = p.pz;

    return pose;
}

void CSampleControllerDriver::RunFrame()
{

    DevkitInput::Update();

    if (ControllerIndex == 1) {
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[0], false, 0);  // System
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[1], false, 0);  // Application Menu
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[2], false, 0);  // Grip
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[3], false, 0);  // D-pad Left
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[4], false, 0);  // D-pad Up
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[5], false, 0);  // D-pad Right
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[6], false, 0);  // D-pad Down
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[7], false, 0);  // A
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[8], false, 0);  // B
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[9], false, 0);  // X
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[10], false, 0); // Y
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[11], false, 0); // Trigger Click
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[12], false, 0); // Trigger Value
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[13], false, 0); // Trackpad Click
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[14], false, 0); // Trackpad Touch

        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[0], 0.0, 0); //Trackpad x
        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[1], 0.0, 0); //Trackpad y

        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[2], 0.0, 0); //Trigger
    }
    else {
        //Controller2
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[0], (0x8000 & GetAsyncKeyState(VK_F13)) != 0, 0);  // System
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[1], false, 0);  // Application Menu
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[2], false, 0);  // Grip
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[3], false, 0);  // D-pad Left
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[4], false, 0);  // D-pad Up
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[5], false, 0);  // D-pad Right
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[6], false, 0);  // D-pad Down
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[7], false, 0);  // A
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[8], false, 0);  // B
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[9], false, 0);  // X
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[10], false, 0); // Y
        bool interactTouch = false, interactClick = false;
        DevkitInput::GetTrackpad(interactTouch, interactClick);
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[13], interactClick || (0x8000 & GetAsyncKeyState(VK_F14)) != 0, 0); // Trackpad Click
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[14], interactTouch || (0x8000 & GetAsyncKeyState(VK_F15)) != 0, 0); // Trackpad Touch

        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[0], 0.0, 0); //Trackpad x
        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[1], 0.0, 0); //Trackpad y

        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[2], 0.0, 0); //Trigger
    }

    if (m_unObjectId != vr::k_unTrackedDeviceIndexInvalid) {
        vr::VRServerDriverHost()->TrackedDevicePoseUpdated(m_unObjectId, GetPose(), sizeof(DriverPose_t));
    }

}
void CSampleControllerDriver::ProcessEvent(const vr::VREvent_t& vrEvent)
{
    switch (vrEvent.eventType) {
    case vr::VREvent_Input_HapticVibration:
        if (vrEvent.data.hapticVibration.componentHandle == m_compHaptic) {
            // This is where you would send a signal to your hardware to trigger actual haptic feedback
            //DriverLog( "BUZZ!\n" );
        }
        break;
    }
}

std::string CSampleControllerDriver::GetSerialNumber() const
{
    switch (ControllerIndex) {
    case 1:
        return "CTRL1Serial";
        break;
    case 2:
        return "CTRL2Serial";
        break;
    }
    return ""; // any other controller index (never used) - avoids falling off the end of the function
}


