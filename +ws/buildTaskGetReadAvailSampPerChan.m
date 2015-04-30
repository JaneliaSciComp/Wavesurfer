function buildTaskGetReadAvailSampPerChan(releaseOrDebugString)

    daqmxVersionString = '9_8_x' ;
    
    if ~exist('releaseOrDebugString','var') || isempty(releaseOrDebugString) ,
        isReleaseBuild=true;
    elseif strcmpi(releaseOrDebugString,'-g') ,
        isReleaseBuild=false;
    else
        isReleaseBuild=true;
    end
        
    isDebugBuild = ~isReleaseBuild ;
    
    originalDirName = pwd();
    wsDirName = fileparts(mfilename('fullpath'));
    
    sourceDirName = fullfile(wsDirName,'+dabs/+ni/+daqmx/@Task');
    targetBaseName = 'getReadAvailSampPerChan';
    sourceFileName = sprintf('%s.cpp',targetBaseName) ;
    
    thirdPartiesDirName = fullfile(wsDirName,'+dabs/private/ThirdParties');
    daqmxIncludeDirName = fullfile(thirdPartiesDirName,sprintf('NI/DAQmx_%s',daqmxVersionString)) ;
    daqmxLibraryDirName = fullfile(daqmxIncludeDirName,'x64') ;
    daqmxIncludeSwitch = sprintf('-I%s',daqmxIncludeDirName) ;
    daqmxLibraryDirSwitch = sprintf('-L%s',daqmxLibraryDirName) ;
    daqmxLibrarySwitch = sprintf('-lNIDAQmx') ;
    
    cd(sourceDirName);
    if isReleaseBuild ,
        mex('-v',sourceFileName,daqmxIncludeSwitch,daqmxLibraryDirSwitch,daqmxLibrarySwitch);
    elseif isDebugBuild ,
        mex('-g','-v',sourceFileName,daqmxIncludeSwitch,daqmxLibraryDirSwitch,daqmxLibrarySwitch)
    end

%     % Copy mex file to the class dir
%     mexFileName = sprintf('%s.mexw64',targetBaseName);
%     mexFilePath = fullfile(sourceDirName,mexFileName);
%     classDirName = fullfile(wsDirName,'+dabs/+ni/+daqmx/@Task');
%     mexFileDestinationPath = fullfile(classDirName,mexFileName);
%     copyfile(mexFilePath,mexFileDestinationPath);
    
%     % Copy .pdb file to the class dir, if debug build
%     if isDebugBuild ,
%         pdbFileName = sprintf('%s.pdb',mexFileName) ;
%         pdbFilePath = fullfile(sourceDirName,pdbFileName);
%         pdbFileDestinationPath = fullfile(classDirName,pdbFileName);
%         copyfile(pdbFilePath,pdbFileDestinationPath);
%     end
    
    cd(originalDirName);
end
