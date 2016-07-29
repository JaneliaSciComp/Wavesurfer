function deleteIfValidHandle(things)
    % Delete any elements of things that are valid handles (i.e. instances of
    % a subclass of handle).

    % A lot of this logic is necessary to avoid, for instance, calling
    % isvalid() on double arrays, for which it is not defined.

    if isempty(things), 
        return
    end
    isHandleArray=isa(things,'handle');
    if ~isHandleArray , 
        return
    end
    isValid=isvalid(things);  % logical array, same size as things
    validHandles=things(isValid);
    delete(validHandles);
end
