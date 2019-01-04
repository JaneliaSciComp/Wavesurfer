function build_ni(option)
    % Build daqmex.  Note that if you change daqmex.c or daqmex.h, you
    % should do "build clean; build" --- this function isn't smart enough
    % to deal with those dependencies.
    if nargin<1 || isempty(option) ,
        option = 'all';
    end
    
    orginal_pwd = pwd() ;
    cleaner = onCleanup(@()(cd(orginal_pwd))) ;
    this_script_path = mfilename('fullpath') ;
    this_script_folder_path = fileparts(this_script_path) ;
    cd(this_script_folder_path) ;
    
    niIncludePath = '-I"C:/Program Files (x86)/National Instruments/Shared/ExternalCompilerSupport/C/include"' ;
    niLibraryPath = '-L"C:/Program Files (x86)/National Instruments/Shared/ExternalCompilerSupport/C/lib64/msvc"' ;

    baseNamesOfFilesToCompile = { 'ni' , ...
                                  } ;
%                                   'DAQmx_Val_Rising' ...
%                                   'DAQmx_Val_Falling' ...
%                                   'DAQmx_Val_FiniteSamps' ...
%                                   'DAQmx_Val_ContSamps' ...
%                                   'DAQmx_Val_WaitInfinitely' ...
%                                   'DAQmx_Val_Task_Start' ...
%                                   'DAQmx_Val_Task_Stop' ...
%                                   'DAQmx_Val_Task_Verify' ...
%                                   'DAQmx_Val_Task_Commit' ...
%                                   'DAQmx_Val_Task_Reserve' ...
%                                   'DAQmx_Val_Task_Unreserve' ...
%                                   'DAQmx_Val_Task_Abort' ...
%                                   'DAQmxStartTask' , ...
%                                   'DAQmxStopTask' , ...
%                                   'DAQmxIsTaskDone' , ...
%                                   'DAQmxTaskControl' , ...
%                                   'DAQmxWaitUntilTaskDone' , ...
%                                   'DAQmxCfgSampClkTiming', ...
%                                   'DAQmxCfgDigEdgeStartTrig' ...
%                                   'DAQmxGetReadAvailSampPerChan', ...
%                                   'DAQmxCreateAIVoltageChan', ...
%                                   'DAQmxCreateDIChan', ...
%                                   'DAQmxCreateAOVoltageChan', ...
%                                   'DAQmxCreateDOChan', ...
%                                   'DAQmxReadBinaryI16' , ...
%                                   'DAQmxReadDigitalLines' , ...
%                                   'DAQmxReadDigitalU32' , ...
%                                   'DAQmxWriteAnalogF64' , ...
%                                   'DAQmxWriteDigitalLines' , ...

    for i=1:length(baseNamesOfFilesToCompile) ,                
        cFileName = sprintf('%s.c',baseNamesOfFilesToCompile{i}) ;
        mexFileName = sprintf('%s.mexw64',baseNamesOfFilesToCompile{i}) ;
        pdbFileName = sprintf('%s.mexw64.pdb',baseNamesOfFilesToCompile{i}) ;
        cFileInfo = dir(cFileName) ;
        mexFileInfo = dir(mexFileName) ;
        if isequal(option,'clean') ,
            if ~isempty(mexFileInfo) ,
                delete(mexFileName) ;
            end
            pdbFileInfo = dir(pdbFileName) ;
            if ~isempty(pdbFileInfo) ,
                delete(pdbFileName) ;
            end            
        else
            % normal build
            if isempty(cFileInfo) ,
                warning('Source file %s is missing',cFileName) ;
            else
                % C file is present, at least
                if isempty(mexFileInfo) || cFileInfo.datenum>=mexFileInfo.datenum ,
                    % Mex file is missing or older than C file, so compile the
                    % C file
                    fprintf('%s:\n',cFileName) ;
                    mex('-g', ...
                        'COMPFLAGS="$COMPFLAGS /W3"', ...
                        '-largeArrayDims', ...
                        niIncludePath, ...
                        niLibraryPath, ...
                        cFileName, ...
                        '-lNIDAQmx');
                    fprintf('\n');
                end
                %fprintf('\n\n\n\n\n\n');
            end
        end
    end
end
