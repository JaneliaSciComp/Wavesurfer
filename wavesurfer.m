function varargout = wavesurfer(mdfFileName,isCommandLineOnly)
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
    if ~exist('mdfFileName','var') || isempty(mdfFileName),
        wasMDFFileNameGivenAtCommandLine=false;
        mdfFileName='';
    else
        wasMDFFileNameGivenAtCommandLine=true;
    end

    % Create the application (model) object.
    model = ws.WavesurferModel();

    % Start the controller, if desired
    if isCommandLineOnly ,
        % do nothing
        controller=[];
    else
        controller = ws.WavesurferMainController(model);    
        controller.initialize();
          % prompts it to sync the view with the model
          % Why does this not happen automatically when you create the controller?
    end

    % Load the MDF file, maybe
    if wasMDFFileNameGivenAtCommandLine ,
        if isempty(controller) ,
            model.initializeFromMDFFileName(mdfFileName);
        else
            % Need to do via controller, to keep the figure updated
            controller.initializeGivenMDFFileName(mdfFileName);
        end
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
