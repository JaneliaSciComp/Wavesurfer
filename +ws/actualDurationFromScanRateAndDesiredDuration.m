function actualDuration = actualDurationFromScanRateAndDesiredDuration(scanRate, desiredDuration)
    nScans = ws.nScansFromScanRateAndDesiredDuration(scanRate, desiredDuration) ;
    actualDuration = ws.actualDurationFromScanRateAndNScans(scanRate, nScans) ;
end
