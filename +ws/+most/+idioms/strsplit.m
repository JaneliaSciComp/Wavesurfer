%% sadly, pre-2013 matlab does not have strsplit and strjoin
% code copied off of the matlab file exchange and modified for brevity
function terms = strsplit(s, delimiter)
if nargin < 2
    by_space = true;
else
    d = delimiter;
    d = strtrim(d);
    by_space = isempty(d);
end
s = strtrim(s);

if by_space
    w = isspace(s);
    if any(w)
        % decide the positions of terms
        dw = diff(w);
        sp = [1, find(dw == -1) + 1];     % start positions of terms
        ep = [find(dw == 1), length(s)];  % end positions of terms
        
        % extract the terms
        nt = numel(sp);
        terms = cell(1, nt);
        for i = 1 : nt
            terms{i} = s(sp(i):ep(i));
        end
    else
        terms = {s};
    end
    
else
    p = strfind(s, d);
    if ~isempty(p)
        % extract the terms
        nt = numel(p) + 1;
        terms = cell(1, nt);
        sp = 1;
        dl = length(delimiter);
        for i = 1 : nt-1
            terms{i} = strtrim(s(sp:p(i)-1));
            sp = p(i) + dl;
        end
        terms{nt} = strtrim(s(sp:end));
    else
        terms = {s};
    end
end