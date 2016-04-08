function restlessSleep(duration)
    % Burn cycles until the given duration (in seconds) has elapsed.
    % Not accurate below about a millisecond.
    
    tStart=tic();
    x=0;
    durationSoFar=toc(tStart);
    while (durationSoFar<duration)
        %A=rand(40);
        %Ainv=inv(A); %#ok<NASGU>
        x=mod(x+1,2);
        durationSoFar=toc(tStart);
    end
end

