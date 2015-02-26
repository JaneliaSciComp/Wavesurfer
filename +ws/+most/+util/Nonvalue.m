classdef Nonvalue < double
    %ws.most.app.Nonvalue  This is an enumeration with only one value.  If you
    %set a model property to this value, the convention is that the property will not be set
    %to this "nonvalue", but will retain its original value.  Thus the only affect of the set
    %will be to fire the PreSet and PostSet events.  This is often a useful
    %thing to do, especially in the context of property bindings, and
    %particularly for dependent properties.
    
    enumeration
        The (nan) % The only possible value
    end    
end
