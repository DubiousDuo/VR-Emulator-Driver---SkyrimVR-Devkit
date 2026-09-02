#include "csamplecontrollerdriver.h"
#include "basics.h"
#include <fstream>
#include <sstream>
#include <math.h>
#include "driverlog.h"
#include "vrmath.h"

using namespace vr;

// Controller 1 orientation (Changed to quaternion to prevent gimbal lock and another annoying as bug i found)
static double c1OrientW = 1.0, c1OrientX = 0.0, c1OrientY = 0.0, c1OrientZ = 0.0;
static double cpX = 0, cpY = 0, cpZ = 0;

// Controller 2 orientation (Changed to quaternion to prevent gimbal lock and another annoying as bug i found)
static double c2OrientW = 1.0, c2OrientX = 0.0, c2OrientY = 0.0, c2OrientZ = 0.0;
static double c2pX = 0, c2pY = 0, c2pZ = 0;

static void quatMultiply(
    double aw, double ax, double ay, double az,
    double bw, double bx, double by, double bz,
    double& rw, double& rx, double& ry, double& rz)
{
    rw = aw * bw - ax * bx - ay * by - az * bz;
    rx = aw * bx + ax * bw + ay * bz - az * by;
    ry = aw * by - ax * bz + ay * bw + az * bx;
    rz = aw * bz + ax * by - ay * bx + az * bw;
}

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



    if (ControllerIndex == 1) {
        std::ifstream posFile("C:/actions/controller1_position_changes.txt");
        if (posFile.is_open()) {
            std::string line;
            std::getline(posFile, line);
            posFile.close();

            // Reset before applying so repeated RunFrame calls don't stack
            std::ofstream resetPosFile("C:/actions/controller1_position_changes.txt");
            if (resetPosFile.is_open()) {
                resetPosFile << "0 0 0";
                resetPosFile.close();
            }

            std::istringstream iss(line);
            double posChanges[3] = { 0 };
            iss >> posChanges[0] >> posChanges[1] >> posChanges[2];
            if (posChanges[0] != 0 || posChanges[1] != 0 || posChanges[2] != 0) {
                cpX += posChanges[0];
                cpY += posChanges[1];
                cpZ += posChanges[2];
            }
        }

        // Read rotation changes from file
        std::ifstream rotFile("C:/actions/controller1_rotation_changes.txt");
        if (rotFile.is_open()) {
            std::string line;
            std::getline(rotFile, line);
            rotFile.close();

            std::ofstream resetRotFile("C:/actions/controller1_rotation_changes.txt");
            if (resetRotFile.is_open()) {
                resetRotFile << "0 0 0";
                resetRotFile.close();
            }

            std::istringstream iss(line);
            double pitchDeg = 0, yawDeg = 0, rollDeg = 0;
            iss >> pitchDeg >> yawDeg >> rollDeg;

            if (pitchDeg != 0 || yawDeg != 0) {
                double halfPitch = DEG_TO_RAD(pitchDeg) * 0.5;
                double halfYaw = DEG_TO_RAD(yawDeg) * 0.5;

                // Yaw around world Y axis
                double yw = cos(halfYaw), yx = 0.0, yy = sin(halfYaw), yz = 0.0;
                // Pitch around local X axis
                double pw = cos(halfPitch), px = sin(halfPitch), py = 0.0, pz = 0.0;

                // Apply pitch locally then yaw in world space
                double tempW, tempX, tempY, tempZ;
                quatMultiply(c1OrientW, c1OrientX, c1OrientY, c1OrientZ,
                    pw, px, py, pz,
                    tempW, tempX, tempY, tempZ);
                quatMultiply(yw, yx, yy, yz,
                    tempW, tempX, tempY, tempZ,
                    c1OrientW, c1OrientX, c1OrientY, c1OrientZ);

                // Normalize to prevent floating point drift over time
                double len = sqrt(c1OrientW * c1OrientW + c1OrientX * c1OrientX + c1OrientY * c1OrientY + c1OrientZ * c1OrientZ);
                if (len > 0) { c1OrientW /= len; c1OrientX /= len; c1OrientY /= len; c1OrientZ /= len; }
            }
        }

        pose.qRotation.w = c1OrientW;
        pose.qRotation.x = c1OrientX;
        pose.qRotation.y = c1OrientY;
        pose.qRotation.z = c1OrientZ;

        pose.vecPosition[0] = cpX;
        pose.vecPosition[1] = cpY;
        pose.vecPosition[2] = cpZ;
    }
    else {
        std::string posFileName = "C:/actions/controller2_position_changes.txt";
        std::string rotFileName = "C:/actions/controller2_rotation_changes.txt";

        // Read position changes from file
        std::ifstream posFile("C:/actions/controller2_position_changes.txt");
        if (posFile.is_open()) {
            std::string line;
            std::getline(posFile, line);
            posFile.close();

            // Reset before applying so repeated RunFrame calls don't stack
            std::ofstream resetPosFile("C:/actions/controller2_position_changes.txt");
            if (resetPosFile.is_open()) {
                resetPosFile << "0 0 0";
                resetPosFile.close();
            }

            std::istringstream iss(line);
            double posChanges[3] = { 0 };
            iss >> posChanges[0] >> posChanges[1] >> posChanges[2];
            if (posChanges[0] != 0 || posChanges[1] != 0 || posChanges[2] != 0) {
                c2pX += posChanges[0];
                c2pY += posChanges[1];
                c2pZ += posChanges[2];
            }
        }

        // Read rotation changes from file
        std::ifstream rotFile("C:/actions/controller2_rotation_changes.txt");
        if (rotFile.is_open()) {
            std::string line;
            std::getline(rotFile, line);
            rotFile.close();

            std::ofstream resetRotFile("C:/actions/controller2_rotation_changes.txt");
            if (resetRotFile.is_open()) {
                resetRotFile << "0 0 0";
                resetRotFile.close();
            }

            std::istringstream iss(line);
            double pitchDeg = 0, yawDeg = 0, rollDeg = 0;
            iss >> pitchDeg >> yawDeg >> rollDeg;

            if (pitchDeg != 0 || yawDeg != 0) {
                double halfPitch = DEG_TO_RAD(pitchDeg) * 0.5;
                double halfYaw = DEG_TO_RAD(yawDeg) * 0.5;

                // Yaw around world Y axis
                double yw = cos(halfYaw), yx = 0.0, yy = sin(halfYaw), yz = 0.0;
                // Pitch around local X axis
                double pw = cos(halfPitch), px = sin(halfPitch), py = 0.0, pz = 0.0;

                // Apply pitch locally then yaw in world space
                double tempW, tempX, tempY, tempZ;
                quatMultiply(c2OrientW, c2OrientX, c2OrientY, c2OrientZ,
                    pw, px, py, pz,
                    tempW, tempX, tempY, tempZ);
                quatMultiply(yw, yx, yy, yz,
                    tempW, tempX, tempY, tempZ,
                    c2OrientW, c2OrientX, c2OrientY, c2OrientZ);

                // Normalize to prevent floating point drift over time
                double len = sqrt(c2OrientW * c2OrientW + c2OrientX * c2OrientX + c2OrientY * c2OrientY + c2OrientZ * c2OrientZ);
                if (len > 0) { c2OrientW /= len; c2OrientX /= len; c2OrientY /= len; c2OrientZ /= len; }
            }
        }

        pose.qRotation.w = c2OrientW;
        pose.qRotation.x = c2OrientX;
        pose.qRotation.y = c2OrientY;
        pose.qRotation.z = c2OrientZ;

        pose.vecPosition[0] = c2pX;
        pose.vecPosition[1] = c2pY;
        pose.vecPosition[2] = c2pZ;
    }

    return pose;
}

void CSampleControllerDriver::RunFrame()
{

    if (ControllerIndex == 1) {
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[0], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // System
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[1], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // Application Menu
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[2], (0x8000 & GetAsyncKeyState(VK_F13)) != 0, 0);  // Grip
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[3], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // D-pad Left
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[4], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // D-pad Up
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[5], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // D-pad Right
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[6], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // D-pad Down
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[7], (0x8000 & GetAsyncKeyState(VK_F14)) != 0, 0);  // A
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[8], (0x8000 & GetAsyncKeyState(VK_F15)) != 0, 0);  // B
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[9], (0x8000 & GetAsyncKeyState(VK_F16)) != 0, 0);  // X
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[10], (0x8000 & GetAsyncKeyState(VK_F17)) != 0, 0); // Y
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[11], (0x8000 & GetAsyncKeyState(VK_F18)) != 0, 0); // Trigger Click
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[12], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0); // Trigger Value
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[13], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0); // Trackpad Click
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[14], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0); // Trackpad Touch

        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[0], 0.0, 0); //Trackpad x
        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[1], 0.0, 0); //Trackpad y

        if ((GetAsyncKeyState('2') & 0x8000) != 0) {
            vr::VRDriverInput()->UpdateScalarComponent(HAnalog[0], 1.0, 0);
        }

        if ((GetAsyncKeyState('3') & 0x8000) != 0) {
            vr::VRDriverInput()->UpdateScalarComponent(HAnalog[1], 1.0, 0);
        }

        if ((GetAsyncKeyState('X') & 0x8000) != 0) { //Trigger
            vr::VRDriverInput()->UpdateScalarComponent(HAnalog[2], 1.0, 0);
        }
        else {
            vr::VRDriverInput()->UpdateScalarComponent(HAnalog[2], 0.0, 0);
        }
    }
    else {
        //Controller2
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[0], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // System
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[1], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // Application Menu
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[2], (0x8000 & GetAsyncKeyState(VK_F20)) != 0, 0);  // Grip
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[3], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // D-pad Left
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[4], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // D-pad Up
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[5], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // D-pad Right
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[6], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // D-pad Down
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[7], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // A
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[8], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // B
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[9], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0);  // X
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[10], (0x8000 & GetAsyncKeyState(VK_F24)) != 0, 0); // Y
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[11], (0x8000 & GetAsyncKeyState(VK_F19)) != 0, 0); // Trigger Click
        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[12], (0x8000 & GetAsyncKeyState(VK_F20)) != 0, 0); // Trigger Value

        bool turnLeft = (GetAsyncKeyState(VK_F21) & 0x8000) != 0;
        bool turnRight = (GetAsyncKeyState(VK_F22) & 0x8000) != 0;
        bool trackpadTouch = (GetAsyncKeyState(VK_F23) & 0x8000) != 0;

        float trackpadX = 0.0f;
        if (turnLeft) {
            trackpadX = -1.0f;
        }
        else if (turnRight) {
            trackpadX = 1.0f;
        }

        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[0], trackpadX, 0);   // Trackpad X
        vr::VRDriverInput()->UpdateScalarComponent(HAnalog[1], 0.0f, 0);        // Trackpad Y (unused, stays neutral)

        vr::VRDriverInput()->UpdateBooleanComponent(HButtons[14], trackpadTouch, 0); // Trackpad Touch

        if ((GetAsyncKeyState('4') & 0x8000) != 0) { //Trigger
            vr::VRDriverInput()->UpdateScalarComponent(HAnalog[2], 1.0, 0);
        }
        else {
            vr::VRDriverInput()->UpdateScalarComponent(HAnalog[2], 0.0, 0);
        }
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
}


