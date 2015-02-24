function restlessSleep(duration)
    % Burn cycles until the given duration (in seconds) has elapsed.
    % Not accurate below about a millisecond.
    
    tStart=tic();
    durationSoFar=toc(tStart);
    while (durationSoFar<duration)
        A=rand(40);
        Ainv=inv(A); %#ok<NASGU>
        durationSoFar=toc(tStart);
    end
end

