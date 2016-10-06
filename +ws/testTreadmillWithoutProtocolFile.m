% WaveSurfer stuff should all be on the path already

ws.clear() ;

%[wsModel,wsController] = wavesurfer('repo/+ws/+examples/Machine_Data_File_rasterTreadMill.m') ;
[wsModel,wsController] = wavesurfer() ;

% delete all pre-existing channels
wsModel.Acquisition.IsAnalogChannelMarkedForDeletion(:) = true ;
wsModel.deleteMarkedAIChannels() ;
wsModel.Acquisition.IsDigitalChannelMarkedForDeletion(:) = true ;
wsModel.deleteMarkedDIChannels() ;
wsModel.Stimulation.IsAnalogChannelMarkedForDeletion(:) = true ;
wsModel.deleteMarkedAOChannels() ;
wsModel.Stimulation.IsDigitalChannelMarkedForDeletion(:) = true ;
wsModel.deleteMarkedDOChannels() ;

% add electrode AI channel
wsModel.Acquisition.addAnalogChannel() ;
channelIndex = wsModel.Acquisition.NAnalogChannels ;
wsModel.Acquisition.setSingleAnalogChannelName(channelIndex,'electrode') ;
wsModel.Acquisition.setSingleAnalogTerminalID(channelIndex,0) ;

% add velocity AI channel
wsModel.Acquisition.addAnalogChannel() ;
channelIndex = wsModel.Acquisition.NAnalogChannels ;
wsModel.Acquisition.setSingleAnalogChannelName(channelIndex,'velocity') ;
wsModel.Acquisition.setSingleAnalogTerminalID(channelIndex,1) ;

% add photodiode DI channel
wsModel.addDIChannel() ;
channelIndex = wsModel.Acquisition.NDigitalChannels ;
wsModel.Acquisition.setSingleDigitalChannelName(channelIndex,'photodiode') ;
wsModel.setSingleDIChannelTerminalID(channelIndex,2) ;

% add laser DI channel
wsModel.addDIChannel() ;
channelIndex = wsModel.Acquisition.NDigitalChannels ;
wsModel.Acquisition.setSingleDigitalChannelName(channelIndex,'laser') ;
wsModel.setSingleDIChannelTerminalID(channelIndex,3) ;

% add electrode AO channel
wsModel.Stimulation.addAnalogChannel() ;
channelIndex = wsModel.Stimulation.NAnalogChannels ;
wsModel.Stimulation.setSingleAnalogChannelName(channelIndex,'electrodeOut') ;
wsModel.Stimulation.setSingleAnalogTerminalID(channelIndex,0) ;

% add velocity AO channel
wsModel.Stimulation.addAnalogChannel() ;
channelIndex = wsModel.Stimulation.NAnalogChannels ;
wsModel.Stimulation.setSingleAnalogChannelName(channelIndex,'velocityOut') ;
wsModel.Stimulation.setSingleAnalogTerminalID(channelIndex,1) ;

% add photodiode DO channel
wsModel.addDOChannel() ;
channelIndex = wsModel.Stimulation.NDigitalChannels ;
wsModel.Stimulation.setSingleDigitalChannelName(channelIndex,'photodiodeOut') ;
wsModel.setSingleDOChannelTerminalID(channelIndex,0) ;

% add laser DO channel
wsModel.addDOChannel() ;
channelIndex = wsModel.Stimulation.NDigitalChannels ;
wsModel.Stimulation.setSingleDigitalChannelName(channelIndex,'laserOut') ;
wsModel.setSingleDOChannelTerminalID(channelIndex,1) ;


% % add electrode AO channel
% electrodeAOChannel = wsModel.Stimulation.addAnalogChannel() ;
% electrodeAOChannel.Name = 'electrodeOut' ;
% electrodeAOChannel.TerminalID = 0 ;
% 
% % add velocity AO channel
% velocityAOChannel = wsModel.Stimulation.addAnalogChannel() ;
% velocityAOChannel.Name = 'velocityOut' ;
% velocityAOChannel.TerminalID = 1 ;
% 
% % add photodiode DO channel
% photodiodeDOChannel = wsModel.Stimulation.addDigitalChannel() ;
% photodiodeDOChannel.Name = 'photodiodeOut' ;
% photodiodeDOChannel.TerminalID = 0 ;
% 
% % add laser DO channel
% laserDOChannel = wsModel.Stimulation.addDigitalChannel() ;
% laserDOChannel.Name = 'laserOut' ;
% laserDOChannel.TerminalID = 1 ;

% configure the rest of the stuff
wsModel.Stimulation.IsEnabled = true ;
wsModel.Display.IsEnabled = true ;
wsModel.Logging.IsOKToOverwrite=true ;

wsModel.AreSweepsContinuous = true ;
wsModel.Acquisition.AnalogChannelScales = [0.001 0.01] ;  % electrode, velocity
wsModel.Acquisition.AnalogChannelUnits = {'mV' 'cm/s'} ;  % electrode, velocity
wsModel.Stimulation.IsDigitalChannelTimed = [true false] ;

wsModel.clearStimulusLibrary() ;  % clear out pre-defined stimuli

% stimulus1 = wsModel.Stimulation.StimulusLibrary.addNewStimulus('File');
% stimulus1.Name='Electrode Stimulus';
% stimulus1.Delay='0';
% stimulus1.Duration='1010';
% stimulus1.Amplitude='1';
% stimulus1.DCOffset='0';
% stimulus1.Delegate.FileName = 'treadmillWaveforms/electrodeStimulus.wav' ;

electrodeStimulusIndex = wsModel.addNewStimulus() ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', electrodeStimulusIndex, 'TypeString', 'File') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', electrodeStimulusIndex, 'Name', 'Electrode Stimulus') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', electrodeStimulusIndex, 'Delay', '0') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', electrodeStimulusIndex, 'Amplitude', '1') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', electrodeStimulusIndex, 'Duration', '1010') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', electrodeStimulusIndex, 'FileName', 'treadmillWaveforms/electrodeStimulus.wav') ;            

% stimulus2 = wsModel.Stimulation.StimulusLibrary.addNewStimulus('File');
% stimulus2.Name='Velocity Stimulus';
% stimulus2.Delay='0';
% stimulus2.Duration='1010';
% stimulus2.Amplitude='1';
% stimulus2.DCOffset='0';
% stimulus2.Delegate.FileName = 'treadmillWaveforms/velocityStimulus.wav' ;

velocityStimulusIndex = wsModel.addNewStimulus() ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', velocityStimulusIndex, 'TypeString', 'File') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', velocityStimulusIndex, 'Name', 'Velocity Stimulus') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', velocityStimulusIndex, 'Delay', '0') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', velocityStimulusIndex, 'Amplitude', '1') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', velocityStimulusIndex, 'Duration', '1010') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', velocityStimulusIndex, 'FileName', 'treadmillWaveforms/velocityStimulus.wav') ;            

% stimulus3 = wsModel.Stimulation.StimulusLibrary.addNewStimulus('File');
% stimulus3.Name='Photodiode Stimulus';
% stimulus3.Delay='0';
% stimulus3.Duration='1010';
% stimulus3.Amplitude='1';
% stimulus3.DCOffset='0';
% stimulus3.Delegate.FileName = 'treadmillWaveforms/photodiodeStimulus.wav' ;

photodiodeStimulusIndex = wsModel.addNewStimulus() ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', photodiodeStimulusIndex, 'TypeString', 'File') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', photodiodeStimulusIndex, 'Name', 'Photodiode Stimulus') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', photodiodeStimulusIndex, 'Delay', '0') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', photodiodeStimulusIndex, 'Amplitude', '1') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', photodiodeStimulusIndex, 'Duration', '1010') ;
wsModel.setStimulusLibraryItemProperty('ws.Stimulus', photodiodeStimulusIndex, 'FileName', 'treadmillWaveforms/photodiodeStimulus.wav') ;            

% stimulusMap1=wsModel.Stimulation.StimulusLibrary.addNewMap();
% stimulusMap1.Name = 'Christine' ;
% stimulusMap1.Duration = 1010 ;
% stimulusMap1.addBinding('electrodeOut' , stimulus1);
% stimulusMap1.addBinding('velocityOut'  , stimulus2);
% stimulusMap1.addBinding('photodiodeOut', stimulus3);

mapIndex = wsModel.addNewStimulusMap() ;
wsModel.setStimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Name', 'Christine') ;
wsModel.setStimulusLibraryItemProperty('ws.StimulusMap', mapIndex, 'Duration', 1010) ;
bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', 'electrodeOut') ;
wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', electrodeStimulusIndex) ;
bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', 'velocityOut') ;
wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', velocityStimulusIndex) ;
bindingIndex = wsModel.addBindingToStimulusLibraryItem('ws.StimulusMap', mapIndex) ;
wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'ChannelName', 'photodiodeOut') ;
wsModel.setStimulusLibraryItemBindingProperty('ws.StimulusMap', mapIndex, bindingIndex, 'IndexOfEachStimulusInLibrary', photodiodeStimulusIndex) ;

%Stimulation.StimulusLibrary.SelectedOutputable = stimulusMap1 ;
wsModel.setSelectedOutputableByIndex(1) ;  % should be the only one

wsModel.UserCodeManager.ClassName = 'ws.examples.RasterTreadMill' ;

%scope = wsModel.Display.Scopes{1} ;
%scope.YLim = [-55 +25] ;
wsModel.Display.setYLimitsForSingleAnalogChannel(1, [-75 +25]) ;
wsModel.Display.setYLimitsForSingleAnalogChannel(2, [-10 +60]) ;
%wsModel.Display.setYLimitsForSingleAnalogChannel(3, [-0.1 +1.1]) ;
%wsModel.Display.setYLimitsForSingleAnalogChannel(4, [-0.1 +1.1]) ;

wsModel.Display.XSpan=10 ;  % s




%wsController.loadConfigFileForRealsSrsly('ben2adam/treadmill/rasterTreadMillTest4.cfg');

