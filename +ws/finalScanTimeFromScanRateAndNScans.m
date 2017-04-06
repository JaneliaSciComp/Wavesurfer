function actualDuration = finalScanTimeFromScanRateAndNScans(scanRate, nScans)
    actualDuration = (nScans-1)/scanRate ;
        % NI boards take their first scan at the start of the
        % sweep (t==0).  So the (actual) time of the final scan
        % is tf == (n-1)*dt.
        % (Of course, with non-synchronous sampling, other channels are
        % offset from these times somewhat.)
end
