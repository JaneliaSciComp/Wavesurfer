% MulticlampTelegraph - Interface to the Axon Multiclamp software.
%
% SYNTAX
%  MulticlampTelegraph(command)
%  result = MulticlampTelegraph(command)
%  MulticlampTelegraph(command, ...)
%  [result, ...] = MulticlampTelegraph(command, ...)
%    command - A string, indicating the action to be performed, see below.
%              Multiple actions may be performed, per mex call.
%    result - The return value, if any, from the corresponding command.
%             Multiple results may be returned, if multiple commands are issued.
%
% USAGE
%  Commands:
%   start - Set up and start the messaging system.  Typically, consumers
%           don't have to call this directly, b/c all the commands do it as needed.
%   getElectrodeIDs - Return the electrode IDs of all electrodes from
%                     all Multiclamp Commanders, as a uint32 row vector.   
%                     Returns [] if unable to obtain.
%   getElectrodeState - Returns the state of a single electrode.
%                       Args: The ID of the electrode.
%                       Returns: The electrode state, or [] if unable
%                                to get it.
%   get700AID - Returns the unique ID associated with a specified 700A electrode.
%               Args: uComPortID, uAxoBusID, uChannelID (each a uint32
%                     scalar)
%               Returns: electrode ID (uint32 scalar)
%   get700BID - Returns the unique ID associated with a specified 700B electrode.
%               Args: uSerialNum, uChannelID (each a uint32 scalar)
%               Returns: electrode ID (uint32 scalar)
%   stop - Shuts down the messaging system and releases all dynamic memory (this is the same effect as `clear mex` would have).
%   version - Prints the MulticlampTelegraph version number to the screen.
%   getIsRunning - Whether or not the messaging system is currently
%                  running.  (This is orthogonal to whether any instances
%                  of MCC are running.)
%
%  Structure:
%   .ID - A unique ID, used to address the electrode (uint32).
%   .OperatingMode - A string representing the current mode.
%   .ScaledOutSignal - The name of the scaled (primary) output signal.
%   .Alpha - Gain of scaled (primary) output.
%   .ScaleFactor - Scale factor of scaled (primary) output.
%   .ScaleFactorUnits - A string representing the scale factor of scaled (primary) output
%   .LPFCutoff - Lowpass filter cutoff frequency [Hz] of scaled (primary) output.
%   .MembraneCap - Membrane capacitance [F].
%   .ExtCmdSens - External command sensitivity.
%   .RawOutSignal - A string representing the signal identifier of raw (secondary) output.
%   .RawScaleFactor - Gain scale factor of raw (secondary) output.
%   .RawScaleFactorUnits - A string representing the scale factor units of raw (secondary) output.
%   .HardwareType - Hardware type identifier: 'MCTG_HW_TYPE_MC700A' or 'MCTG_HW_TYPE_MC700B'
%   .SecondaryAlpha - Gain of raw (secondary) output.
%   .SecondaryLPFCutoff - Lowpass filter cutoff frequency [Hz] of raw (secondary) output.
%   .AppVersion - Application version of Multiclamp Commander 2.x.
%   .FirmwareVersion - Firmware version of Multiclamp 700B.
%   .DSPVersion - DSP version of Multiclamp 700B.
%   .SerialNumber - Serial number of Multiclamp 700B.
%   .Age - The elapsed time since this structure has been updated, in seconds.
%   .ComPortID - The COM port ID. Only applies to 700A.
%   .AxoBusID - The AXOBUS ID. Only applies to 700A.
%   .ChannelID - The Channel ID.
%   .SerialNum - The serial number. Only applies to 700B.
%
% NOTES
%  See MulticlampTelegraph.cpp, and its associated documentation, for more information.
%
% CHANGES
%
% Created 10/26/08 Tim O'Connor
% Copyright - Cold Spring Harbor Laboratories/Howard Hughes Medical Institute 2008
% Modified 01/2015 Adam L. Taylor
% Copyright - Howard Hughes Medical Institute 2015



%  Former Commands:
%   broadcast - Send a request for all Multiclamp Commanders to identify themselves and their electrodes.
%   getElectrode - Gets the state of the electrode.
%                  Args: The ID of the electrode.
%                  Returns: A struct representing the electrode.
%   getAllElectrodes - Retrieves all known states.
%                      Returns a cell array of state structures.
%   get700AID - Returns the unique ID associated with a specified 700A electrode.
%               Args: uComPortID, uAxoBusID, uChannelID
%               All arguments must be of type uint16.
%   get700BID - Returns the unique ID associated with a specified 700B electrode.
%               Args: uSerialNum, uChannelID
%               All arguments must be of type uint16.
%   requestTelegraph - Requests that the Multiclamp Commander send an updated telegraph for the specified ID.
%                      Args: The ID of the electrode.
%   displayAllElectrodes - Prints all known states to the screen.
%   openConnection - Opens a connection to a Multiclamp Commander, to recieve automatic change notifications (ie. subscribe).
%                    Args: The ID of the electrode.
%   closeConnection - Closes a connection to a Multiclamp Commander, to stop recieving automatic change notifications (ie. unsubscribe).
%                     Args: The ID of the electrode.
%   stop - Shuts down the messaging system and releases all dynamic memory (this is the same effect as `clear mex` would have).
%   version - Prints the MulticlampTelegraph version number to the screen.

