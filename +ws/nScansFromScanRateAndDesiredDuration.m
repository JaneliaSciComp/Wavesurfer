function nScans = nScansFromScanRateAndDesiredDuration(scanRate, desiredDuration)
    nScans = ceil(desiredDuration * scanRate) ;
    % This is the expected number of scans, and also the number of scans we
    % request from the NI hardware.
    %
    % NI boards take their first scan at the start of the sweep (t==0). So
    % the (actual) time of the final scan is tf == (n-1)*dt.  In choosing n
    % given a desired scan interval, dt, and a desired duration, T, you
    % either want tf < T or tf <= T.  Of course, the difference only
    % matters if T is an integer multiple of dt.  In that case, I think n =
    % T/dt is the right answer.  The alternative is n = T/dt+1.  That's
    % defensible, but I like m = T/dt because 1) it's simpler, 2) if you
    % double T, you get double the number of samples, 3) it's consistent
    % with the past WS behavior, which used n = round(T/dt), in the very
    % common case where T is an integer multiple of dt.  The commitment to
    % n=T/dt when T is an integer multiple of dt implies that tf<T
    % (strictly) is the right constraint, and we want n to be as large as
    % possible given this constraint.  Thus:
    %
    %    n the largest integer s.t. (n-1)*dt < T
    % => n the largest integer s.t. (n-1)/fs < T
    % => n the largest integer s.t. n < T*fs+1
    % => n == ceil(T*fs+1) - 1  (ceil(x)-1 is the largest integer strictly less than x)
    % => n == ceil(T*fs)
    %
    % Example: If dt = 40 s (very slow, but we want to support very slow
    % sampling for time-lapse style applications), and desired T = 100 s,
    % then the right answer is a sample at t=0, one at t=40, and one at
    % t=80, thus n==3.  This does that.  And if T==dt*m, for some integer
    % m, then this gives n == m.
end
