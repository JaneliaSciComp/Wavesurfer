function lCOM_Port = getAvailableComPorts()
% function lCOM_Port = getAvailableComPorts()
% Return a Cell Array of COM port names available on your computer

try
    s=serial('IMPOSSIBLE_NAME_ON_PORT');fopen(s);
catch
    lErrMsg = lasterr;
end

%Start of the COM available port
lIndex1 = findstr(lErrMsg,'COM');
%End of COM available port
lIndex2 = findstr(lErrMsg,'Use')-3;

lComStr = lErrMsg(lIndex1:lIndex2);

%Parse the resulting string
lIndexDot = findstr(lComStr,',');

% If no Port are available
if isempty(lIndex1)
    lCOM_Port{1}='';
    return;
end

% If only one Port is available
if isempty(lIndexDot)
    lCOM_Port{1}=lComStr;
    return;
end

lCOM_Port{1} = lComStr(1:lIndexDot(1)-1);

for i=1:numel(lIndexDot)+1
    % First One
    if (i==1)
        lCOM_Port{1,1} = lComStr(1:lIndexDot(i)-1);
        % Last One
    elseif (i==numel(lIndexDot)+1)
        lCOM_Port{i,1} = lComStr(lIndexDot(i-1)+2:end);
        % Others
    else
        lCOM_Port{i,1} = lComStr(lIndexDot(i-1)+2:lIndexDot(i)-1);
    end
end