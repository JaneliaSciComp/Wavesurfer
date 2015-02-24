classdef Diagnostics < handle
    %Diagnostics Control diagnostic output at the command line and in log files.
    %
    %   The Diagnostics class can be used to provide control over the vebosity of
    %   diagnostic output at the command line and in log files for most classes and
    %   derived applications.  Functions and class methods can query the LogLevel to
    %   determine how much information to display, if any.  Applications can also
    %   set and change the LogLevel at any time.
    %
    %   
    %   See also ws.most.util.LogLevel.
    
    properties
        LogLevel = ws.most.util.LogLevel.Info; %Specifies the verbosity of command line and log file output.
    end
    
    methods (Access = private)
        function self = Diagnostics()
            %Diagnostics Default class constructor.
            %
            %   Diagnostics is a singleton class per MATLAB instance and therefore has a
            %   private constructor.
        end
    end
    
    methods
        function set.LogLevel(self, value)
            validateattributes(value, {'numeric', 'logical', 'ws.most.util.LogLevel'}, {'scalar'});
            
            if ~isa(value, 'ws.most.util.LogLevel')
                value = ws.most.util.LogLevel(value);
            end
            
            self.LogLevel = value;
        end
    end
    
    methods (Static = true)
        function out = shareddiagnostics()
            %shareddiagnostics Return Diagnostics class singleton.
            
            persistent sharedInstance;
            if isempty(sharedInstance)
                sharedInstance = ws.most.Diagnostics();
            end
            out = sharedInstance;
        end
    end
end
