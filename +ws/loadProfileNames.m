function result = loadProfileNames()
    appDataPath = getenv('APPDATA') ;
    preferencesFolderPath = fullfile(appDataPath, 'janelia', 'wavesurfer', 'profiles') ;
    matFileNames = ws.simpleDir(fullfile(preferencesFolderPath, '*.mat')) ;
    rawProfileNames = cellfun(@stripDotMat, matFileNames, 'UniformOutput', false) ;
    if isempty(rawProfileNames) ,
        result = {'Default'} ;
    else
        result = sort(rawProfileNames) ;
    end
end

function result = stripDotMat(matFileName)
    result = matFileName(1:end-4) ;
end
