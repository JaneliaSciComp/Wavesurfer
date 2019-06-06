function result = scalarVersionFromVersionString(versionString)
    % Version 1.0 was the last real-number version.  After that we switched to
    % semantic versioning.  This allows either to be converted into a scalar,
    % suitable for comparison.
    versionOrNan = str2double(versionString) ;
    if isnan(versionOrNan) ,
        % Presumably a semver style major.minor.bugfix version
        versionAsTriple = ws.versionTripleFromVersionString(versionString) ;
        result = versionAsTriple(1) + 1e-4*versionAsTriple(2) + 1e-8*versionAsTriple(3) ;
    else
        % Must be a <= 1.0 version, so just return as-is
        result = versionOrNan ;
    end
end
