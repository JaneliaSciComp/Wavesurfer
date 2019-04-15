/**
* @file MulticlampTelegraph.cpp
*
* @brief State storage and message processing for Axon MutliClamp 700A/700B amplifiers.
*
* A formal window is spawned, to recieve responsese from the MutltiClamp Commander program, which is where the
* information originates. Connection is initiated by this code, via a broadcast message. Responses will then come
* either as broadcast messages or as messages targeted directly at this window. The window is not visible or
* accessible to the user in any way. It is intended solely for message processing, but it is not a message-class
* window, as message windows do not recieve broadcast messages. The message processing requires a thread to
* poll for new messages.
*
* A continually growing global array of states is maintained, with one state structure for each electrode. In
* practice, this array will rarely grow beyond two entries. Old states are maintained even if an electrode is off, so
* the states may be stale. We can't know if an electrode goes off line anyway. This means that the user level code needs 
* to understand that queries may produce stale data. This is okay, since the previous user code (\@multi_clamp) expected
* potentially stale data in the text file that was used for communication. Note that the global array is cleared if 
* the mex file is cleared, as per good Matlab programming practice.
*
* While this is a 'cpp' file, because the Microsoft compiler chokes on an unadulterated MultiClampBroadcastMsg.hpp,
* the code within here should be pure ANSI C (C99).
*
* @see http://msdn.microsoft.com/en-us/library/ms632596(VS.85).aspx
* @see \htmlonly <a href="../../../resources/MCTG_Spec.pdf">MCTG_Spec.pdf</a> \endhtmlonly
*
* @author Timothy O'Connor
* @date 10/26/08
*
* <em><b>Copyright</b> - Cold Spring Harbor Laboratories/Howard Hughes Medical Institute 2008</em>
*
*/

/* Later modifications were made by Adam L. Taylor, and are copyright 2015 by the Howard Hughes Medical Institute */


#ifdef MCT_DEBUG
#pragma message("   *****   Compiling in debug mode.   *****")
#endif

/*********************************
*         OS DEFINES            *
*********************************/
/**
* @brief This is required to use functions such as SwitchToThread.
*
* This declares that the minumum system used must be NT4.0.
*
* @see http://msdn.microsoft.com/en-us/library/ms686352.aspx
*/
#define _WIN32_WINNT 0x0400

/*********************************
*     APPLICATION DEFINES       *
*********************************/
///@brief The version number. This should be incremented when this file is changed.
#define MCT_VERSION "0.3"
///@brief This string is used in place of fields not supported by the 700A.
#define UNSPECIFIED_FOR_700A "UNSPECIFIED"
///@brief This string is used as the class name for the messaging window.
#define MCT_WINDOWCLASS_NAME "MCT_windowClass"

/*********************************
*           INCLUDES            *
*********************************/

#include "windows.h"
#ifdef MATLAB_MEX_FILE
#include <mex.h>
#else
#include "stdio.h"
#endif
//#include <MultiClampBroadcastMsg.hpp>
#include "MultiClampBroadcastMsg.hpp"
  // Switched to a copy of MultiClampBroadcastMsg.hpp distributed with Multiclamp 700B Commander 2.1.0.16 copied
  // into the same folder as this source file.

/*********************************
*      MACRO DEFINITIONS        *
*********************************/
#ifndef MCT_DEBUG
///@brief Use printf semantics to display a debug message, if MCT_DEBUG is defined at compile-time.
#define MCT_debugMsg(...)
#endif

#ifdef MATLAB_MEX_FILE
///@brief Use printf semantics to display a message to the console.
#define MCT_printMsg(...)            mexPrintf(__VA_ARGS__)
///@brief Use printf/mexPrintf semantics to display an error message to the console.
#define MCT_errorMsg(...)    mexPrintf("MCT_ERROR: " __VA_ARGS__)
//It would be nice to use mexErrMsgTxt, but that may cause problems when called from the 
//message processing thread, because it attempts to terminate the mex file.
//#define MCT_errorMsg(...)    mexErrMsgTxt("MCT_ERROR: " __VA_ARGS__)
#ifdef MCT_DEBUG
///@brief Use printf/mexPrintf  semantics to display a debug message, if MCT_DEBUG is defined at compile-time.
#define MCT_debugMsg(...) mexPrintf("MCT_DEBUG: " __VA_ARGS__)
#endif
#else
///@brief Use printf/mexPrintf  semantics to display a message to the console.
#define MCT_printMsg(...)    printf(__VA_ARGS__)
///@brief Use printf semantics to display an error message to the console.
#define MCT_errorMsg(...)    printf("MCT_ERROR: " __VA_ARGS__)
#ifdef MCT_DEBUG
///@brief Use printf semantics to display a debug message, if MCT_DEBUG is defined at compile-time.
#define MCT_debugMsg(...) printf("MCT_DEBUG: " __VA_ARGS__)
#endif
#endif

/*********************************
*       TYPE DEFINITIONS        *
*********************************/

/**
* @brief A representation of an electrode state.
*
* Each callback is identified by a unique ID, which also serves as its address for communcation purposes.
*/
static const size_t MAXIMUM_VERSION_STRING_LENGTH=15;   // The max length of version strings, the buffer for a version string has to be one longer
typedef struct MCT_electrodeStateSlotStruct
{
    BOOL isFresh;  // Whether there's really an electrode here.  If false, this is an empty slot.
    ///Unique identifier for, and address of, this electrode.
    LPARAM ID;
    /**
    * @brief Operating mode of the electrode.
    *
    * The available modes are -\n
    *  @indent V-Clamp\n
    *  @indent I-Clamp\n
    *  @indent I = 0\n
    *
    * The unsigned integer is interpreted as an offset into the MCTG_MODE_NAMES array of strings.
    *
    * @see MCTG_MODE_NAMES
    */
    unsigned int uOperatingMode;
    /**
    * @brief Signal identifier of scaled (primary) output.
    *
    * 700A Values:\n
    *   @indent Membrane Potential / Command Current\n
    *   @indent Membrane Current\n
    *   @indent Pipette Potential / Membrane Potential\n
    *   @indent x100 AC Pipette / Membrane Potential\n
    *   @indent Bath Current\n
    *   @indent Bath Potential\n
    * 700B Values:\n
    *   @indent Membrane Current\n
    *   @indent Membrane Potential\n
    *   @indent Pipette Potential\n
    *   @indent 100x AC Membrane Potential\n
    *   @indent Command Current\n
    *   @indent External Command Potential / External Command Current\n
    *   @indent Auxiliary 1\n
    *   @indent Auxiliary 2\n
    */
    unsigned int uScaledOutSignal;
    ///@brief Gain of scaled (primary) output.
    double dAlpha;
    ///@brief Scale factor of scaled (primary) output.
    double dScaleFactor;
    /**
    * @brief Scale factor units of scaled (primary) output.
    *
    *  Values:\n
    *    @indent V/V  - MCTG_UNITS_VOLTS_PER_VOLT\n
    *    @indent V/mV - MCTG_UNITS_VOLTS_PER_MILLIVOLT\n
    *    @indent V/uV - MCTG_UNITS_VOLTS_PER_MICROVOLT\n
    *    @indent V/A  - MCTG_UNITS_VOLTS_PER_AMP\n
    *    @indent V/mA - MCTG_UNITS_VOLTS_PER_MILLIAMP\n
    *    @indent V/uA - MCTG_UNITS_VOLTS_PER_MICROAMP\n
    *    @indent V/nA - MCTG_UNITS_VOLTS_PER_NANOAMP\n
    *    @indent V/pA - MCTG_UNITS_VOLTS_PER_PICOAMP\n
    *    @indent None - MCTG_UNITS_NONE\n
    */
    unsigned int uScaleFactorUnits;
    ///@brief Lowpass filter cutoff frequency [Hz] of scaled (primary) output.
    double dLPFCutoff;
    ///@brief Membrane capacitance [F].
    double dMembraneCap;
    /**
    * @brief External command sensitivity.
    *
    *  Values:\n
    *    @indent V/V (V-Clamp)\n
    *    @indent A/V (I-Clamp)\n
    *    @indent 0.0 A/V, OFF (I=0)\n
    */
    double dExtCmdSens;
    /**
    * @brief Signal identifier of raw (secondary) output.
    *
    * 700A Values:\n
    *   @indent Membrane plus Offset Potential / Command Current\n
    *   @indent Membrane Current\n
    *   @indent Pipette Potential / Membrane plus Offset Potential\n
    *   @indent x100 AC Pipette / Membrane Potential\n
    *   @indent Bath Current\n
    *   @indent Bath Potential\n
    * 700B Values:\n
    *   @indent Membrane Current\n
    *   @indent Membrane Potential\n
    *   @indent Pipette Potential\n
    *   @indent 100x AC Membrane Potential\n
    *   @indent External Command Potential / External Command Current\n
    *   @indent Auxiliary 1\n
    *   @indent Auxiliary 2\n
    */
    unsigned int uRawOutSignal;
    ///@brief Scale factor of raw (secondary) output.
    double dRawScaleFactor;
    /**
    * @brief Scale factor units of raw (secondary) output.
    *
    *  Values:\n
    *    @indent V/V  - MCTG_UNITS_VOLTS_PER_VOLT\n
    *    @indent V/mV - MCTG_UNITS_VOLTS_PER_MILLIVOLT\n
    *    @indent V/uV - MCTG_UNITS_VOLTS_PER_MICROVOLT\n
    *    @indent V/A  - MCTG_UNITS_VOLTS_PER_AMP\n
    *    @indent V/mA - MCTG_UNITS_VOLTS_PER_MILLIAMP\n
    *    @indent V/uA - MCTG_UNITS_VOLTS_PER_MICROAMP\n
    *    @indent V/nA - MCTG_UNITS_VOLTS_PER_NANOAMP\n
    *    @indent V/pA - MCTG_UNITS_VOLTS_PER_PICOAMP\n
    *    @indent None - MCTG_UNITS_NONE\n
    */
    unsigned int uRawScaleFactorUnits;
    /**
    * @brief Hardware type identifier.
    *
    * Values:\n
    *  @indent MCTG_HW_TYPE_MC700A\n
    *  @indent MCTG_HW_TYPE_MC700B\n
    */
    unsigned int uHardwareType;
    ///@brief Gain of raw (secondary) output.
    double dSecondaryAlpha;
    ///@brief Lowpass filter cutoff frequency [Hz] of raw (secondary) output.
    double dSecondaryLPFCutoff;
    ///@brief Application version of Multiclamp Commander 2.x.
    char szAppVersion[MAXIMUM_VERSION_STRING_LENGTH+1];
    ///@brief Firmware version of Multiclamp 700B.
    char szFirmwareVersion[MAXIMUM_VERSION_STRING_LENGTH+1];
    ///@brief DSP version of Multiclamp 700B.
    char szDSPVersion[MAXIMUM_VERSION_STRING_LENGTH+1];
    ///@brief Serial number of Multiclamp 700B.
    char szSerialNumber[MAXIMUM_VERSION_STRING_LENGTH+1];
    ///@brief The last time this structure has been updated, in system ticks.
    LARGE_INTEGER refreshTickCount;
} MCT_electrodeStateSlot;

static const char* MCT_SCALE_UNITS[] = {"V/V", "V/mV", "V/uV", "V/A", "V/mA", "V/uA", "V/nA", "V/pA", "None"};

/*********************************
*       GLOBAL VARIABLES        *
*********************************/

///@brief Flag to indicate if initialization has been performed.
bool MCT_isRunning = false;  // This is only touched on the main thread
// Stronger than MCT_isMessageThreadRunning below.  MCT_isRunning=>MCT_isMessageThreadRunning, but not vice-versa.
// This means that the critical section has been initialized, and the message thread has been launched.
// When stopping, MCT_isMessageThreadRunning should generally go false a bit before MCT_isRunning, while
// the critical section is released, etc.
// However, note that if the message-processing thread fails to launch, this can be true when MCT_isMessageThreadRunning
// is false.

///@brief Boolean flag that is true when the message processing thread is running.
BOOL MCT_isMessageThreadRunning = FALSE;  // This is only be touched on the message-processing thread

///@brief Handle to the window used to recieve messages.
HWND MCT_hwnd = NULL;

///@brief The class used when creating the message processing client window.
WNDCLASSEX MCT_wndClass;

//@brief Handle to the thread used to process window messages.
HANDLE MCT_messageProcessingThread = NULL;

///@brief Boolean flag that is true when an outstanding request to shut down the message processing thread exists.
BOOL MCT_doStopMessageProcessingThread = FALSE;

/**
* @brief The Windows thread ID for the message processing thread.
* This is not strictly necessary, and is only kept for good bookkeeping.
*/
DWORD MCT_messageProcessingThreadID = 0;

///@brief Only one thread may be accessing the global state array at one time, this is used to synchronize access across threads.
CRITICAL_SECTION MCT_criticalSection; 
CRITICAL_SECTION* MCT_criticalSectionPtr = NULL;  // Invariant:  MCT_criticalSectionPtr is null iff MCT_criticalSection is not initialized

/**
* @brief The inverse of the system ticks per second.
*
* This is not <tt>performanceFrequency</tt>, which might seem more
* natural, because such a variable would then be used as the denominator
* to convert ticks into seconds. Since multiplication is faster than division
* we cache the division up front.
*/
double MCT_performancePeriod;

///@brief The ID of the MCTG Open message.
DWORD MCT_MCTGOpenMessage;
///@brief The ID of the MCTG Close message.
DWORD MCT_MCTGCloseMessage;
///@brief The ID of the MCTG Request message.
DWORD MCT_MCTGRequestMessage;
///@brief The ID of the MCTG Reconnect message.
DWORD MCT_MCTGReconnectMessage;
///@brief The ID of the MCTG Broadcast message.
DWORD MCT_MCTGBroadcastMessage;
///@brief The ID of the MCTG ID message.
DWORD MCT_MCTGIDMessage;
///@brief The ID of the MCT Shutdown message.
DWORD MCT_STOP;

///@brief An array of MCT_electrodeStateSlot objects, one for each electrode.
//MCT_electrodeStateSlot** MCT_electrodeStatePointers;
///@brief The length of the <tt>MCT_electrodeStatePointers</tt> array.
//int MCT_nElectrodeStatePointers;

const size_t MCT_N_ELECTRODE_STATES = 16;
///@brief An array of MCT_electrodeStateSlot objects, one for each potential electrode.
MCT_electrodeStateSlot MCT_electrodeStateSlots[MCT_N_ELECTRODE_STATES];

// After a broadcast, the "I'm here!" messages are tallied in these two globals
const size_t MAX_N_FRESH_KNOWN_ELECTRODE_IDS = 16 ;
size_t MCT_N_FRESH_KNOWN_ELECTRODE_IDS = 0 ;
LPARAM MCT_freshKnownElectrodeIDs[MAX_N_FRESH_KNOWN_ELECTRODE_IDS] ;


/*********************************
*      UTILITY FUNCTIONS        *
*********************************/

void MCT_copyVersionString(char * destination, const char* source)  // This is called on message processing thread, but not on the main thread
{
    size_t sourceLength;
    size_t nCharactersToCopy;
    size_t i;

    sourceLength = strlen(source);
    nCharactersToCopy=max(sourceLength,MAXIMUM_VERSION_STRING_LENGTH);
    for (i=0; i<nCharactersToCopy; ++i)
    {    
        destination[i]=source[i];
    }
    destination[i]='\0';
}


/**
* @brief Converts "ticks" into current age in seconds.
*
* This function is declared as inline because it is quite small and trivial... and built for speed, baby, yeah!
* Of course, this will be called relatively infrequently, so speed really doesn't matter, I'm just keeping myself amused.
* @arg <tt>ticks</tt> - The number of system ticks, as retrieved via Windows' QueryPerformanceCounter function.
* @return The number of seconds that corresponds to <tt>ticks</tt>.
* @see QueryPerformanceCounter
* @see performancePeriod
*/
inline double MCT_ticksToSeconds(LARGE_INTEGER ticks)
{
    LARGE_INTEGER currentTicks;

    QueryPerformanceCounter(&currentTicks);

    MCT_debugMsg("Computing seconds:\n\tcurrentTicks = %lld\n\tticks = %lld\n\tseconds per tick = %3.4f\n\telapsed time = %3.5f [s]\n",
        currentTicks.QuadPart, ticks.QuadPart, MCT_performancePeriod, (double)(currentTicks.QuadPart - ticks.QuadPart) * MCT_performancePeriod);

    return (currentTicks.QuadPart - ticks.QuadPart) * MCT_performancePeriod;
}

/**
* @brief Prints the Windows error message corresponding to <tt>GetLastError()</tt>.
* @see http://msdn.microsoft.com/en-us/library/ms679351(VS.85).aspx
*/
void printWindowsErrorMessage(void)  // This is called on message processing thread
{
    DWORD lastError;
    LPTSTR errorMsg = NULL;

    lastError = GetLastError();
    //FormatMessage(dwFlags, lpSource, dwMessageId, dwLanguageId, lpBuffer, nSize, Arguments)
    if (!FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS, NULL, lastError, NULL, (LPTSTR)&errorMsg, 1024, NULL))
    {
        MCT_printMsg("printWindowsErrorMessage() - Failed to format message for error: %d\n"
            "                             FormatMessage Error: %d\n", lastError, GetLastError());
        return;
    }

    MCT_errorMsg("Windows Error: %d\n"
        "                          %s\n", lastError, errorMsg);
    LocalFree(errorMsg);

    return;
}


/*********************************
*       MCT_electrodeStateSlot METHODS       *
*********************************/


/**
* @brief Return a value representing the uScaleFactorUnits as a string
*
* @arg <tt>uScaleFactorUnits</tt> - The uScaleFactorUnits that is to be converted into a string.
* @arg <tt>uHardwareType</tt> - The uHardwareType of the corresponding amplifier.
* @arg <tt>uOperatingMode</tt> - The uOperatingMode of the corresponding electrode.
* @return The resulting string.
*/
const char* MCT_scaleFactorUnitsToString(UINT uScaleFactorUnits, UINT uHardwareType, UINT uOperatingMode, UINT uScaledOutSignal)
{
    if (uHardwareType == MCTG_HW_TYPE_MC700A)
    {
        /*
        * The following values had to be empirically determined, because the values supplied in
        * MultiClampBroadcastMsg.hpp do not, in any way, correspond to the actual signal
        * being sent to the Scaled Output BNC.
        * Here's what they suggest:
        *     const UINT MCTG_OUT_MUX_I_CMD_SUMMED    = 0;
        *     const UINT MCTG_OUT_MUX_V_CMD_SUMMED    = 1;
        *     const UINT MCTG_OUT_MUX_I_CMD_EXT       = 2;
        *     const UINT MCTG_OUT_MUX_V_CMD_EXT       = 3;
        *     const UINT MCTG_OUT_MUX_I_MEMBRANE      = 4;
        *     const UINT MCTG_OUT_MUX_V_MEMBRANE      = 5;
        *     const UINT MCTG_OUT_MUX_V_MEMBRANEx100  = 6;
        *     const UINT MCTG_OUT_MUX_I_AUX1          = 7;
        *     const UINT MCTG_OUT_MUX_V_AUX1          = 8;
        *     const UINT MCTG_OUT_MUX_I_AUX2          = 9;
        *     const UINT MCTG_OUT_MUX_V_AUX2          = 10;
        * Here are the actual values:
        *  Voltage Clamp -
        *     0 = Membrane Potential [10 V/V]            ? MCTG_OUT_MUX_I_CMD_SUMMED
        *     1 = Membrane Current [0.5 V/nA]            ? MCTG_OUT_MUX_V_CMD_SUMMED
        *     2 = Pipette Potential [1 V/V]              ? MCTG_OUT_MUX_I_CMD_EXT
        *     3 = 100 x AC Pipette Potential [0.1 V/mV]  ? MCTG_OUT_MUX_V_CMD_EXT
        *     5 = Bath Potential [N/A]                   ? MCTG_OUT_MUX_V_MEMBRANE
        *  Current Clamp -
        *     0 = Command Current [0.5 V/nA]             ? MCTG_OUT_MUX_I_CMD_SUMMED
        *     1 = Membrane Current [0.5 V/nA]            ? MCTG_OUT_MUX_V_CMD_SUMMED
        *     2 = Membrane Potential [1 V/V]             ? MCTG_OUT_MUX_I_CMD_EXT
        *     3 = 100 x AC Membrane Potential [0.1 V/mV] ? MCTG_OUT_MUX_V_CMD_EXT
        *     5 = Bath Potential [N/A]                   ? MCTG_OUT_MUX_V_MEMBRANE
        */
        if (uOperatingMode == MCTG_MODE_VCLAMP)
        {
            switch (uScaledOutSignal)
            {
            case 0:
                return "V/V";//Membrane Potential [10 V/V]
            case 1:
                if (uScaleFactorUnits==5)
                    return "V/uA";
                else
                    return "V/nA";  //Membrane Current [0.5 V/nA]
            case 2:
                return "V/V";//Pipette Potential [1 V/V]
            case 3:
                return "V/mV";//100 x AC Pipette Potential [0.1 V/mV]
            case 5:
                return "";//Bath Potential [N/A]
            default:
                return "ERROR - Unknown uScaledOutSignal value";//???
            }
        }
        else if ((uOperatingMode == MCTG_MODE_ICLAMP) || (uOperatingMode == MCTG_MODE_ICLAMPZERO))
        {
            switch (uScaledOutSignal)
            {
            case 0:
                return "V/nA";//Command Current [0.5 V/nA]
            case 1:
                return "V/nA";//Membrane Current [0.5 V/nA]
            case 2:
                return "V/V";//Membrane Potential [1 V/V]
            case 3:
                return "V/mV";//100 x AC Membrane Potential [0.1 V/mV]
            case 5:
                return "";//Bath Potential [N/A]
            default:
                return "ERROR - Unknown uScaledOutSignal value";//???
            }
        }
    }
    else if (uHardwareType == MCTG_HW_TYPE_MC700B)
        return MCT_SCALE_UNITS[uScaleFactorUnits];
    else
        return "UNKNOWN_SCALE_UNITS";

    return "This code is unreachable, dumb compiler.";
}

/**
* @brief Return a value representing the uScaleFactorUnits as a string
*
* @arg <tt>state</tt> - The state whose uScaleFactorUnits is to be converted into a string.
* @return The resulting string.
*/
const char* MCT_getScaleFactorUnitsString(MCT_electrodeStateSlot* state)
{
    return MCT_scaleFactorUnitsToString(state->uScaleFactorUnits, state->uHardwareType, state->uOperatingMode, state->uScaledOutSignal);
}

/**
* @brief Return a value representing the uScaledOutSignal as a long string
*
* @arg <tt>uScaledOutSignal</tt> - The uScaledOutSignal that is to be converted into a string.
* @arg <tt>uHardwareType</tt> - The uHardwareType of the corresponding amplifier.
* @arg <tt>uOperatingMode</tt> - The uOperatingMode of the corresponding electrode.
* @return The resulting string.
*/
const char* MCT_scaledOutSignalToLongName(UINT uScaledOutSignal, UINT uHardwareType, UINT uOperatingMode)  // this is called on message processing thread
{
    if (uHardwareType == MCTG_HW_TYPE_MC700A)
    {
        /*
        * The following values had to be empirically determined, because the values supplied in
        * MultiClampBroadcastMsg.hpp do not, in any way, correspond to the actual signal
        * being sent to the Scaled Output BNC.
        * Here's what they suggest:
        *     const UINT MCTG_OUT_MUX_I_CMD_SUMMED    = 0;
        *     const UINT MCTG_OUT_MUX_V_CMD_SUMMED    = 1;
        *     const UINT MCTG_OUT_MUX_I_CMD_EXT       = 2;
        *     const UINT MCTG_OUT_MUX_V_CMD_EXT       = 3;
        *     const UINT MCTG_OUT_MUX_I_MEMBRANE      = 4;
        *     const UINT MCTG_OUT_MUX_V_MEMBRANE      = 5;
        *     const UINT MCTG_OUT_MUX_V_MEMBRANEx100  = 6;
        *     const UINT MCTG_OUT_MUX_I_AUX1          = 7;
        *     const UINT MCTG_OUT_MUX_V_AUX1          = 8;
        *     const UINT MCTG_OUT_MUX_I_AUX2          = 9;
        *     const UINT MCTG_OUT_MUX_V_AUX2          = 10;
        * Here are the actual values:
        *  Voltage Clamp -
        *     0 = Membrane Potential [10 V/V]            ? MCTG_OUT_MUX_I_CMD_SUMMED
        *     1 = Membrane Current [0.5 V/nA]            ? MCTG_OUT_MUX_V_CMD_SUMMED
        *     2 = Pipette Potential [1 V/V]              ? MCTG_OUT_MUX_I_CMD_EXT
        *     3 = 100 x AC Pipette Potential [0.1 V/mV]  ? MCTG_OUT_MUX_V_CMD_EXT
        *     5 = Bath Potential [N/A]                   ? MCTG_OUT_MUX_V_MEMBRANE
        *  Current Clamp -
        *     0 = Command Current [0.5 V/nA]             ? MCTG_OUT_MUX_I_CMD_SUMMED
        *     1 = Membrane Current [0.5 V/nA]            ? MCTG_OUT_MUX_V_CMD_SUMMED
        *     2 = Membrane Potential [1 V/V]             ? MCTG_OUT_MUX_I_CMD_EXT
        *     3 = 100 x AC Membrane Potential [0.1 V/mV] ? MCTG_OUT_MUX_V_CMD_EXT
        *     5 = Bath Potential [N/A]                   ? MCTG_OUT_MUX_V_MEMBRANE
        */
        if (uOperatingMode == MCTG_MODE_VCLAMP)
        {
            switch (uScaledOutSignal)
            {
            case 0:
                return "Membrane Potential";//Membrane Potential [10 V/V]
            case 1:
                return "Membrane Current";//Membrane Current [0.5 V/nA]
            case 2:
                return "Pipette Potential";//Pipette Potential [1 V/V] 
            case 3:
                return "100 x AC Pipette Potential";//100 x AC Pipette Potential [0.1 V/mV]
            case 5:
                return "Bath Potential";//Bath Potential [N/A]
            default:
                return "ERROR - Unknown uScaledOutSignal value";//???
            }
        }
        else if ((uOperatingMode == MCTG_MODE_ICLAMP) || (uOperatingMode == MCTG_MODE_ICLAMPZERO))
        {
            switch (uScaledOutSignal)
            {
            case 0:
                return "Command Current";//Command Current [0.5 V/nA]
            case 1:
                return "Membrane Current";//Membrane Current [0.5 V/nA]
            case 2:
                return "Membrane Potential";//Membrane Potential [1 V/V] 
            case 3:
                return "100 x AC Membrane Potential";//100 x AC Membrane Potential [0.1 V/mV]
            case 5:
                return "Bath Potential";//Bath Potential [N/A]
            default:
                return "ERROR - Unknown uScaledOutSignal value";//???
            }
        }
    }
    else if (uHardwareType == MCTG_HW_TYPE_MC700B)
        return MCTG_OUT_GLDR_LONG_NAMES[uScaledOutSignal];
    else
        return "ERROR - Unknown uHardwareType value";//???

    return "How did we ever get to this line of code?";
}

/**
* @brief Return a value representing the uScaledOutSignal as a short string
*
* @arg <tt>uScaledOutSignal</tt> - The uScaledOutSignal that is to be converted into a string.
* @arg <tt>uHardwareType</tt> - The uHardwareType of the corresponding amplifier.
* @arg <tt>uOperatingMode</tt> - The uOperatingMode of the corresponding electrode.
* @return The resulting string.
*/
const char* MCT_scaledOutSignalToShortName(UINT uScaledOutSignal, UINT uHardwareType, UINT uOperatingMode)
{
    if (uHardwareType == MCTG_HW_TYPE_MC700A)
    {
        /*
        * The following values had to be empirically determined, because the values supplied in
        * MultiClampBroadcastMsg.hpp do not, in any way, correspond to the actual signal
        * being sent to the Scaled Output BNC.
        * Here's what they suggest:
        *     const UINT MCTG_OUT_MUX_I_CMD_SUMMED    = 0;
        *     const UINT MCTG_OUT_MUX_V_CMD_SUMMED    = 1;
        *     const UINT MCTG_OUT_MUX_I_CMD_EXT       = 2;
        *     const UINT MCTG_OUT_MUX_V_CMD_EXT       = 3;
        *     const UINT MCTG_OUT_MUX_I_MEMBRANE      = 4;
        *     const UINT MCTG_OUT_MUX_V_MEMBRANE      = 5;
        *     const UINT MCTG_OUT_MUX_V_MEMBRANEx100  = 6;
        *     const UINT MCTG_OUT_MUX_I_AUX1          = 7;
        *     const UINT MCTG_OUT_MUX_V_AUX1          = 8;
        *     const UINT MCTG_OUT_MUX_I_AUX2          = 9;
        *     const UINT MCTG_OUT_MUX_V_AUX2          = 10;
        * Here are the actual values:
        *  Voltage Clamp -
        *     0 = Membrane Potential [10 V/V]            ? MCTG_OUT_MUX_I_CMD_SUMMED
        *     1 = Membrane Current [0.5 V/nA]            ? MCTG_OUT_MUX_V_CMD_SUMMED
        *     2 = Pipette Potential [1 V/V]              ? MCTG_OUT_MUX_I_CMD_EXT
        *     3 = 100 x AC Pipette Potential [0.1 V/mV]  ? MCTG_OUT_MUX_V_CMD_EXT
        *     5 = Bath Potential [N/A]                   ? MCTG_OUT_MUX_V_MEMBRANE
        *  Current Clamp -
        *     0 = Command Current [0.5 V/nA]             ? MCTG_OUT_MUX_I_CMD_SUMMED
        *     1 = Membrane Current [0.5 V/nA]            ? MCTG_OUT_MUX_V_CMD_SUMMED
        *     2 = Membrane Potential [1 V/V]             ? MCTG_OUT_MUX_I_CMD_EXT
        *     3 = 100 x AC Membrane Potential [0.1 V/mV] ? MCTG_OUT_MUX_V_CMD_EXT
        *     5 = Bath Potential [N/A]                   ? MCTG_OUT_MUX_V_MEMBRANE
        */
        if (uOperatingMode == MCTG_MODE_VCLAMP)
        {
            switch (uScaledOutSignal)
            {
            case 0:
                return "Vm";//Membrane Potential [10 V/V]
            case 1:
                return "Im";//Membrane Current [0.5 V/nA]
            case 2:
                return "Vp";//Pipette Potential [1 V/V]
            case 3:
                return "100Vp";//100 x AC Pipette Potential [0.1 V/mV]
            case 5:
                return "Vb";//Bath Potential [N/A]
            default:
                return "ERROR - Unknown uScaledOutSignal value";//???
            }
        }
        else if ((uOperatingMode == MCTG_MODE_ICLAMP) || (uOperatingMode == MCTG_MODE_ICLAMPZERO))
        {
            switch (uScaledOutSignal)
            {
            case 0:
                return "Vext";//Command Current [0.5 V/nA]
            case 1:
                return "Im";//Membrane Current [0.5 V/nA]
            case 2:
                return "Vm";//Membrane Potential [1 V/V]
            case 3:
                return "100Vm";//100 x AC Membrane Potential [0.1 V/mV]
            case 5:
                return "Vb";//Bath Potential [N/A]
            default:
                return "ERROR - Unknown uScaledOutSignal value";//???
            }
        }
    }
    else if (uHardwareType == MCTG_HW_TYPE_MC700B)
        return MCTG_OUT_GLDR_SHORT_NAMES[uScaledOutSignal];
    else
        return "ERROR - Unknown uHardwareType value";//???

    return "How did we ever get to this line of code?";
}

/**
* @brief Return a value representing the uScaledOutSignal as a long string
*        Calls through to MCT_scaledOutSignalToLongName.
*
* @arg <tt>state</tt> - The state whose uScaledOutSignal is to be converted into a string.
* @return The resulting string.
*/
const char* MCT_getScaledOutSignalLongName(MCT_electrodeStateSlot* state)
{
    return MCT_scaledOutSignalToLongName(state->uScaledOutSignal, state->uHardwareType, state->uOperatingMode);
}

/**
* @brief Return a value representing the uScaledOutSignal as a short string
*        Calls through to MCT_scaledOutSignalToShortName.
*
* @arg <tt>state</tt> - The state whose uScaledOutSignal is to be converted into a string.
* @return The resulting string.
*/
const char* MCT_getScaledOutSignalShortName(MCT_electrodeStateSlot* state)
{
    return MCT_scaledOutSignalToShortName(state->uScaledOutSignal, state->uHardwareType, state->uOperatingMode);
}

/**
* @brief Render the MCT_electrodeStateSlot struct as a string.
* @arg <tt>state</tt> - The state to be converted into a string.
* @arg <tt>str</tt> - The character array in which to render the string.
*/
int MCT_stateToString(MCT_electrodeStateSlot* state, char* str, size_t strSize)
{
    unsigned int uComPortID, uAxoBusID, uChannelID, uSerialNum;
    MCT_debugMsg("MCT_stateToString(@%p)\n", state);

    if ( !(state->isFresh) )
        return sprintf_s(str, strSize, "MCT_electrodeStateSlot: EMPTY\n");

    if (state->uHardwareType == MCTG_HW_TYPE_MC700A)
    {
        MCTG_Unpack700ASignalIDs(state->ID, &uComPortID, &uAxoBusID, &uChannelID);
        uSerialNum = 0;
    }
    else if (state->uHardwareType == MCTG_HW_TYPE_MC700B)
    {
        MCTG_Unpack700BSignalIDs(state->ID, &uSerialNum, &uChannelID);
        uComPortID = 0;
        uAxoBusID = 0;
    }

    return sprintf_s(str, strSize,
        "MCT_electrodeStateSlot:\n"
        "\tID:                     0x%p (%u)\n"
        "\tOperating Mode:         %s\n"
        "\tScaled Out Signal:      %s (%s)\n"
        "\tAlpha:                  %3.4f\n"
        "\tScaleFactor:            %3.4f\n"
        "\tScaleFactorUnits:       %s\n"
        "\tLPF Cutoff:             %3.4f\n"
        "\tMembrane Capacitance:   %3.4f\n"
        "\tExt Cmd Sense:          %3.4f\n"
        "\tRaw Out Signal:         %s (%s)\n"
        "\tRaw Scale Factor:       %3.4f\n"
        "\tRaw Scale Factor Units: %s\n"
        "\tHardware Type:          %s\n"
        "\tSecondary Alpha:        %3.4f\n"
        "\tSecondary LPF Cutoff:   %3.4f\n"
        "\tApp Version:            %s\n"
        "\tFirmware Version:       %s\n"
        "\tDSPVersion:             %s\n"
        "\tSerial Number:          %s\n"
        "\tuComPortID:             %u\n"
        "\tuAxoBusID:              %u\n"
        "\tuChannelID:             %u\n"
        "\tuSerialNum:             %u\n"
        "\trefreshTickCount:       %llu (Elapsed time = %3.4f [s])\n",
        state->ID, state->ID,
        MCTG_MODE_NAMES[state->uOperatingMode],
        MCT_getScaledOutSignalLongName(state),
        MCT_getScaledOutSignalShortName(state),
        state->dAlpha,
        state->dScaleFactor,
        MCT_getScaleFactorUnitsString(state),
        state->dLPFCutoff,
        state->dMembraneCap,
        state->dExtCmdSens,
        "NOT_YET_IMPLEMENTED",
        "NOT_YET_IMPLEMENTED",
        state->dRawScaleFactor,
        "NOT_YET_IMPLEMENTED",
        MCTG_HW_TYPE_NAMES[state->uHardwareType],
        state->dSecondaryAlpha,
        state->dSecondaryLPFCutoff,
        state->szAppVersion,
        state->szFirmwareVersion,
        state->szDSPVersion,
        state->szSerialNumber,
        uComPortID,
        uAxoBusID,
        uChannelID,
        uSerialNum,
        state->refreshTickCount.QuadPart,
        MCT_ticksToSeconds(state->refreshTickCount));
}

/**
* @brief Display the state to the console.
* @arg <tt>state</tt> - The state to be displayed.
*/
void MCT_displayState(MCT_electrodeStateSlot* state)
{
    char str[1024];

    MCT_debugMsg("MCT_displayState(@%p)\n", state);

    MCT_stateToString(state, str, 1024);
    MCT_printMsg("%s", str);

    return;
}

/*********************************
*       DISPLAY FUNCTIONS       *
*********************************/

///**
//* @brief Display the state of all the <tt>MCT_electrodeStateSlotPointers</tt> to the console.
//*/
//void MCT_displayElectrodes(void)
//{
//    EnterCriticalSection(MCT_criticalSectionPtr);
//    for (size_t i = 0; i < MCT_N_ELECTRODE_STATES; ++i)
//        MCT_displayState(&MCT_electrodeStateSlots[i]);
//    LeaveCriticalSection(MCT_criticalSectionPtr);
//
//    return;
//}

/**
* @brief Render the MC_TELEGRAPH_DATA struct as a string.
* @arg <tt>state</tt> - The packet to be converted into a string.
* @arg <tt>str</tt> - The character array in which to render the string.
*/
int MCT_MCTGPacketToString(MC_TELEGRAPH_DATA* mctgPacket, char* str, size_t strSize)  // This is called on message processing thread, if MCT_DEBUG is defined
{
    LPARAM ID = 0;
    MCT_debugMsg("MCT_MCTGPacketToString(@%p)\n", mctgPacket);

    if (mctgPacket == NULL)
        return sprintf_s(str, strSize, "MCT_electrodeStateSlot: NULL\n");

    if (mctgPacket->uHardwareType == MCTG_HW_TYPE_MC700A)
    {
        MCT_debugMsg("MCT_MCTGPacketToString: @%p is from a 700A.\n", mctgPacket);
        ID = MCTG_Pack700ASignalIDs(mctgPacket->uComPortID, mctgPacket->uAxoBusID, mctgPacket->uChannelID);
    }
    else if (mctgPacket->uHardwareType == MCTG_HW_TYPE_MC700B)
    {
        MCT_debugMsg("MCT_MCTGPacketToString: @%p is from a 700B.\n", mctgPacket);
        ID = MCTG_Pack700BSignalIDs(strtoul(mctgPacket->szSerialNumber, NULL, 10), mctgPacket->uChannelID);
    }

    if (mctgPacket->uHardwareType == MCTG_HW_TYPE_MC700A)
        return sprintf_s(str, strSize,
        "MC_TELEGRAPH_DATA (0x%p):\n"
        "\tID:                     0x%p (%u)\n"
        "\tOperating Mode:         %s\n"
        "\tScaled Out Signal:      %s (%s)\n"
        "\tAlpha:                  %3.4f\n"
        "\tScaleFactor:            %3.4f\n"
        "\tScaleFactorUnits:       %s\n"
        "\tLPF Cutoff:             %3.4f\n"
        "\tMembrane Capacitance:   %3.4f\n"
        "\tExt Cmd Sense:          %3.4f\n"
        "\tRaw Out Signal:         %s (%s)\n"
        "\tRaw Scale Factor:       %3.4f\n"
        "\tRaw Scale Factor Units: %s\n"
        "\tHardware Type:          %s\n"
        "\tSecondary Alpha:        %3.4f\n"
        "\tSecondary LPF Cutoff:   %3.4f\n"
        "\tuComPortID:             %u\n"
        "\tuAxoBusID:              %u\n"
        "\tuChannelID:             %u\n"
        "\tuVersion:               %u\n",
        mctgPacket,
        ID, ID,
        MCTG_MODE_NAMES[mctgPacket->uOperatingMode],
        MCT_scaledOutSignalToLongName(mctgPacket->uScaledOutSignal, mctgPacket->uHardwareType, mctgPacket->uOperatingMode),
        MCT_scaledOutSignalToShortName(mctgPacket->uScaledOutSignal, mctgPacket->uHardwareType, mctgPacket->uOperatingMode),
        mctgPacket->dAlpha,
        mctgPacket->dScaleFactor,
        MCT_scaleFactorUnitsToString(mctgPacket->uScaleFactorUnits, mctgPacket->uHardwareType, mctgPacket->uOperatingMode, mctgPacket->uScaledOutSignal),
        mctgPacket->dLPFCutoff,
        mctgPacket->dMembraneCap,
        mctgPacket->dExtCmdSens,
        "NOT_YET_IMPLEMENTED",
        "NOT_YET_IMPLEMENTED",
        mctgPacket->dRawScaleFactor,
        "NOT_YET_IMPLEMENTED",
        MCTG_HW_TYPE_NAMES[mctgPacket->uHardwareType],
        mctgPacket->dSecondaryAlpha,
        mctgPacket->dSecondaryLPFCutoff,
        mctgPacket->uComPortID,
        mctgPacket->uAxoBusID,
        mctgPacket->uChannelID,
        mctgPacket->uVersion);
    else if (mctgPacket->uHardwareType == MCTG_HW_TYPE_MC700B)
        return sprintf_s(str, strSize,
        "MC_TELEGRAPH_DATA (0x%p):\n"
        "\tID:                     0x%p (%u)\n"
        "\tOperating Mode:         %s\n"
        "\tScaled Out Signal:      %s (%s)\n"
        "\tAlpha:                  %3.4f\n"
        "\tScaleFactor:            %3.4f\n"
        "\tScaleFactorUnits:       %s\n"
        "\tLPF Cutoff:             %3.4f\n"
        "\tMembrane Capacitance:   %3.4f\n"
        "\tExt Cmd Sense:          %3.4f\n"
        "\tRaw Out Signal:         %s (%s)\n"
        "\tRaw Scale Factor:       %3.4f\n"
        "\tRaw Scale Factor Units: %s\n"
        "\tHardware Type:          %s\n"
        "\tSecondary Alpha:        %3.4f\n"
        "\tSecondary LPF Cutoff:   %3.4f\n"
        "\tApp Version:            %s\n"
        "\tFirmware Version:       %s\n"
        "\tDSPVersion:             %s\n"
        "\tSerial Number:          %s\n"
        "\tuComPortID:             %u\n"
        "\tuAxoBusID:              %u\n"
        "\tuChannelID:             %u\n"
        "\tuVersion:               %u\n",
        mctgPacket,
        ID, ID,
        MCTG_MODE_NAMES[mctgPacket->uOperatingMode],
        MCT_scaledOutSignalToLongName(mctgPacket->uScaledOutSignal, mctgPacket->uHardwareType, mctgPacket->uOperatingMode),
        MCT_scaledOutSignalToShortName(mctgPacket->uScaledOutSignal, mctgPacket->uHardwareType, mctgPacket->uOperatingMode),
        mctgPacket->dAlpha,
        mctgPacket->dScaleFactor,
        MCT_scaleFactorUnitsToString(mctgPacket->uScaleFactorUnits, mctgPacket->uHardwareType, mctgPacket->uOperatingMode, mctgPacket->uScaledOutSignal),
        mctgPacket->dLPFCutoff,
        mctgPacket->dMembraneCap,
        mctgPacket->dExtCmdSens,
        "NOT_YET_IMPLEMENTED",
        "NOT_YET_IMPLEMENTED",
        mctgPacket->dRawScaleFactor,
        "NOT_YET_IMPLEMENTED",
        MCTG_HW_TYPE_NAMES[mctgPacket->uHardwareType],
        mctgPacket->dSecondaryAlpha,
        mctgPacket->dSecondaryLPFCutoff,
        mctgPacket->szAppVersion,
        mctgPacket->szFirmwareVersion,
        mctgPacket->szDSPVersion,
        mctgPacket->szSerialNumber,
        mctgPacket->uComPortID,
        mctgPacket->uAxoBusID,
        mctgPacket->uChannelID,
        mctgPacket->uVersion);
    else
        return sprintf_s(str, strSize, "Unrecognized uHardwareType: %u\n", mctgPacket->uHardwareType);
}

/*********************************
*    AMPLIFIER ARRAY METHODS    *
*********************************/


/**
* @brief Look up an MCT_electrodeStateSlot struct's index by its ID.
* @arg <tt>ID</tt> - The ID of the struct to be found.
* @return The index of the struct, -1 if not found.
*/
int MCT_findSlotHoldingElectrodeState(LPARAM ID)  {
    MCT_debugMsg("MCT_findSlotHoldingElectrodeState(0x%p)\n", ID);

    MCT_debugMsg("MCT_findSlotHoldingElectrodeState() - Entering critical section...\n");
    EnterCriticalSection(MCT_criticalSectionPtr);

    int indexOfID=-1;  // We return this if we can't find the ID
    for (int i = 0; i < MCT_N_ELECTRODE_STATES; ++i)  {
        if (MCT_electrodeStateSlots[i].isFresh && MCT_electrodeStateSlots[i].ID == ID)  {
            indexOfID=i;
            break;
        }
    }

    MCT_debugMsg("MCT_findSlotHoldingElectrodeState() - Leaving critical section...\n");
    LeaveCriticalSection(MCT_criticalSectionPtr);

    return indexOfID;
}

/**
* @brief Look up an MCT_electrodeStateSlot struct's index by its ID.
* @arg <tt>ID</tt> - The ID of the struct to be found.
* @return The index of the struct, or the index of a new/empty slot in which to store a struct.
*/
int MCT_findEmptySlotForElectrodeState()  {  // Called from message processing thread
    MCT_debugMsg("MCT_findEmptySlotForElectrodeState() - Entering critical section...\n");
    EnterCriticalSection(MCT_criticalSectionPtr);

    // Find the empty space and create a new entry there.
    int electrodeIndex= -1;  // We return this if we can't find a free slot
    for (int i = 0; i < MCT_N_ELECTRODE_STATES; ++i)  {
        if (!MCT_electrodeStateSlots[i].isFresh)  {
            electrodeIndex=i;
            MCT_electrodeStateSlots[i].isFresh = TRUE;
            break;
        }
    }

    MCT_debugMsg("MCT_findEmptySlotForElectrodeState() - Leaving critical section...\n");
    LeaveCriticalSection(MCT_criticalSectionPtr);

    return electrodeIndex;
}

/**
* @brief Store an MCTG packet into the (global) <tt>MCT_electrodeStateSlotPointers</tt> array.
* @arg <tt>mctgPacket</tt> - A packet recieved from the Multiclamp Commander software, via Windows messaging.
*/
void MCT_storeMCTGPacket(MC_TELEGRAPH_DATA* mctgPacket)  // This is called on message processing thread
{
    int electrodeIndex;
    LPARAM ID = 0;

    MCT_debugMsg("MCT_storeMCTGPacket(@%p)", mctgPacket);

    if (mctgPacket->uHardwareType == MCTG_HW_TYPE_MC700A)
    {
        MCT_debugMsg("MCT_storeMCTGPacket: @%p is from a 700A.\n", mctgPacket);
        ID = MCTG_Pack700ASignalIDs(mctgPacket->uComPortID, mctgPacket->uAxoBusID, mctgPacket->uChannelID);
    }
    else if (mctgPacket->uHardwareType == MCTG_HW_TYPE_MC700B)
    {
        MCT_debugMsg("MCT_storeMCTGPacket: @%p is from a 700B.\n", mctgPacket);
        ID = MCTG_Pack700BSignalIDs(strtoul(mctgPacket->szSerialNumber, NULL, 10), mctgPacket->uChannelID);
    }
    else
        MCT_printMsg("MulticlampTelegraph - Unrecognizable Multiclamp hardware type: %p\n", mctgPacket->uHardwareType);

    MCT_debugMsg("MCT_storeMCTGPacket(%p) - ID = %p\n", mctgPacket, ID);

    MCT_debugMsg("MCT_storeMCTGPacket() - Entering critical section...\n");
    EnterCriticalSection(MCT_criticalSectionPtr);

    // See if this is an electrode we know about.  If so, great.  If not, try to find a free slot for it.
    electrodeIndex = MCT_findSlotHoldingElectrodeState(ID);
    if (electrodeIndex<0)  {
        // Means the ID isn't present, so we try to find a slot to put it in
        electrodeIndex=MCT_findEmptySlotForElectrodeState();  // will mark the slot as occupied if there's a free one
    }

    // Check for failure to find a slot, either pre-existing or free, as was needed
    if (electrodeIndex>=0)  {
        MCT_debugMsg("MCT_storeMCTGPacket(%p) - Copying ID:%p into electrodeIndex:%d\n", mctgPacket, ID, electrodeIndex);

        //Copy the data over to the local structure.
        MCT_electrodeStateSlots[electrodeIndex].ID = ID;
        MCT_electrodeStateSlots[electrodeIndex].uOperatingMode = mctgPacket->uOperatingMode;
        MCT_electrodeStateSlots[electrodeIndex].uScaledOutSignal = mctgPacket->uScaledOutSignal;
        MCT_electrodeStateSlots[electrodeIndex].dAlpha = mctgPacket->dAlpha;
        MCT_electrodeStateSlots[electrodeIndex].dScaleFactor = mctgPacket->dScaleFactor;
        MCT_electrodeStateSlots[electrodeIndex].uScaleFactorUnits = mctgPacket->uScaleFactorUnits;
        MCT_electrodeStateSlots[electrodeIndex].dLPFCutoff = mctgPacket->dLPFCutoff;
        MCT_electrodeStateSlots[electrodeIndex].dMembraneCap = mctgPacket->dMembraneCap;
        MCT_electrodeStateSlots[electrodeIndex].dExtCmdSens = mctgPacket->dExtCmdSens;
        MCT_electrodeStateSlots[electrodeIndex].uRawOutSignal = mctgPacket->uRawOutSignal;
        MCT_electrodeStateSlots[electrodeIndex].dRawScaleFactor = mctgPacket->dRawScaleFactor;
        MCT_electrodeStateSlots[electrodeIndex].uRawScaleFactorUnits = mctgPacket->uRawScaleFactorUnits;
        MCT_electrodeStateSlots[electrodeIndex].uHardwareType = mctgPacket->uHardwareType;
        MCT_electrodeStateSlots[electrodeIndex].dSecondaryAlpha = mctgPacket->dSecondaryAlpha;
        MCT_electrodeStateSlots[electrodeIndex].dSecondaryLPFCutoff = mctgPacket->dSecondaryLPFCutoff;
        if (mctgPacket->uHardwareType == MCTG_HW_TYPE_MC700A)
        {
            //MCT_electrodeStateSlots[electrodeIndex].szAppVersion = UNSPECIFIED_FOR_700A;
            //MCT_electrodeStateSlots[electrodeIndex].szFirmwareVersion = UNSPECIFIED_FOR_700A;
            //MCT_electrodeStateSlots[electrodeIndex].szDSPVersion = UNSPECIFIED_FOR_700A;
            //MCT_electrodeStateSlots[electrodeIndex].szSerialNumber = UNSPECIFIED_FOR_700A;
            MCT_copyVersionString(MCT_electrodeStateSlots[electrodeIndex].szAppVersion, UNSPECIFIED_FOR_700A);
            MCT_copyVersionString(MCT_electrodeStateSlots[electrodeIndex].szFirmwareVersion, UNSPECIFIED_FOR_700A);
            MCT_copyVersionString(MCT_electrodeStateSlots[electrodeIndex].szDSPVersion, UNSPECIFIED_FOR_700A);
            MCT_copyVersionString(MCT_electrodeStateSlots[electrodeIndex].szSerialNumber, UNSPECIFIED_FOR_700A);
        }
        else
        {
            //       MCT_electrodeStateSlotPointers[electrodeIndex]->szAppVersion = MCT_copyString(mctgPacket->szAppVersion);  // Won't this leak memory?  --ALT, 2015-01-16
            //       MCT_electrodeStateSlotPointers[electrodeIndex]->szFirmwareVersion = MCT_copyString(mctgPacket->szFirmwareVersion);
            //       MCT_electrodeStateSlotPointers[electrodeIndex]->szDSPVersion = MCT_copyString(mctgPacket->szDSPVersion);
            //       MCT_electrodeStateSlotPointers[electrodeIndex]->szSerialNumber = MCT_copyString(mctgPacket->szSerialNumber);
            MCT_copyVersionString(MCT_electrodeStateSlots[electrodeIndex].szAppVersion,mctgPacket->szAppVersion);
            MCT_copyVersionString(MCT_electrodeStateSlots[electrodeIndex].szFirmwareVersion, mctgPacket->szFirmwareVersion);
            MCT_copyVersionString(MCT_electrodeStateSlots[electrodeIndex].szDSPVersion, mctgPacket->szDSPVersion);
            MCT_copyVersionString(MCT_electrodeStateSlots[electrodeIndex].szSerialNumber, mctgPacket->szSerialNumber);
        }

        QueryPerformanceCounter(&(MCT_electrodeStateSlots[electrodeIndex].refreshTickCount));

        MCT_debugMsg("MCT_storeMCTGPacket(%p) - Updated state %p (MCT_electrodeStateSlotPointers[%d]).\n", mctgPacket, ID, electrodeIndex);
    }

    MCT_debugMsg("MCT_storeMCTGPacket() - Leaving critical section...\n");
    LeaveCriticalSection(MCT_criticalSectionPtr);
}

void MCT_recordThatElectrodeExists(LPARAM electrodeID)  {
    EnterCriticalSection(MCT_criticalSectionPtr);
    bool didFindElectrode=false;
    for (size_t i=0; i<MCT_N_FRESH_KNOWN_ELECTRODE_IDS; ++i)  {
        if ( MCT_freshKnownElectrodeIDs[i]==electrodeID )  {
            // This electrodeID is already in the list, so don't want to put in again
            didFindElectrode=true;
        }
    }
    if (!didFindElectrode)  {
        // If we get here, the electrodeID is not already in the list of fresh IDs
        size_t targetIndex=MCT_N_FRESH_KNOWN_ELECTRODE_IDS;
        if (targetIndex<MAX_N_FRESH_KNOWN_ELECTRODE_IDS)  {
            MCT_freshKnownElectrodeIDs[targetIndex]=electrodeID;
            ++MCT_N_FRESH_KNOWN_ELECTRODE_IDS;
        }
    }
    LeaveCriticalSection(MCT_criticalSectionPtr);
}




/*********************************
*  WINDOWS THREADING/MESSAGING  *
*********************************/

/**
* @brief Open a connection to the specified electrode (subscribe for updates).
* @arg <tt>ID</tt> - The ID of the electrode to which to connect.
*/
void MCT_openConnection(LPARAM ID)  // This is called on message processing thread
{
    MCT_debugMsg("MCT_openConnection(0x%p)\n", ID);
    PostMessage(HWND_BROADCAST, MCT_MCTGOpenMessage, (WPARAM)MCT_hwnd, ID);
}

/**
* @brief Close a connection to the specified electrode (unsubscribe for updates).
* @arg <tt>ID</tt> - The ID of the electrode from which to disconnect.
*/
void MCT_closeConnection(LPARAM ID)  // This is called on message processing thread
{
    MCT_debugMsg("MCT_closeConnection(0x%p)\n", ID);
    PostMessage(HWND_BROADCAST, MCT_MCTGOpenMessage, (WPARAM)MCT_hwnd, ID);
}

/**
* @brief Request a telegraph packet frm the specified electrode (request a single update).
* @arg <tt>ID</tt> - The ID of the electrode from which to request an update.
*/
void MCT_requestElectrodeState(LPARAM ID)  // This is called on message processing thread
{
    MCT_debugMsg("MCT_requestElectrodeState(0x%p)\n", ID);
    PostMessage(HWND_BROADCAST, MCT_MCTGRequestMessage, (WPARAM)MCT_hwnd, ID);
    //Yield the CPU to allow the Multiclamp Commander to respond, and the message processing thread to get the telegraph.
    SwitchToThread();
}

/**
* @brief Broadcast to all electrodes, requesting them to identify themselves.
*/
void MCT_requestAllElectrodeIDs(void)  // This gets called from the message processing thread
{
    MCT_debugMsg("MCT_requestAllElectrodeIDs() - Sending MCT_MCTGBroadcastMessage...\n");
    PostMessage(HWND_BROADCAST, MCT_MCTGBroadcastMessage, (WPARAM)MCT_hwnd, NULL);
    //Yield the CPU to allow the Multiclamp Commander(s) to respond, and the message processing thread to get the telegraph.
    SwitchToThread();
}

/**
* @brief Returns the handle to the active module (DLL or executable), necessary for working with windows.
*
* @return The current module's handle.
*/
HINSTANCE MCT_getCurrentModuleHandle(void)  // This is called on message processing thread
{
#ifdef MATLAB_MEX_FILE
    return GetModuleHandle("MulticlampTelegraph.mexw64");
#else
    return GetModuleHandle("MulticlampTelegraph.exe");
#endif
}

/**
* @brief Required function for processing Windows messages.
*
* This function is necessary for registering a window class, to create a window.
* Lots of stupid hoops to jump through, considering I'm pumping my own messages.
*
* @see http://msdn.microsoft.com/en-us/library/ms633573(VS.85).aspx
* @return 1 if processing a normal message, 0 if it is a stop message.
*/
LRESULT CALLBACK MCT_WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)  // This is called on message processing thread
{
    MC_TELEGRAPH_DATA* mctgPacket = NULL;
#ifdef MCT_DEBUG
    char packetStr[2048];
#endif

    MCT_debugMsg("MCT_WindowProc(hwnd: %p, uMsg: %p, wParam: %p, lParam: %p)\n", hwnd, uMsg, wParam, lParam);

    //Process messages.
    if ( (uMsg == MCT_STOP) || (uMsg == WM_DESTROY) || (uMsg == WM_QUIT) )
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_STOP message.\n");
        return 0;
    }
    else if (uMsg == MCT_MCTGIDMessage)
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGIDMessage message.\n");
        MCT_recordThatElectrodeExists(lParam);
        //MCT_requestElectrodeState(lParam);
        //MCT_openConnection(lParam);
    }
    else if (uMsg == MCT_MCTGReconnectMessage)
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGReconnectMessage message.\n");
        MCT_debugMsg("MCT_WindowProc(...) - Requesting reconnect...\n");
        //MCT_openConnection(lParam);//Request reconnect. Is this necessary?
        MCT_requestElectrodeState(lParam);
    }
    else if (uMsg == WM_COPYDATA)
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved WM_COPYDATA message.\n");
        //Here's a message that's probably from the Multiclamp Commander.
        if (((COPYDATASTRUCT*)lParam)->dwData == MCT_MCTGRequestMessage)
        {
            mctgPacket = (MC_TELEGRAPH_DATA *)((COPYDATASTRUCT*)lParam)->lpData;
            if ( (mctgPacket->uVersion != MCTG_API_VERSION_700A) && 
                 (mctgPacket->uVersion != MCTG_API_VERSION_700B) && 
                 (mctgPacket->uVersion != MCTG_API_VERSION_700B+1) )  
            // This last check is b/c we include the MultiClampBroadcastMsg.hpp included 
            // with the Multiclamp 700B Commander version 2.1, but we want the mex DLL to
            // work with both 2.1 and 2.2, and the messages from 2.2 have uVersion==14, whereas
            // the ones from 2.1 have uVersion==13.  But otherwise the messages from 2.2 have the
            // same structure as the ones from 2.1.
            {
                MCT_errorMsg("MulticlampTelegraph Warning - Unrecognized uVersion field found in MC_TELEGRAPH_DATA struct: %u\n", mctgPacket->uVersion);
            }

#ifdef MCT_DEBUG
            MCT_MCTGPacketToString(mctgPacket, packetStr, 2048);
            MCT_debugMsg("MCT_storeMCTGPacket:\n%s\n", packetStr);
#endif
            MCT_storeMCTGPacket(mctgPacket);
        }
        else
        {
            MCT_debugMsg("MCT_WindowProc(...) - Recieved unrecognized WM_COPYDATA message: dwData = %p\n", ((COPYDATASTRUCT*)lParam)->dwData);
        }
    }
    else if (uMsg == MCT_MCTGBroadcastMessage)
    {
        if (wParam == (WPARAM)MCT_hwnd)
        {
            MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGBroadcastMessage message from %p (MCT_hwnd).\n", wParam);
        }
        else
        {
            MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGBroadcastMessage message from %p.\n", wParam);
        }
    }
    else if (uMsg == MCT_MCTGRequestMessage)
    {
        if (wParam == (WPARAM)MCT_hwnd)
        {
            MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGRequestMessage message from %p (MCT_hwnd).\n", wParam);
        }
        else
        {
            MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGRequestMessage message from %p.\n", wParam);
        }
    }
    else if (uMsg == MCT_MCTGOpenMessage)
    {
        if (wParam == (WPARAM)MCT_hwnd)
        {
            MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGOpenMessage message from %p (MCT_hwnd).\n", wParam);
        }
        else
        {
            MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGOpenMessage message from %p.\n", wParam);
        }
    }
    else if (uMsg == MCT_MCTGCloseMessage)
    {
        if (wParam == (WPARAM)MCT_hwnd)
        {
            MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGCloseMessage message from %p (MCT_hwnd).\n", wParam);
        }
        else
        {
            MCT_debugMsg("MCT_WindowProc(...) - Recieved MCT_MCTGCloseMessage message from %p.\n", wParam);
        }
    }
    else if (uMsg == WM_CREATE)//Sent upon window creation.
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved WM_Create message.\n");
    }
    else if (uMsg == WM_GETMINMAXINFO)//Sent upon window creation (depending on the type of window).
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved WM_GETMINMAXINFO message.\n");
    }
    else if (uMsg == WM_NCCREATE)//Sent upon window creation (depending on the type of window).
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved WM_NCCREATE message.\n");
    }
    else if (uMsg == WM_NCCALCSIZE)//Sent upon window creation (depending on the type of window).
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved WM_NCCALCSIZE message.\n");
    }
    else if (uMsg == WM_DESTROY)//Sent upon window destruction.
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved WM_DESTROY message.\n");
    }
    else if (uMsg == WM_NCDESTROY)//Sent upon window destruction (depending on the type of window).
    {
        MCT_debugMsg("MCT_WindowProc(...) - Recieved WM_NCDESTROY message.\n");
    }
    else
    {
        //Any other messages should just be ignored, I think. Use them as cues to check for stop signals.
        MCT_debugMsg("MCT_WindowProc(...) - Unrecognized window message: %u (See WinUser.h for common window message definitions)\n", uMsg);
    }

    MCT_debugMsg("MCT_WindowProc(...) - Completed message handling.\n");

    return 1;
}

/**
* @brief Creates the window used to recieve Axon Multiclamp Commander messages.
*/
BOOL MCT_createClientWindow(void)  // This is called on message processing thread
{
    HINSTANCE moduleHandle = NULL;
    ATOM wndClassAtom = NULL;

    moduleHandle = MCT_getCurrentModuleHandle();
    if (moduleHandle == NULL)
    {
        printWindowsErrorMessage();
        MCT_errorMsg("MCT_createClientWindow() - Failed to get module handle.\n");
        return FALSE;
    }

    if (MCT_hwnd == NULL)
    {
        MCT_wndClass.cbSize = sizeof(WNDCLASSEX);
        MCT_wndClass.style = CS_GLOBALCLASS;
        MCT_wndClass.lpfnWndProc = MCT_WindowProc;
        MCT_wndClass.cbClsExtra = 0;
        MCT_wndClass.cbWndExtra = 0;
        MCT_wndClass.hInstance = moduleHandle;
        MCT_wndClass.hIcon = NULL;
        MCT_wndClass.hCursor = NULL;
        MCT_wndClass.hbrBackground = NULL;
        MCT_wndClass.lpszMenuName = NULL;
        MCT_wndClass.lpszClassName = MCT_WINDOWCLASS_NAME;
        MCT_wndClass.hIconSm = NULL;

        wndClassAtom = RegisterClassEx(&MCT_wndClass);
        if (!wndClassAtom)
        {
            printWindowsErrorMessage();
            MCT_errorMsg("MCT_createClientWindow() - Failed to create register window class.\n");
            return FALSE;
        }

        MCT_debugMsg("MCT_createClientWindow() - Creating window...\n");

        //It's a nice idea to just use a HWND_MESSAGE class of window, but the 700B software sucks and needs to send broadcast messages.
        ////Use a message only window (HWND_MESSAGE), broadcast messages aren't necessary.
        //MCT_hwnd = CreateWindow(MCT_WINDOWCLASS_NAME, "MCT_Message_Only", WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        //                    CW_USEDEFAULT, HWND_MESSAGE, (HMENU)NULL, moduleHandle, (LPVOID)NULL);

        //Use a full-fledged window (WS_OVERLAPPED), so we can recieve our own broadcast messages, for debugging.
        MCT_hwnd = CreateWindow(MCT_WINDOWCLASS_NAME, "MCT_Message_Only", WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
            CW_USEDEFAULT, WS_OVERLAPPED, (HMENU)NULL, moduleHandle, (LPVOID)NULL);
        //#endif
        //#endif
        MCT_debugMsg("MCT_createClientWindow() - Created window: %p\n", MCT_hwnd);
        if (MCT_hwnd == NULL)
        {
            printWindowsErrorMessage();
            MCT_errorMsg("MCT_createClientWindow() - Failed to create messaging client window.\n");
            return FALSE;
        }

        ShowWindow(MCT_hwnd, SW_HIDE);
    }

    MCT_debugMsg("MCT_createClientWindow() - Window has been created.\n");

    return TRUE;
}

/**
* @brief Tear down the client window used for Windows messaging.
*/
void MCT_destroyClientWindow(void)  // This is called on message processing thread
{
    HINSTANCE moduleHandle = NULL;
    //BOOL result;

    MCT_debugMsg("MCT_destroyClientWindow() - Destroying client window...\n");

    if (!DestroyWindow(MCT_hwnd))
    {
        printWindowsErrorMessage();
        MCT_errorMsg("MCT_destroyClientWindow() - Failed to destroy window.\n");
    }
    MCT_hwnd=NULL;

    moduleHandle = MCT_getCurrentModuleHandle();
    if (moduleHandle == NULL)
    {
        printWindowsErrorMessage();
        MCT_errorMsg("MCT_destroyClientWindow() - Failed to get module handle.\n");
        return;
    }

    if (!UnregisterClass(MCT_WINDOWCLASS_NAME, moduleHandle))
    {
        printWindowsErrorMessage();
        MCT_errorMsg("MCT_destroyClientWindow() - Failed to get unregister window class.\n");
    }

    return;
}

///**
//* @brief Close all connections, for all electrodes.
//*/
//void MCT_closeAllConnections(void)  // This is called on message processing thread
//{
//    int i;
//
//    MCT_debugMsg("MCT_closeAllConnections() - Entering critical section...\n");
//    EnterCriticalSection(MCT_criticalSectionPtr);
//
//    for (i = 0; i < MCT_N_ELECTRODE_STATES; ++i)  {
//        MCT_debugMsg("MCT_closeAllConnections() - Closing connection for MCT_electrodeStateSlotPointers[%d] = @%p...\n", i, MCT_electrodeStateSlotPointers[i]);
//        if (MCT_electrodeStateSlots[i].isFresh)
//            MCT_closeConnection(MCT_electrodeStateSlots[i].ID);
//    }
//
//    MCT_debugMsg("MCT_closeAllConnections() - Leaving critical section...\n");
//    LeaveCriticalSection(MCT_criticalSectionPtr);
//    MCT_debugMsg("MCT_closeAllConnections() - Completed\n");
//}

/**
* @brief The work function for the message processing thread.
*
* @arg <tt>lpParam</tt> - A pointer, as prescribed by the Windows thread creation. Not used.
* @see http://msdn.microsoft.com/en-us/library/ms644928(VS.85).aspx
*/
DWORD WINAPI MCT_messageProcessingThreadWorkerFunction(LPVOID lpParam)
{
    BOOL gotMessage = 0;
    LPMSG msgPtr = NULL;
    MSG msg;

    MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Creating client window...\n");

    if (!MCT_createClientWindow())  // This thread will own the window.
        return 1;  // Window creation failed, no point in continuing.

    MCT_isMessageThreadRunning = TRUE;

    //Probe for Multiclamp Commanders.
    //MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Broadcasting to probe for Multiclamp Commander instances...\n");
    //MCT_requestAllElectrodeIDs();
    //MCT_requestElectrodeState(MCTG_Pack700ASignalIDs(3, 1, 1));  // What is up with this?  We don't even know if such an electrode exists...  -- ALT, 2015-01-28

    MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Starting message processing loop...\n");

    //msgPtr = (LPMSG)calloc(1, sizeof(MSG));
    msgPtr = &msg;

    //Wait for messages until we get the stop signal.
    //while ( (!MCT_doStopMessageProcessingThread) && (WaitMessage()) )
    while (!MCT_doStopMessageProcessingThread)
    {
        /**The MSDN documentation isn't really clear on whether or not WaitMessage is neccessary, or if GetMessage can
        * be used to block thread execution.
        * Empirical observation suggests that WaitMessage is not necessary.
        MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Waiting for message...\n");
        if (!WaitMessage())
        {
        printWindowsErrorMessage();
        MCT_printMsg("MCT_messageProcessingThreadWorkerFunction() - An error occurred while waiting for a message.\n");
        return 1;
        }*/

        MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Getting message...\n");
        gotMessage = GetMessage(msgPtr, MCT_hwnd, 0, 0);
        if (!gotMessage)
        {
            MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - GetMessage(...) returned FALSE!\n");
            continue;//Oops.
        }

        MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Handing message off to MCT_WindowProc(...)...\n");
        if (!MCT_WindowProc(MCT_hwnd, msgPtr->message, msgPtr->wParam, msgPtr->lParam))
        {
            MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Terminating message processing loop...\n");
            break;//Shutdown.
        }
    }

    // We don't open connections anymore, so no need to close them
    //MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Loop terminated. Closing connections...\n");
    //MCT_closeAllConnections();

    MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Loop terminated. Destroying client window...\n");
    MCT_destroyClientWindow();

    //if (!MCT_doStopMessageProcessingThread) //We're shutting down due to an error.

    MCT_doStopMessageProcessingThread = FALSE;
    MCT_isMessageThreadRunning = FALSE;

    MCT_debugMsg("MCT_messageProcessingThreadWorkerFunction() - Message processing thread terminated.\n");
    //This is the preferred method of ending a thread in C, but not in C++, according to MSDN.
    //ExitThread(0);

    //free(msgPtr);  // need to free calloc'ed() space

    return 0;
}

///**
// * @brief Creates (and starts) the message processing thread.
// * @pre The messaging window has been created.
// */
//void MCT_createMessageProcessingThread(void)
//{
//   MCT_debugMsg("MCT_createMessageProcessingThread() - Creating thread...\n");
//   MCT_messageProcessingThread = CreateThread(NULL, 0, MCT_messageProcessingThreadWorkerFunction, NULL, 0, &MCT_messageProcessingThreadID);
//   MCT_debugMsg("MCT_createMessageProcessingThread() - Thread created.\n");
//}

/*********************************
*       STARTUP/STOP        *
*********************************/

/**
* @brief Creates the CRITICAL_SECTION, for cross-thread exclusion.
* @note This MUST occur before starting the message processing thread.
*/
void MCT_initializeCriticalSection(void)  // Called from main thread
{
    if (!MCT_criticalSectionPtr)
    {
        MCT_debugMsg("MCT_initializeCriticalSection() - Initializing MCT_criticalSectionPtr...\n");
        //MCT_criticalSectionPtr = (CRITICAL_SECTION *)calloc(1, sizeof(CRITICAL_SECTION));
        MCT_criticalSectionPtr = &MCT_criticalSection;
        InitializeCriticalSection(MCT_criticalSectionPtr);
        MCT_debugMsg("MCT_initializeCriticalSection() - MCT_criticalSectionPtr initialized.\n");
    }
}

/**
* @brief Clean up and shut down the module.
*
* Release all dynamic memory and stop the message processing thread.
*/
void MCT_stop(void)
{
    int i;

    if (!MCT_isRunning)
    {
        MCT_debugMsg("MCT_stop() - Not running.\n");
        return;
    }

    MCT_debugMsg("MCT_stop() - Signalling message processing thread: MCT_STOP\n");
    MCT_doStopMessageProcessingThread = TRUE;
    PostMessage(MCT_hwnd, MCT_STOP, NULL, NULL);
    PostThreadMessage(MCT_messageProcessingThreadID, MCT_STOP, NULL, NULL);

    MCT_debugMsg("MCT_stop() - Waiting for message processing thread to stop.\n");
    SwitchToThread();  //Yield the CPU, so the messaging thread (hopefully) takes control.
    switch (WaitForSingleObject(MCT_messageProcessingThread, 5000))   //Wait ~5 second(s).
    {
    case WAIT_ABANDONED:
        MCT_debugMsg("MCT_stop() - WaitForSingleObject(MCT_messageProcessingThread) = WAIT_ABANDONDED\n");
        break;
    case WAIT_OBJECT_0:
        MCT_debugMsg("MCT_stop() - WaitForSingleObject(MCT_messageProcessingThread) = WAIT_OBJECT_0\n");
        break;
    case WAIT_TIMEOUT:
        MCT_debugMsg("MCT_stop() - WaitForSingleObject(MCT_messageProcessingThread) = WAIT_TIMEOUT\n");
        MCT_debugMsg("MCT_stop() - Re-waiting for message processing thread to stop.\n");
        SwitchToThread();
        switch (WaitForSingleObject(MCT_messageProcessingThread, 5000))
        {
        case WAIT_ABANDONED:
            MCT_debugMsg("MCT_stop() - WaitForSingleObject(MCT_messageProcessingThread) = WAIT_ABANDONDED\n");
            break;
        case WAIT_OBJECT_0:
            MCT_debugMsg("MCT_stop() - WaitForSingleObject(MCT_messageProcessingThread) = WAIT_OBJECT_0\n");
            break;
        case WAIT_TIMEOUT:
            MCT_debugMsg("MCT_stop() - WaitForSingleObject(MCT_messageProcessingThread) = WAIT_TIMEOUT\n");
            break;
        default:
            MCT_debugMsg("MCT_stop() - WaitForSingleObject(MCT_messageProcessingThread) = Unrecognized return value ???\n");
        }
        break;
    default:
        MCT_debugMsg("MCT_stop() - WaitForSingleObject(MCT_messageProcessingThread) = Unrecognized return value ???\n");
    }

    if (MCT_isMessageThreadRunning)
    {
        //We could have segfaults now, if the thread tries to access memory after it gets cleared below.
        MCT_errorMsg("MCT_stop() - MCT_messageProcessingThread appears to still be running. Continuing with stop procedure anyway.\n");
    }

    MCT_debugMsg("MCT_stop() - Clearing MCT_electrodeStateSlots array.\n");
    MCT_debugMsg("MCT_stop() - Entering critical section...\n");
    EnterCriticalSection(MCT_criticalSectionPtr);
    for (i = 0; i < MCT_N_ELECTRODE_STATES; ++i)  {
        //MCT_freeElectrodeState(MCT_electrodeStatePointers[i]);
        MCT_electrodeStateSlots[i].isFresh=FALSE;
    }
    //free(MCT_electrodeStatePointers);
    MCT_debugMsg("MCT_stop() - Leaving critical section...\n");
    LeaveCriticalSection(MCT_criticalSectionPtr);

    // Finally, release the critical section object
    DeleteCriticalSection(MCT_criticalSectionPtr);
    MCT_criticalSectionPtr=NULL;

    MCT_isRunning = false;
}

/**
* @brief Initialize the Windows messaging, an MCT_electrodeStateSlot array, and other basic functionality.
*        Register all window messages. Start a message processing thread (which will create its own window).
*/
void MCT_start(void)
{
    LARGE_INTEGER performanceFrequencyResult;

    if (MCT_isRunning)
    {
        MCT_debugMsg("MCT_start() - Already started.\n");
        return;
    }

    mexAtExit(MCT_stop);  // Register the stop hook, so it's executed when the mex file is cleared.

    MCT_debugMsg("MCT_start() - Initializing performancePeriod...\n");
    QueryPerformanceFrequency(&performanceFrequencyResult);
    MCT_performancePeriod = 1.0 / (double)performanceFrequencyResult.QuadPart;//Inverse of ticks per second. Cache the division.
    MCT_debugMsg("MCT_start() - MCT_performancePeriod = %3.4f [S/tick] from %llu [ticks/S]\n", MCT_performancePeriod, performanceFrequencyResult.QuadPart);

    MCT_initializeCriticalSection();

    // Initialize the array of electrode state slots, marked all as empty
    MCT_debugMsg("MCT_start() - Initializing MCT_electrodeStateSlots array...\n");
    size_t i;
    for (i=0; i<MCT_N_ELECTRODE_STATES; ++i)  {
        MCT_electrodeStateSlots[i].isFresh=FALSE;
    }

    MCT_debugMsg("MCT_start() - Registering window messages...\n");
    MCT_MCTGOpenMessage = RegisterWindowMessage(MCTG_OPEN_MESSAGE_STR);
    MCT_MCTGCloseMessage = RegisterWindowMessage(MCTG_CLOSE_MESSAGE_STR);
    MCT_MCTGRequestMessage = RegisterWindowMessage(MCTG_REQUEST_MESSAGE_STR);
    MCT_MCTGReconnectMessage = RegisterWindowMessage(MCTG_RECONNECT_MESSAGE_STR);
    MCT_MCTGBroadcastMessage = RegisterWindowMessage(MCTG_BROADCAST_MESSAGE_STR);
    MCT_MCTGIDMessage = RegisterWindowMessage(MCTG_ID_MESSAGE_STR);
    MCT_STOP = RegisterWindowMessage("MCT_STOP");
    MCT_debugMsg("MCT_start() - Window messages:\n\t"
        "MCT_MCTGOpenMessage:      %p\n\t"
        "MCT_MCTGCloseMessage:     %p\n\t"
        "MCT_MCTGRequestMessage:   %p\n\t"
        "MCT_MCTGReconnectMessage: %p\n\t"
        "MCT_MCTGBroadcastMessage: %p\n\t"
        "MCT_MCTGIDMessage:        %p\n\t"
        "MCT_STOP:             %p\n",
        MCT_MCTGOpenMessage, MCT_MCTGCloseMessage,
        MCT_MCTGRequestMessage, MCT_MCTGReconnectMessage, 
        MCT_MCTGBroadcastMessage, MCT_MCTGIDMessage,
        MCT_STOP);

    //MCT_createMessageProcessingThread();
    MCT_debugMsg("MCT_createMessageProcessingThread() - Creating thread...\n");
    MCT_messageProcessingThread = CreateThread(NULL, 0, MCT_messageProcessingThreadWorkerFunction, NULL, 0, &MCT_messageProcessingThreadID);
    MCT_debugMsg("MCT_createMessageProcessingThread() - Thread created.\n");

    MCT_isRunning = true;

    Sleep(100);
}

/*********************************
*        DATA FUNCTIONS         *
*********************************/
/**
* @brief Compute a factor, such that when multiplied by the voltage (in Volts) on the primary/scaled output, the result will be in the units specified by <tt>MCT_getUnits</tt>.
* @arg <tt>state</tt> - A valid <tt>MCT_electrodeStateSlot</tt> pointer.
* @return A value which, when multiplied by the recorded signal [V] of the primary/scaled output will convert it into the appropriate unit as determined by <tt>MCT_getUnits</tt>.
*/
double MCT_getScaledGain(MCT_electrodeStateSlot* state)
{
    return  state->dAlpha * state->dScaleFactor;  

}

/**
* @brief Return the units, as a string, that corresponds to the scale factor returned by <tt>MCT_getScaleGain</tt>.
* @arg <tt>state</tt> - A valid <tt>MCT_electrodeStateSlot</tt> pointer.
* @return The units corresponding to the result of <tt>MCT_getScaleGain</tt> (ie. "nA").
*/
char* MCT_getScaledUnits(MCT_electrodeStateSlot* state)
{

    switch (state->uScaleFactorUnits)
    {
    case 0:
        return "V";
    case 1:
        return "mV";
    case 2:
        return "uV";
    case 3:
        return "A";
    case 4:
        return "mA";
    case 5:
        return "uA";
    case 6:
        return "nA";
    case 7: 
        return "pA";
    default:
        return "???";
    }

}



/**********************************
**********************************
* PROGRAM CONTROL/USER INTERFACE *
**********************************
**********************************/

#ifdef MATLAB_MEX_FILE
/**********************************
*          MEX INTERFACE         *
**********************************/
/////@brief A central <tt>mwSize</tt> for use when creating mxArrays.
//mwSize MCT_mxDims[2] = {1, 1};  //Global 1x1 array indicator, as this is very common.
///@brief The set of field names that define the mxArray equivalent of an <tt>MCT_electrodeStateSlot</tt> struct.
const char* MCT_mxFieldNames[] = {"ID", 
                                  "OperatingMode", 
                                  "ScaledOutSignal", 
                                  "Alpha", 
                                  "ScaleFactor", 
                                  "ScaleFactorUnits", 
                                  "LPFCutoff", 
                                  "MembraneCap", 
                                  "ExtCmdSens", 
                                  "RawOutSignal", 
                                  "RawScaleFactor", 
                                  "RawScaleFactorUnits", 
                                  "HardwareType", 
                                  "SecondaryAlpha", 
                                  "SecondaryLPFCutoff", 
                                  "AppVersion", 
                                  "FirmwareVersion",
                                  "DSPVersion", 
                                  "SerialNumber", 
                                  "Age", 
                                  "ComPortID", 
                                  "AxoBusID", 
                                  "ChannelID", 
                                  "SerialNum"};
const size_t MCT_nFieldNamesInMatlabStruct=sizeof(MCT_mxFieldNames)/sizeof(char *);

/**
* @brief Convert an ID value into an mxArray.
* @arg <tt>ID</tt> - The ID to be converted into an mxArray.
* @arg <tt>mxID</tt> - A pointer to the mxArray pointer in which to place the 16-bit ID. Must point to NULL.
*/
mxArray* MCT_packageElectrodeID(LPARAM electrodeID)
{
    mxArray* result = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
    UINT32* resultStoragePtr = (UINT32*)mxGetData(result);
    *resultStoragePtr = (UINT32)electrodeID;  
      // Even though electrodeID is an LPARAM, we know that 0 <= electrodeID < 2^32
    return result;
}

LPARAM MCT_unpackageElectrodeID(mxArray* mxID)  {
    if ( mxGetNumberOfElements(mxID) == 1 )  {
        if (mxIsUint32(mxID))  {
            UINT32* ptr = (UINT32*)mxGetData(mxID);
            return (LPARAM)(*ptr);
        }
        else if (mxIsDouble(mxID))  {
            double* ptr = mxGetPr(mxID);
            return (LPARAM)(UINT32)(*ptr);
        }
        else  {
            mexErrMsgTxt("MCT_unpackageElectrodeID - Invalid mxID. Must be a scalar uint32 or scalar double.");
            return 0;  // Suppress stupid warning
        }
    }
    else  {
        mexErrMsgTxt("MCT_unpackageElectrodeID - Invalid mxID. Must be a scalar uint32 or scalar double.");
        return 0;  // Suppress stupid warning
    }
}

///**
//* @brief Convert an mxArray value into an ID.
//* @arg <tt>mxID</tt> - The mxArray containing the 16-bit ID, or the uComPortID/uAxoBusID/uChannelID, or uSerialNum/uChannelID.
//* @return The 16 bit unsigned integer corresponding to the ID.
//*/
//LPARAM MCT_unpackageElectrodeIDfancy(mxArray* mxID)
//{
//    double *ptr;
//    size_t numEl;
//    unsigned int uComPortID, uAxoBusID, uChannelID, uSerialNum = 0;
//
//    ptr = mxGetPr(mxID);
//    numEl = mxGetNumberOfElements(mxID);
//    if (numEl == 1)
//    {
//        return (LPARAM)*ptr;
//    }
//    else if (numEl == 2)
//    {
//        uSerialNum = (unsigned int)ptr[0];
//        uChannelID = (unsigned int)ptr[1];
//
//        //MCTG_Pack700BSignalIDs(UINT uComPortID, UINT uAxoBusID, UINT uChannelID)
//        return MCTG_Pack700BSignalIDs(uSerialNum, uChannelID);
//    }
//    else if (numEl == 3)
//    {
//        uComPortID = (unsigned int)ptr[0];
//        uAxoBusID = (unsigned int)ptr[1];
//        uChannelID = (unsigned int)ptr[2];
//
//        //MCTG_Pack700BSignalIDs(UINT uComPortID, UINT uAxoBusID, UINT uChannelID)                          
//        return MCTG_Pack700ASignalIDs(uComPortID, uAxoBusID, uChannelID);
//    }
//    else
//        mexErrMsgTxt("MCT_unpackageElectrodeID - Invalid mxID. Must be a 1, 2, or 3 element array.");
//
//    return 0;
//}

/**
* @brief Convert an MCT_electrodeStateSlot struct into its Matlab equivalent.
* @arg <tt>state</tt> - The state to be converted.
* @arg <tt>mxStruct</tt> - The memory location in which to create the mxArray object. The value pointed to must be NULL.
*/
// The caller of MCT_packageElectrodeStateAndMarkAsStale is responsible for entering the critical section before the call.
mxArray* MCT_packageElectrodeStateAndMarkAsStale(MCT_electrodeStateSlot* state)
{
    unsigned int uComPortID, uAxoBusID, uChannelID, uSerialNum = 0;
    mxArray *result;

    MCT_debugMsg("MCT_packageElectrodeStateAndMarkAsStale(...) - Converting state: \n  %s\n", stateStr);

    if (state == NULL)  {
        mexErrMsgTxt("MCT_packageElectrodeStateAndMarkAsStale - The state argument must not be NULL");
    }

    EnterCriticalSection(MCT_criticalSectionPtr);

    result = mxCreateStructMatrix(1, 1, MCT_nFieldNamesInMatlabStruct, MCT_mxFieldNames);
    mxSetField(result, 0, "ID", MCT_packageElectrodeID(state->ID));
    mxSetField(result, 0, "OperatingMode", mxCreateString(MCTG_MODE_NAMES[state->uOperatingMode]));
    mxSetField(result, 0, "ScaledOutSignal", mxCreateString(MCT_getScaledOutSignalShortName(state)));
    mxSetField(result, 0, "Alpha", mxCreateDoubleScalar(state->dAlpha));
    mxSetField(result, 0, "ScaleFactor", mxCreateDoubleScalar(state->dScaleFactor));
    mxSetField(result, 0, "ScaleFactorUnits", mxCreateString(MCT_getScaleFactorUnitsString(state)));//FIND_ME
    mxSetField(result, 0, "LPFCutoff", mxCreateDoubleScalar(state->dLPFCutoff));
    mxSetField(result, 0, "MembraneCap", mxCreateDoubleScalar(state->dMembraneCap));
    mxSetField(result, 0, "ExtCmdSens", mxCreateDoubleScalar(state->dExtCmdSens));
    mxSetField(result, 0, "RawOutSignal", mxCreateString("NOT_YET_IMPLEMENTED"));//mxCreateString(MCTG_OUT_GLDR_SHORT_NAMES[state->uRawOutSignal]));
    mxSetField(result, 0, "RawScaleFactor", mxCreateDoubleScalar(state->dRawScaleFactor));
    mxSetField(result, 0, "RawScaleFactorUnits", mxCreateString("NOT_YET_IMPLEMENTED"));//mxCreateString(MCT_SCALE_UNITS[state->uRawScaleFactorUnits]));
    mxSetField(result, 0, "HardwareType", mxCreateString(MCTG_HW_TYPE_NAMES[state->uHardwareType]));
    mxSetField(result, 0, "SecondaryAlpha", mxCreateDoubleScalar(state->dSecondaryAlpha));
    mxSetField(result, 0, "SecondaryLPFCutoff", mxCreateDoubleScalar(state->dSecondaryLPFCutoff));
    mxSetField(result, 0, "AppVersion", mxCreateString(state->szAppVersion));
    mxSetField(result, 0, "FirmwareVersion", mxCreateString(state->szFirmwareVersion));
    mxSetField(result, 0, "DSPVersion", mxCreateString(state->szDSPVersion));
    mxSetField(result, 0, "SerialNumber", mxCreateString(state->szSerialNumber));
    mxSetField(result, 0, "Age", mxCreateDoubleScalar(MCT_ticksToSeconds(state->refreshTickCount)));
    if (state->uHardwareType == MCTG_HW_TYPE_MC700A)
    {
        MCTG_Unpack700ASignalIDs(state->ID, &uComPortID, &uAxoBusID, &uChannelID);
        mxSetField(result, 0, "ComPortID", mxCreateDoubleScalar(uComPortID));
        mxSetField(result, 0, "AxoBusID", mxCreateDoubleScalar(uAxoBusID));
        mxSetField(result, 0, "ChannelID", mxCreateDoubleScalar(uChannelID));
        mxSetField(result, 0, "SerialNum", mxCreateDoubleScalar(0));  // Not used for 700A
    }
    else if (state->uHardwareType == MCTG_HW_TYPE_MC700B)
    {
        MCTG_Unpack700BSignalIDs(state->ID, &uSerialNum, &uChannelID);
        mxSetField(result, 0, "ComPortID", mxCreateDoubleScalar(0));  // Not used for 700B
        mxSetField(result, 0, "AxoBusID", mxCreateDoubleScalar(0));  // Not used for 700B
        mxSetField(result, 0, "ChannelID", mxCreateDoubleScalar(uChannelID));
        mxSetField(result, 0, "SerialNum", mxCreateDoubleScalar(uSerialNum));
    }

    MCT_debugMsg("Created mxArray struct from @%p in @%p.\n", state, result);
    
    state->isFresh = false;  // Once the electrode state is read out, don't want to read it out again

    LeaveCriticalSection(MCT_criticalSectionPtr);

    return result;
}

// Reads the contents of MCT_freshKnownElectrodeIDs into a Matlab array,
// then records that they are no longer "fresh"
mxArray* MCT_collectAllElectrodeIDs()  {
    EnterCriticalSection(MCT_criticalSectionPtr);
    mxArray* result = mxCreateDoubleMatrix(1, MCT_N_FRESH_KNOWN_ELECTRODE_IDS, mxREAL);
    double* elementPtr = (double*)mxGetPr(result);
    for (size_t i=0; i<MCT_N_FRESH_KNOWN_ELECTRODE_IDS; ++i)  {
        *elementPtr=(double)MCT_freshKnownElectrodeIDs[i];
        ++elementPtr;
    }
    MCT_N_FRESH_KNOWN_ELECTRODE_IDS = 0 ;  // Now that we've read them, they're not fresh
    LeaveCriticalSection(MCT_criticalSectionPtr);
    return result;
}

// Attempt to collect the electrode state, but only check once
mxArray* MCT_collectElectrodeState(LPARAM electrodeID)  {
    mxArray* result;
    LPARAM electrodeIndex = MCT_findSlotHoldingElectrodeState(electrodeID);
    if (electrodeIndex >= 0)  {
		result=MCT_packageElectrodeStateAndMarkAsStale(&MCT_electrodeStateSlots[electrodeIndex]);
    }
    else  {
        result=mxCreateDoubleMatrix(0, 0, mxREAL);  // return empty matrix
    }
    return result;
}

// Attempt to collect the electrode state, trying multiple times if needed.
mxArray* MCT_waitAndCollectElectrodeState(LPARAM electrodeID)  {
    mxArray* result;
    const int maxNumberOfSleeps=20;
    const int sleepDuration=50;  // ms
    bool didGetResponse=false;
    for (int i=0; i<maxNumberOfSleeps; ++i)  {
        Sleep(sleepDuration);
        LPARAM electrodeIndex = MCT_findSlotHoldingElectrodeState(electrodeID);
        if (electrodeIndex >= 0)  {
            didGetResponse=true;
            result=MCT_packageElectrodeStateAndMarkAsStale(&MCT_electrodeStateSlots[electrodeIndex]);
            break;
        }
    }
    if (!didGetResponse)  {
        result=mxCreateDoubleMatrix(0, 0, mxREAL);  // return empty matrix
    }
    return result;
}


/**
* @brief Standard Matlab Mex file entry point.
* @see \htmlonly <a href="../../../resources/MulticlampTelegraph.m">MulticlampTelegraph.m</a> \endhtmlonly for documentation.
* @arg <tt>nlhs</tt> - The number of left-hand-side arguments.
* @arg <tt>plhs</tt> - The left-hand-side arguments.
* @arg <tt>nrhs</tt> - The number of right-hand-side arguments.
* @arg <tt>prhs</tt> - The right-hand-side arguments.
*/
void mexFunction(int nlhs, mxArray** plhs, int nrhs, mxArray** prhs)
{
    //i and j increment as we consume left/right hand side arguments.
    //k, h, and count may be used as necessary in handling a given command (make sure to locally initialize them).
    //electrodeIndex is used as a place to store the output of a MCT_findSlotHoldingElectrodeState look-up.
    //int electrodeIndex;
    int i, j;
    char* command;
    //mxArray* tempMXArrayPtr;  //Initialize locally, as usual. Clean up when done.
    //unsigned int uComPortID, uAxoBusID, uChannelID, uSerialNum;
    //LPARAM electrodeID;
    int comPortRHSIndex, axoBusRHSIndex, channelIDRHSIndex, serialNumberRHSIndex ;
    int effectiveNLHS;

    effectiveNLHS=max(nlhs,1);  // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned
    //mexAtExit(MCT_stop);  // Register the stop hook, so it's executed when the mex file is cleared. (moved into MCT_start() so doesn't get called quite as much)
    //MCT_start();  // does nothing if already started

    j = 0;  // the "current" LHS index
    for (i = 0; i < nrhs; ++i)  // i is the "current" RHS index
    {
        command = mxArrayToString(prhs[i]);

        MCT_debugMsg("mexFunction(...) - Processing command: '%s'...\n", command);

        if (_strcmpi(command, "start") == 0)  {
            MCT_start();  // does nothing if already started
        }
        //else if (_strcmpi(command, "requestAllElectrodeIDs") == 0)  {
        //    MCT_start();  // does nothing if already started
        //    MCT_requestAllElectrodeIDs();
        //}
        //else if (_strcmpi(command, "collectAllElectrodeIDs") == 0)
        //{
        //    MCT_start();  // does nothing if already started
        //    if (j < effectiveNLHS)
        //    {
        //        plhs[j] = MCT_collectAllElectrodeIDs();
        //        ++j;
        //    }
        //}
        else if (_strcmpi(command, "getAllElectrodeIDs") == 0)
        {
            if (j < effectiveNLHS)
            {
                MCT_start();  // does nothing if already started
                MCT_requestAllElectrodeIDs();
                Sleep(500);
                plhs[j] = MCT_collectAllElectrodeIDs();
                ++j;
            }
        }
        //else if (_strcmpi(command, "requestElectrodeState") == 0)
        //{
        //    MCT_start();  // does nothing if already started
        //    ++i;  // This command needs an argument, so bump the counter
        //    if (i>=nrhs)
        //    {
        //        mexErrMsgTxt("requestElectrodeState requires another argument");
        //        return;  //mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
        //    }
        //    LPARAM electrodeID = MCT_unpackageElectrodeID(prhs[i]);
        //    MCT_requestElectrodeState(electrodeID);
        //}
        //else if (_strcmpi(command, "collectElectrodeState") == 0)
        //{
        //    MCT_start();  // does nothing if already started

        //    ++i;  // This command needs an argument, so bump the counter
        //    if (i>=nrhs)  {
        //        mexErrMsgTxt("collectElectrodeState requires another argument");
        //    }

        //    LPARAM electrodeID=MCT_unpackageElectrodeID(prhs[i]);
        //    if (j < effectiveNLHS)  {
        //        plhs[j]=MCT_collectElectrodeState(electrodeID);
        //        ++j;
        //    }
        //}
        else if (_strcmpi(command, "getElectrodeState") == 0)  {
            ++i;  // This command needs an argument, so bump the counter
            if (i>=nrhs)  {
                mexErrMsgTxt("requestElectrodeState requires another argument");
            }
            LPARAM electrodeID = MCT_unpackageElectrodeID(prhs[i]);
            if (j < effectiveNLHS)  {
                MCT_start();  // does nothing if already started
                MCT_requestElectrodeState(electrodeID);  // This calls SwitchToThread() at end.  Is that enough?
                plhs[j]=MCT_waitAndCollectElectrodeState(electrodeID);
                ++j;
            }
        }
        //else if (_strcmpi(command, "getElectrode") == 0)
        //{
        //    MCT_start();  // does nothing if already started
        //    if (i >= nrhs - 1)
        //        mexErrMsgTxt("Invalid number of arguments. 'getState' must be followed by an ID");
        //    // Don't need this anymore
        //    //if (j >= effectiveNLHS)
        //    //   mexErrMsgTxt("Not enough return arguments available.");

        //    MCT_debugMsg("mexFunction() - Entering critical section...\n");
        //    EnterCriticalSection(MCT_criticalSectionPtr);

        //    ++i;  // This command needs an argument, so bump the counter
        //    if (i>=nrhs)
        //    {
        //        MCT_debugMsg("mexFunction() - Leaving critical section...\n");
        //        LeaveCriticalSection(MCT_criticalSectionPtr);
        //        mexErrMsgTxt("getElectrode requires another argument");
        //        return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
        //    }
        //    electrodeID=MCT_unpackageElectrodeID(prhs[i]);
        //    electrodeIndex = MCT_findSlotHoldingElectrodeState(electrodeID);
        //    if (electrodeIndex < 0)
        //    {
        //        MCT_debugMsg("mexFunction() - Leaving critical section...\n");
        //        LeaveCriticalSection(MCT_criticalSectionPtr);
        //        mexErrMsgTxt("No electrode found with requested ID");
        //        return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
        //    }

        //    if (j < effectiveNLHS)
        //    {
        //        plhs[j]=MCT_packageElectrodeStateAndMarkAsStale(&MCT_electrodeStateSlots[electrodeIndex]);
        //        ++j;
        //    }

        //    MCT_debugMsg("mexFunction() - Leaving critical section...\n");
        //    LeaveCriticalSection(MCT_criticalSectionPtr);
        //}
        //else if (_strcmpi(command, "getAllElectrodes") == 0)
        //{
        //    MCT_start();  // does nothing if already started
        //    if (j < effectiveNLHS)
        //    {
        //        MCT_debugMsg("mexFunction() - Entering critical section...\n");
        //        EnterCriticalSection(MCT_criticalSectionPtr);

        //        //Initialize a correctly sized cell array.
        //        count = 0;
        //        for (k = 0; k < MCT_N_ELECTRODE_STATES; k++)
        //        {
        //            if (MCT_electrodeStateSlots[k].isFresh)
        //                count++;
        //        }

        //        //MCT_mxDims[0] = count;
        //        //MCT_mxDims[1] = 1;
        //        plhs[j] = mxCreateCellMatrix(count, 1);
        //        //Populate the cell array.
        //        h = 0;
        //        for (k = 0; k < MCT_N_ELECTRODE_STATES; k++)
        //        {
        //            if (MCT_electrodeStateSlots[k].isFresh)
        //            {
        //                //tempMXArrayPtr = NULL;
        //                tempMXArrayPtr=MCT_packageElectrodeStateAndMarkAsStale(&MCT_electrodeStateSlots[k]);
        //                mxSetCell(plhs[j], (mwIndex)h, tempMXArrayPtr);
        //                ++h;
        //            }
        //        }

        //        MCT_debugMsg("mexFunction() - Leaving critical section...\n");
        //        LeaveCriticalSection(MCT_criticalSectionPtr);
        //        ++j;
        //    }
        //}
        //else if (_strcmpi(command, "requestTelegraph") == 0)
        //{
        //    MCT_start();  // does nothing if already started
        //    ++i;  // This command needs an argument, so bump the counter
        //    if (i>=nrhs)
        //    {
        //        mexErrMsgTxt("requestTelegraph requires another argument");
        //        return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
        //    }
        //    MCT_requestElectrodeState(MCT_unpackageElectrodeID(prhs[i]));
        //}
        //else if (_strcmpi(command, "displayAllElectrodes") == 0)  {
        //    MCT_start();  // does nothing if already started
        //    MCT_displayElectrodes();
        //}
        else if (_strcmpi(command, "stop") == 0)  {
            MCT_stop();  // does nothing if already stopped
        }
        else if (_strcmpi(command, "getIsRunning") == 0)  {
            if (j < effectiveNLHS)  {
                plhs[j] = mxCreateLogicalScalar(MCT_isRunning);
                ++j;
            }
        }
        else if (_strcmpi(command, "version") == 0)  {
            MCT_printMsg("MulticlampTelegraph Version: %s\n", MCT_VERSION);
        }
        //else if (_strcmpi(command, "openConnection") == 0)  {
        //    MCT_start();  // does nothing if already started
        //    ++i;  // This command needs an argument, so bump the counter
        //    if (i>=nrhs)
        //    {
        //        mexErrMsgTxt("openConnection requires another argument");
        //        return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
        //    }
        //    electrodeID=MCT_unpackageElectrodeID(prhs[i]);
        //    MCT_openConnection(electrodeID);
        //}
        //else if (_strcmpi(command, "closeConnection") == 0)
        //{
        //    MCT_start();  // does nothing if already started
        //    ++i;  // This command needs an argument, so bump the counter
        //    if (i>=nrhs)
        //    {
        //        mexErrMsgTxt("closeConnection requires another argument");
        //        return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
        //    }
        //    electrodeID=MCT_unpackageElectrodeID(prhs[i]);
        //    MCT_closeConnection(electrodeID);
        //}
        else if (_strcmpi(command, "get700AID") == 0)
        {
            //MCT_start();  // does nothing if already started

            // This command needs three arguments, so bump the counter thrice.  (Yeah, that's right.  "Thrice".)
            ++i;  
            comPortRHSIndex=i;
            ++i;
            axoBusRHSIndex=i;
            ++i;
            channelIDRHSIndex=i;

            // Make sure there are enough args
            if (i>=nrhs)
            {
                mexErrMsgTxt("get700AID requires three additional arguments");
                return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
            }

            // Make sure args are all the right type
            if (!(mxIsUint32(prhs[comPortRHSIndex]) && mxIsUint32(prhs[axoBusRHSIndex]) && mxIsUint32(prhs[channelIDRHSIndex])))
                mexErrMsgTxt("uComPortID, uAxoBusID, and uChannelID must be of type uint32.");

            // get the args into plain-old vars
            unsigned int uComPortID = (unsigned int) *((UINT32*)mxGetData(prhs[comPortRHSIndex]));
            unsigned int uAxoBusID = (unsigned int) *((UINT32*)mxGetData(prhs[axoBusRHSIndex]));
            unsigned int uChannelID = (unsigned int) *((UINT32*)mxGetData(prhs[channelIDRHSIndex]));

            // Get the 700A ID, stuff it into a return argument
            if (j < effectiveNLHS)
            {
                LPARAM electrodeID = MCTG_Pack700ASignalIDs(uComPortID, uAxoBusID, uChannelID);
                plhs[j] = MCT_packageElectrodeID(electrodeID);
                //plhs[j] = mxCreateDoubleScalar((double)MCTG_Pack700ASignalIDs(uComPortID, uAxoBusID, uChannelID));
                ++j;
            }
        }
        else if (_strcmpi(command, "get700BID") == 0)
        {
            //MCT_start();  // does nothing if already started

            // This command needs two arguments, so bump the counter twice.
            ++i;  
            serialNumberRHSIndex=i;
            ++i;
            channelIDRHSIndex=i;

            // Make sure there are enough args
            if (i>=nrhs)
            {
                mexErrMsgTxt("get700BID requires two additional arguments");
                return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
            }

            if (!(mxIsUint32(prhs[serialNumberRHSIndex]) && mxIsUint32(prhs[channelIDRHSIndex])))
                mexErrMsgTxt("uSerialNum and uChannelID must be of type uint32.");

            unsigned int uSerialNum = (unsigned int) *((UINT32*)mxGetData(prhs[serialNumberRHSIndex]));
            unsigned int uChannelID = (unsigned int) *((UINT32*)mxGetData(prhs[channelIDRHSIndex]));

            if (j < effectiveNLHS)
            {
                LPARAM electrodeID = MCTG_Pack700BSignalIDs(uSerialNum, uChannelID) ;
                plhs[j] = MCT_packageElectrodeID(electrodeID);
                //plhs[j] = mxCreateDoubleScalar((double)MCTG_Pack700BSignalIDs(uSerialNum, uChannelID));
                ++j;
            }
        }
        //else if (_strcmpi(command, "getScaledGain") == 0)
        //{
        //    MCT_start();  // does nothing if already started

        //    ++i;  // This command needs an argument, so bump the counter
        //    if (i>=nrhs)
        //    {
        //        mexErrMsgTxt("requestTelegraph requires another argument");
        //        return;
        //    }

        //    electrodeID=MCT_unpackageElectrodeID(prhs[i]);
        //    electrodeIndex = MCT_findSlotHoldingElectrodeState(electrodeID);
        //    if (electrodeIndex < 0)
        //    {
        //        mexErrMsgTxt("No electrode found with requested ID");
        //        return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
        //    }

        //    if (j < effectiveNLHS)
        //    {
        //        double scaledGain = MCT_getScaledGain(&MCT_electrodeStateSlots[electrodeIndex]);
        //        plhs[j] = mxCreateDoubleScalar(scaledGain);
        //        ++j;
        //    }
        //}
        //else if (_strcmpi(command, "getMode") == 0)
        //{
        //    MCT_start();  // does nothing if already started

        //    ++i;  // This command needs an argument, so bump the counter
        //    if (i>=nrhs)
        //    {
        //        mexErrMsgTxt("getMode requires another argument");
        //        return;
        //    }

        //    electrodeID=MCT_mxArrayToID(prhs[i]);
        //    electrodeIndex = MCT_findSlotHoldingElectrodeState(electrodeID);
        //    if (electrodeIndex < 0)
        //    {
        //        mexErrMsgTxt("No electrode found with requested ID");
        //        return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
        //    }

        //    if (j < effectiveNLHS)
        //    {
        //        plhs[j] = mxCreateString(MCTG_MODE_NAMES[MCT_electrodeStateSlots[electrodeIndex].uOperatingMode]);
        //        ++j;
        //    }
        //}
        //else if (_strcmpi(command, "getScaledUnits") == 0)
        //{
        //    MCT_start();  // does nothing if already started

        //    ++i;  // This command needs an argument, so bump the counter
        //    if (i>=nrhs)
        //    {
        //        mexErrMsgTxt("getMode requires another argument");
        //        return;
        //    }

        //    electrodeID=MCT_mxArrayToID(prhs[i]);
        //    electrodeIndex = MCT_findSlotHoldingElectrodeState(electrodeID);
        //    if (electrodeIndex < 0)
        //    {
        //        mexErrMsgTxt("No electrode found with requested ID");
        //        return;//mexErrMsgTxt terminates execution anyway, this is just here to make that obvious.
        //    }

        //    if (j < effectiveNLHS)
        //    {
        //        char* scaledUnits = MCT_getScaledUnits(&MCT_electrodeStateSlots[electrodeIndex]);  // returns a char * to a string literal, no need to free()
        //        plhs[j] = mxCreateString(scaledUnits);
        //        ++j;
        //    }
        //}
        else
        {
            MCT_errorMsg("Unrecognized command: '%s'\n", command);
            mexErrMsgTxt("Unrecognized command.");
        }
    }

    // Matlab catches it if you fail to set one of the plhs elements, so no need for this below
    /*
    // If some LHS vars have not been assigned, throw an error
    if (j<effectiveNLHS)
    {
    mexErrMsgIdAndTxt("MATLAB:mexfunction:inputOutputMismatch",
    "Too many output arguments.\n");
    }
    */

    return;
}
#else
/**********************************
*     COMMAND-LINE INTERFACE     *
**********************************/

/**
* @brief Standard C-language executable entry point.
* @arg <tt>argc</tt> - The number of command-line arguments.
* @arg <tt>argv</tt> - The command-line arguments.
*/
int main(int argc, char** argv)
{
    int i = 0;
    DWORD sleepTime = 15000;

    //Start-up (initialize state array, start message processing thread, create window, broadcast for Multiclamp instances, etc).
    MCT_start();

    for (i = 0; i < 3; ++i)
    {   
        //Broadcast a request for Multiclamp Commanders to identify themselves.
        MCT_requestAllElectrodeIDs();

        //Wait a while, for broadcasts to recieve responses, and to dump debug messages to see what happened.
        printf("%s:main(...) - Sleeping for %3.2f seconds...\n", argv[0], ((unsigned int)sleepTime) / 1000.0);
        Sleep(sleepTime);
        printf("%s:main(...) - Waking up.\n", argv[0]);
    }

    //Broadcast a request for Multiclamp Commanders to identify themselves.
    MCT_requestAllElectrodeIDs();

    //Okay, now shut down cleanly.
    MCT_stop();

    return 0;
}
#endif
