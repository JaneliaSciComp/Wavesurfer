function c = name2csv(str)
%TOCSV Summary of this function goes here
%   Detailed explanation goes here

c = {};

while true
    [pre,post] = strtok(str,'.');
    
    c{end+1} = pre;
    
    if isempty(post)
        break;
    else
        str = post(2:end);
    end    
end

