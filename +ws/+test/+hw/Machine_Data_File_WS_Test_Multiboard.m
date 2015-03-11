% Most Software Machine Data File

%% Wavesurfer

physicalInputChannelNames = {'Dev1/ai0' 'Dev1/ai1' 'Dev2/ai0' 'Dev2/ai1'} ;  % Cell array of strings, each string an NI physical channel name
inputChannelNames = {'Mon1' 'Mon2' 'Mon3' 'Mon4'}; % String cell array of channel identifiers. If left empty, default NI channel names will be used.

physicalOutputChannelNames = {'Dev1/ao0' 'Dev2/ao0'} ;  % Cell array of strings, each string an NI physical channel name
outputChannelNames = {'Cmd1' 'Cmd2'}; % String cell array of channel identifiers. If left empty, default NI channel names will be used.
%outputDigitalChannelIDs = []; % Array of DO channel numbers, e.g. 0:1.
%outputDigitalChannelNames = {}; %String cell array of channel identifiers. If left empty, default NI channel names will be used.

% % This part sets up a "trigger source" -- An internally-generated trigger.
% % In this case, it uses Counter 0 (CTR0) on the NI board.  By default, this
% % will be output as a TTL signal (using rising edges as the trigger) on
% % PFI12 (counter index+12)
triggerSource(1).Name = 'Trial Trigger'; % String specifying name of an Wavesurfer self trigger source.
triggerSource(1).DeviceName = 'Dev1'; % String specifying device name on which Wavesurfer self trigger is generated.
triggerSource(1).CounterID = 0;  % Which internal counter device will be used to generate this trigger output.

% This part sets up a "trigger source" -- An internally-generated trigger.
% In this case, it uses Counter 1 (CTR1) on the NI board.  By default, this
% will be output as a TTL signal (using rising edges as the trigger) on
% PFI13 (counter index+13)
triggerSource(2).Name = 'Internal Trigger'; % String specifying name of an Wavesurfer self trigger source.
triggerSource(2).DeviceName = 'Dev1'; % String specifying device name on which Wavesurfer self trigger is generated.
triggerSource(2).CounterID = 1;  % Which internal counter device will be used to generate this trigger output.

% This part sets up a "trigger destination"---Essentially, a thing so you
% can trigger off an externally-supplied TTL trigger.  In this case, the
% external trigger should be attached to PFI0, and rising edges will be
% interpreted as the triggering event.
triggerDestination(1).Name = 'External Trigger 1';
triggerDestination(1).DeviceName = 'Dev1';
triggerDestination(1).PFIID = 0; 
triggerDestination(1).Edge = 'Rising'; 

% This part sets up a "trigger destination"---Essentially, a thing so you
% can trigger off an externally-supplied TTL trigger.  In this case, the
% external trigger should be attached to PFI1, and rising edges will be
% interpreted as the triggering event.
triggerDestination(2).Name = 'External Trigger 2';
triggerDestination(2).DeviceName = 'Dev1';
triggerDestination(2).PFIID = 1; 
triggerDestination(2).Edge = 'Rising'; 

