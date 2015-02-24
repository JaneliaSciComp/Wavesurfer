function state=warningState(messageID)
    s=warning('query',messageID);
    state=s.state;
end
