function q = invertPermutation(p)    
    % Input p must be a row vector of length n, with elements equal to a
    % permuation of 1:n, such as produced by randperm(n).  p represents the
    % permuation that maps 1 to p(1), 2 to p(2), etc. The result is the
    % inverse of this permuation, call it q.  I.e. q is such that q(p(i))
    % == i, for all i s.t 1<=i<=n.  This implies that p(q(i))==i for all
    % such i also.

    n = length(p) ;
    identity = 1:n ;
    q(p) = identity ;  % maybe not obvious, but this works.
end
