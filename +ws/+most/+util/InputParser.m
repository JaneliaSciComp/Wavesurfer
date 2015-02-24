classdef InputParser < inputParser
% Cause I like to live on the edge.

    properties (Constant)
        fDummyVal = '___ThIs will never be duplicated';
    end

    properties (Hidden)
        fRequiredParams = cell(0,1);
    end
    
    methods
        
        function obj = InputParser
            obj = obj@inputParser;
            obj.KeepUnmatched = true;            
        end
        
    end
    
    methods
        
        function addRequiredParam(obj,pname,validator)
            if nargin < 3
                validator = @(x)true;
            end
            obj.addParamValue(pname,obj.fDummyVal,validator);
            obj.fRequiredParams{end+1,1} = pname;
        end
        
        function parse(obj,varargin)
            parse@inputParser(obj,varargin{:});
            s = obj.Results;
            
            for c = 1:numel(obj.fRequiredParams);
                fld = obj.fRequiredParams{c};
                assert(isfield(s,fld));
                if isequal(s.(fld),obj.fDummyVal);
                    error('Dabs:InputParser','Required property ''%s'' unspecified.',fld);
                end
            end
        end
                
        function createCopy(obj) %#ok<MANU>
            assert(false);
        end
        
    end
        
    
end