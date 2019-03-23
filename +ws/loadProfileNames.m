function result = loadProfileNames()
    preferencesFilePath = ws.preferencesFileNameFromProfileName('Default') ;
    preferencesFolderPath = fileparts(preferencesFilePath) ;
    matFileNames = ws.simpleDir(fullfile(preferencesFolderPath, '*.wsu')) ;
    rawProfileNames = cellfun(@stripDotMat, matFileNames, 'UniformOutput', false) ;
    if isempty(rawProfileNames) ,
        result = { 'Default' } ;
    else
        result = sort(rawProfileNames) ;
    end
end

function result = stripDotMat(matFileName)
    result = matFileName(1:end-4) ;
end
