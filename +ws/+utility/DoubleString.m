classdef DoubleString
    % A class to represent a double as either a string or an actual double,
    % depending on which is most convenient at the moment.  This is often
    % useful for dealing with values that might have been typed in by a
    % user, and you want to preserve the exact string representation of the
    % number.
    properties  (Access=protected)
        Value_  % the value, either a double or a string
    end  % properties
    
    %----------------------------------------------------------------------
    methods
        function doubleString=DoubleString(varargin)
            % Constructor for SIUnit. Will take 0 or 1 args.
            %   0 args: Returns a zero DoubleString.
            %   1 arg: Stores the arg as the value, assuming it's
            %          permissible.
            if nargin==0 ,
                doubleString.Value_='0';
            elseif nargin==1 ,
                argument=varargin{1};
                if ischar(argument) ,
                    newDouble=str2double(argument);
                    if isempty(argument) || ~isnan(newDouble) ,
                        doubleString.Value_=strtrim(argument);
                    else
                        error('DoubleString:badConstructorArgs','Invalid string value.');  
                    end
                elseif isnumeric(argument) ,
                    if isscalar(argument) ,
                        doubleString.Value_=double(argument);
                    else
                        error('DoubleString:badConstructorArgs','Invalid double value.');  
                    end
                elseif isa(argument,'ws.utility.DoubleString') && isscalar(argument),
                    doubleString.Value_=argument.getRepresentation();
                else
                    error('DoubleString:badConstructorArgs','Invalid argument.');
                end
            else
                error('DoubleString:badConstructorArgs','Too many arguments.');
            end
        end  % function
        
        %------------------------------------------------------------------
        function result=filter(doubleString,newThang)
            try
                result=ws.utility.DoubleString(newThang);
            catch me
                if isequal(me.identifier,'DoubleString:badConstructorArgs')
                    result=doubleString;  % return the original value
                else
                    rethrow(me);
                end
            end
        end  % function
        
        %------------------------------------------------------------------
        function result=toDouble(doubleString)
            value=doubleString.Value_;
            if ischar(value) ,
                result=str2double(value);
            else
                % must be a double
                result=value;
            end
        end  % function
        
        %------------------------------------------------------------------
        function result=double(doubleString)
            result=doubleString.toDouble();
        end  % function
        
        %------------------------------------------------------------------
        function result=toString(doubleString,formatString)
            if ~exist('formatString','var') ,
                formatString='%.7g';  % Will preserve 7 significant figures, I think
            end
            
            value=doubleString.Value_;
            if ischar(value) ,
                result=value;
            else 
                % must be double
                result=sprintf(formatString,value);
            end
        end  % function
        
        %------------------------------------------------------------------
        function result=string(doubleString,varargin)
            result=doubleString.toString(varargin{:});
        end  % function
        
        %------------------------------------------------------------------
        function result=getRepresentation(doubleString)
            result=doubleString.Value_;
        end  % function
        
        %------------------------------------------------------------------
        function disp(doubleString)
            value=doubleString.Value_;
            if ischar(value) ,
                fprintf('    String: ''%s''\n',value);
            else 
                % must be double
                fprintf('    Double: %.17g\n',value);
            end
        end  % function
        
        %------------------------------------------------------------------
        function result=saveobj(doubleString)
            % Returns a struct that encodes all the internal state of doubleString.            
            result=struct('Value',{doubleString.Value_});
        end  % function
    end  % methods
    
    %----------------------------------------------------------------------
    methods (Static=true)
        function doubleString=loadobj(s)
            % See saveobj().
            doubleString=ws.utility.DoubleString(s.Value);
        end  % function
    end  % static methods
    
end  % classdef
