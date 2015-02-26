classdef Test < ws.most.DClass
    %TEST Summary of this class goes here
    %   Detailed explanation goes here
    
    
    %% CLASS PROPERTIES
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (Access=protected)
        testName; % An optional human-readable name for this test.
        hFunction; % A function handle to the method under test.
        successCondition; % An evaluable (logical) expression that encodes the success condition for the method under test.
        fncArgs = {}; % A cell array of arguments to be passed to the method under test.
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    %% CONSTRUCTOR/DESTRUCTOR
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods
        
        function obj = Test(testFunction,varargin)
            % hTestFunction - a function handle or a string containing a function name (DEQ20101220 - not reliably working)
            % optional:
            %   'testFixture' - an object on which to make the function call (DEQ20101220 - not reliably working)
            %   'successCondition' - an evaluable expression to verify test success
            %   'testName' - a human-readable name for this test.
            %   'fncArgs' - a cell array of values to be passed to the the method under test.
            
            % Handle optional arg/val pairs
            pvargs = obj.filterPropValArgs(varargin,{'testFixture' 'successCondition' 'testName' 'fncArgs'});
            if ~isempty(pvargs)
                obj.set(pvargs(1:2:end),pvargs(2:2:end));
            end
            
            if isempty(obj.successCondition)
                obj.successCondition = 'true';
            end
            
            if isempty(obj.testName)
                obj.testName = '';
            end
            
            if isempty(obj.fncArgs)
                obj.fncArgs = {};
            end
            
            % 'hTestFunction': accept either a function handle or a function
            % name (string). If a name is given, it is assumed to exist as
            % a method of 'testFixture'.
            %
            % TODO (DEQ): As of now, the 'string' form of this does not (reliably) 
            % work, as I can't figure out a way to accept a variable number 
            % of output arguments from an anonymous function handle...the
            % consequence of this is that any tested class method must be 
            % wrapped by a 'testXXX()' function (in whatever class inherits
            % from TestSuite).  
            if isa(testFunction,'function_handle')
                obj.hFunction = testFunction;
            elseif isa(testFunction,'char') % DEQ20101220 - this works if 'testFunction' returns a single var, but problems occur later when you encounter functions with multiple output args
                obj.hFunction = @(varargin)testFixture.(testFunction)(varargin);
            else
                error('Invalid ''testFunction''.'); 
            end
            
        end
        
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    %% CLASS METHODS
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods (Access = public)
        
        function [didPass,output] = run(obj)            
            % Execute the method under test.
            try
                [didPass, output] = feval(obj.hFunction,obj.fncArgs{:});
            catch ME
                didPass = false;
                output = ME.message;
                return;
            end
            
            % Confirm the success condition.
            if didPass == true
                try
                    assert(eval(obj.successCondition),'The test''s success condition was not met.');
                catch ME
                    didPass = false;
                    output = ME.message;
                    return;
                end
            else
               return; 
            end
            
            didPass = true;
            output = 'Success.';
            return;
        end
        
        function val = getName(obj)
           val = obj.testName; 
        end

    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
end

