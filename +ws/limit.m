function y = limit(lower, x, upper)
    % y = limit(lower, x, upper)
    %
    % y is like x, but limited (elementwise) to the interval [lower,
    % upper].
    y = min(max(lower, x), upper) ;
end
