function s = vertcatfields(X)
    % Returns a single structure that concatenates each field of the
    % structures in the structure array X.
    
    assert(isa(X, 'struct'),'X must be a structure array.')
    
    s = X(1);
    fields = fieldnames(s);
    
    for i = 2:numel(X)
        for j = 1:numel(fields)
            s.(fields{j}) = vertcat(s.(fields{j}),X(i).(fields{j}));
        end
    end
end

