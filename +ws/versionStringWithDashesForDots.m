function result=versionStringWithDashesForDots()
    rawVersionString=ws.versionString();
    result=strrep(rawVersionString,'.','-');
end
