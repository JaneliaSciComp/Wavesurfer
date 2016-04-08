function deleteFileWithoutWarning(fileName)
    originalState=ws.warningState('MATLAB:DELETE:Permission');
    warning('off','MATLAB:DELETE:Permission')
    delete(fileName)
    warning(originalState,'MATLAB:DELETE:Permission');
end
