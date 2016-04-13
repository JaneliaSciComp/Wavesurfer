function varargout = wavesurfer(protocolOrMDFFileName,isCommandLineOnly,mode)
    %wavesurfer  Launch Wavesurfer
    %
    %   wavesurfer(isCommandLineOnly,mdfFileName) launches
    %   the Wavesurfer GUI.  All input arguments are optional.
    %
    %   mdfFileName is the name of the Machine Data File.  If not provided,
    %   Wavesurfer will look for a file named Machine_Data_File.m on the Matlab
    %   path.
    %
    %   isCommandLineOnly, if true, does not launch the GUI.  The default is
    %   false, i.e. the default is to launch the GUI.
    %
    %   wsModel = wavesurfer() returns an application object, wsModel.  This
    %   may be useful for scripting or testing.
    %
    %   [wsModel, wsController] = wavesurfer() also returns the controller
    %   object, wsController.  It is an error to use this form when
    %   isCommandLineOnly is true.

    % Deal with arguments
    if ~exist('isCommandLineOnly','var') || isempty(isCommandLineOnly) ,
        isCommandLineOnly=false;
    end
    if ~exist('protocolOrMDFFileName','var') || isempty(protocolOrMDFFileName),
        wasProtocolOrMDFFileNameGivenAtCommandLine=false;
        protocolOrMDFFileName='';
    else
        wasProtocolOrMDFFileNameGivenAtCommandLine=true;
    end
    if ~exist('mode','var') || isempty(mode),
        mode = 'release' ;
    end

    % Create the application (model) object.
    model = ws.WavesurferModel(true, mode);  % arg is isITheOneTrueWavesurferModel

    % Start the controller, if desired
    if isCommandLineOnly ,
        % do nothing
        controller=[];
    else
        controller = ws.WavesurferMainController(model);    
%         controller.initialize();
%           % prompts it to sync the view with the model
%           % Why does this not happen automatically when you create the controller?
    end

    % Load the protocol/MDF file, if one was given
    if wasProtocolOrMDFFileNameGivenAtCommandLine ,
        [~,~,extension] = fileparts(protocolOrMDFFileName) ;
        if isequal(extension,'.m') ,
            % it's an MDF file
            if isempty(controller) ,
                model.initializeFromMDFFileName(protocolOrMDFFileName);
            else
                % Need to do via controller, to keep the figure updated
                controller.initializeGivenMDFFileName(protocolOrMDFFileName);
            end            
        elseif isequal(extension,'.cfg')
            % it's a protocol file
            if isempty(controller) ,
                model.loadProtocolFileForRealsSrsly(protocolOrMDFFileName);
            else
                % Need to do via controller, to keep the figure updated
                controller.loadProtocolFileForRealsSrsly(protocolOrMDFFileName);
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
end  % function
