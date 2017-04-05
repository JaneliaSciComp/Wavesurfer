function nScans = nScansFromScanRateAndDesiredDuration(scanRate, desiredDuration)
    nScans = floor(desiredDuration * scanRate) + 1 ;
    % This is the expected number of scans, and also the
    % number of scans we request from the NI hardware.
    %
    % NI boards take their first sample at the start of the
    % sweep (t==0).  So the (actual) time of the final sample
    % is tf == (n-1)*dt.  The hard constraint is tf <= T, where
    % T is the desired acquisition duration, and we want n to
    % be as large as possible given this constraint.  Thus:
    %
    %    n the largest integer s.t. (n-1)*dt <= T
    % => n the largest integer s.t. (n-1)/fs <= T
    % => n the largest integer s.t. n <= T*fs+1
    % => n == floor( T*fs+1 )
    % => n == floor(T*fs) + 1
    %
    % Example: If dt = 40 s (very
    % slow, but we want to support very slow sampling for
    % time-lapse style applications), and desired T = 100 s,
    % then the right answer is a sample at t=0, one at t=40,
    % and one at t=80, thus n==3.  This does that.
end
