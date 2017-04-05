function actualDuration = actualDurationFromScanRateAndNScans(scanRate, nScans)
    actualDuration = (nScans-1)/scanRate ;
        % NI boards take their first scan at the start of the
        % sweep (t==0).  So the (actual) time of the final scan
        % is tf == (n-1)*dt, which we use for the duration of the sweep.
        % (Of course, with non-synchronous sampling, other channels are
        % offset from these times somewhat.)
end
