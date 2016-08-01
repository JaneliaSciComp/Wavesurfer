classdef (ConstructOnLoad) EventDataWithArgs < event.EventData
    % A subclass of event.EventData that allows us to basically pass a
    % variable-length list of additional arguments with any event.  This is
    % useful in many places.
    
   properties
      Args  % A cell array of additional arguments, like varargin
   end
   
   methods
      function data = EventDataWithArgs(varargin)
         data.Args = varargin ;  % just pass the arguments as a cell array
      end
   end
end
