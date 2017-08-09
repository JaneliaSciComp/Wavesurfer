% WaveSurfer stuff should all be on the path already

ws.clear() ;

%[wsModel,wsController] = wavesurfer('repo/+ws/+examples/Machine_Data_File_rasterTreadMill.m') ;
[wsModel,wsController] = wavesurfer() ;

% delete all pre-existing channels
wsModel.IsAIChannelMarkedForDeletion(:) = true ;
wsModel.deleteMarkedAIChannels() ;
wsModel.IsDIChannelMarkedForDeletion(:) = true ;
wsModel.deleteMarkedDIChannels() ;
wsModel.IsAOChannelMarkedForDeletion(:) = true ;
wsModel.deleteMarkedAOChannels() ;
wsModel.IsDOChannelMarkedForDeletion(:) = true ;
wsModel.deleteMarkedDOChannels() ;

% add electrode AI channel
wsModel.addAIChannel() ;
channelIndex = wsModel.NAIChannels ;
wsModel.setSingleAIChannelName(channelIndex,'electrode') ;
wsModel.setSingleAIChannelTerminalID(channelIndex,0) ;

% add velocity AI channel
wsModel.addAIChannel() ;
channelIndex = wsModel.NAIChannels ;
wsModel.setSingleAIChannelName(channelIndex,'velocity') ;
wsModel.setSingleAIChannelTerminalID(channelIndex,1) ;

% add photodiode DI channel
wsModel.addDIChannel() ;
channelIndex = wsModel.NDIChannels ;
wsModel.setSingleDIChannelName(channelIndex,'photodiode') ;
wsModel.setSingleDIChannelTerminalID(channelIndex,2) ;

% add laser DI channel
wsModel.addDIChannel() ;
channelIndex = wsModel.NDIChannels ;
wsModel.setSingleDIChannelName(channelIndex,'laser') ;
wsModel.setSingleDIChannelTerminalID(channelIndex,3) ;

% add electrode AO channel
wsModel.addAOChannel() ;
channelIndex = wsModel.NAOChannels ;
wsModel.setSingleAOChannelName(channelIndex,'electrodeOut') ;
wsModel.setSingleAOChannelTerminalID(channelIndex,0) ;

% add velocity AO channel
wsModel.addAOChannel() ;
channelIndex = wsModel.NAOChannels ;
wsModel.setSingleAOChannelName(channelIndex,'velocityOut') ;
wsModel.setSingleAOChannelTerminalID(channelIndex,1) ;

% add photodiode DO channel
wsModel.addDOChannel() ;
channelIndex = wsModel.NDOChannels ;
wsModel.setSingleDOChannelName(channelIndex,'photodiodeOut') ;
wsModel.setSingleDOChannelTerminalID(channelIndex,0) ;

% add laser DO channel
wsModel.addDOChannel() ;
channelIndex = wsModel.NDOChannels ;
wsModel.setSingleDOChannelName(channelIndex,'laserOut') ;
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
wsModel.IsStimulationEnabled = true ;
wsModel.IsDisplayEnabled = true ;
wsModel.IsOKToOverwriteDataFile=true ;

wsModel.AreSweepsContinuous = true ;
wsModel.AIChannelScales = [0.001 0.01] ;  % electrode, velocity
wsModel.AIChannelUnits = {'mV' 'cm/s'} ;  % electrode, velocity
wsModel.IsDOChannelTimed = [true false] ;

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

wsModel.UserClassName = 'ws.examples.RasterTreadMill' ;

%scope = wsModel.Display.Scopes{1} ;
%scope.YLim = [-55 +25] ;
wsModel.setYLimitsForSingleAIChannel(1, [-75 +25]) ;
wsModel.setYLimitsForSingleAIChannel(2, [-10 +60]) ;

wsModel.XSpan=10 ;  % s




%wsController.loadConfigFileForRealsSrsly('ben2adam/treadmill/rasterTreadMillTest4.cfg');

