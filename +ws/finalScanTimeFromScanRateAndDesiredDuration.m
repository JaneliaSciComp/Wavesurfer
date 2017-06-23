function result = finalScanTimeFromScanRateAndDesiredDuration(scanRate, desiredDuration)
    nScans = ws.nScansFromScanRateAndDesiredDuration(scanRate, desiredDuration) ;
    result = ws.finalScanTimeFromScanRateAndNScans(scanRate, nScans) ;
end
