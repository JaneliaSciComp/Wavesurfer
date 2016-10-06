function varargout = wavesurfer(varargin)
    %WAVESURFER  Launch WaveSurfer, an application for data acquisition.
    %
    %   "WAVESURFER", by itself, launches the WaveSurfer graphical user
    %   interface (GUI).
    %
    %   "WAVESURFER <protocolFileName>" launches the WaveSurfer GUI,
    %   opening the named protocol file on launch.
    %
    %   "WAVESURFER --debug" launches WaveSurfer in debugging mode.  This
    %   makes the satellite process windows visible instead of hidden.
    %
    %   "WAVESURFER --nogui" launches WaveSurfer without the graphical user
    %   interface.
    %      
    %   "wsModel = WAVESURFER()" returns an application object, wsModel.
    %   This may be useful for scripting or testing.
    %
    %   "[wsModel, wsController] = WAVESURFER()" also returns the
    %   controller object, wsController.  It is an error to use this form
    %   with the --nogui option.
    %
    %   Except where noted, most of the above forms can be combined in the
    %   usual standard ways.  So, for instance,
    %
    %     [wsModel, wsController] = WAVESURFER('my-protocol.cfg', '--debug')
    %
    %   does what you would expect.

    % Takes a while to start, so give some feedback
    fprintf('Starting WaveSurfer...');
    
    % Process arguments
    [wasProtocolOrMDFFileNameGivenAtCommandLine, protocolOrMDFFileName,isCommandLineOnly,doRunInDebugMode] = processArguments(varargin) ;
    
%     % Deal with arguments
%     if ~exist('isCommandLineOnly','var') || isempty(isCommandLineOnly) ,
%         isCommandLineOnly=false;
%     end
%     if ~exist('protocolOrMDFFileName','var') || isempty(protocolOrMDFFileName) ,
%         wasProtocolOrMDFFileNameGivenAtCommandLine=false;
%         protocolOrMDFFileName='';
%     else
%         wasProtocolOrMDFFileNameGivenAtCommandLine=true;
%     end
%     if ~exist('doRunInDebugMode','var') || isempty(doRunInDebugMode) ,
%         doRunInDebugMode = false ;
%     end
    
%     if ~exist('mode','var') || isempty(mode) ,
%         mode = 'release' ;
%     end

    % Create the application (model) object.
    isITheOneTrueWavesurferModel = true ;
    model = ws.WavesurferModel(isITheOneTrueWavesurferModel, doRunInDebugMode);

    % Start the controller, if desired
    if isCommandLineOnly ,
        % do nothing
        controller=[];
    else
        controller = ws.WavesurferMainController(model);    
    end

    % Do a drawnow()...
    drawnow() ;  
      % Have to do this to give OuterPosition a chance to catch up to
      % reality, since we query that when deciding whether to move figures
      % that are possibly off-screen.  Kind of annoying...
    
    % Load the protocol/MDF file, if one was given
    if wasProtocolOrMDFFileNameGivenAtCommandLine ,
        [~,~,extension] = fileparts(protocolOrMDFFileName) ;
        if isequal(extension,'.m') ,
            % it's an MDF file
            if isempty(controller) ,
                model.initializeFromMDFFileName(protocolOrMDFFileName);
            else
                % Need to do via controller, to keep the figure updated
                %controller.initializeGivenMDFFileName(protocolOrMDFFileName);
                error('ws:mdfFileNotSupportedWhenUIPresent', ...
                      'WaveSurfer no longer supports the use of MDF files in the presence of the UI') ;
            end            
        elseif isequal(extension,'.cfg')
            % it's a protocol file
            if isempty(controller) ,
                model.openProtocolFileGivenFileName(protocolOrMDFFileName);
            else
                % Need to do via controller, to keep the figure updated
                drawnow('expose') ;
                %controller.loadProtocolFileForRealsSrsly(protocolOrMDFFileName);
                % We do this via controlActuated() to get the usual
                % try-catch behaviors when a control is actuated in the UI
                source = [] ;
                event = [] ;
                controller.controlActuated('OpenProtocolGivenFileNameFauxControl', source, event, protocolOrMDFFileName) ;
            end
        else
            % do nothing
        end
    else
        % If no protocol or MDF file given, start with a basic setup
        model.addStarterChannelsAndStimulusLibrary() ;
    end

    % Populate the output args
    varargout=cell(0,1);
    if nargout>=1 ,
        varargout{1}=model;
    end
    if nargout>=2 ,
        varargout{2}=controller;
    end
    
    % Declare WS started
    fprintf('done.\n');    
end  % function



function [wasProtocolOrMDFFileNameGivenAtCommandLine, protocolOrMDFFileName,isCommandLineOnly,doRunInDebugMode] = processArguments(args)
    % Deal with --debug, --nodebug
    isDebugMatch = strcmp('--debug', args) ;
    isNoDebugMatch = strcmp('--nodebug', args) ;
    doRunInDebugMode = any(isDebugMatch) ;    
    argsWithoutDebug = args(~(isDebugMatch|isNoDebugMatch)) ;

    % Deal with --gui, --nogui
    isGuiMatch = strcmp('--gui', argsWithoutDebug) ;
    isNoguiMatch = strcmp('--nogui', argsWithoutDebug) ;
    isCommandLineOnly = any(isNoguiMatch) ;
    argsLeft = argsWithoutDebug(~(isGuiMatch|isNoguiMatch)) ;
    
    % Deal with the rest of the args
    if isempty(argsLeft) ,
        wasProtocolOrMDFFileNameGivenAtCommandLine = false ;
        protocolOrMDFFileName = '' ;
    elseif isscalar(argsLeft) ,
        wasProtocolOrMDFFileNameGivenAtCommandLine = true ;
        protocolOrMDFFileName = argsLeft{1} ;        
    else
        % too many args
        error('ws:tooManyArgsToWavesurfer', ...
              'Too many arguments to wavesurfer()') ;
    end
end  % function

