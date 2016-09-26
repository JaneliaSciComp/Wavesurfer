classdef ExpressionStimulusDelegate < ws.StimulusDelegate
    properties (Constant)
        TypeString='Expression'
        AdditionalParameterNames={'Expression'}
        AdditionalParameterDisplayNames={'Expression'}
        AdditionalParameterDisplayUnitses={''}
    end
    
    properties (Dependent=true)
        Expression
    end
    
    properties (Access=protected)
        Expression_ = ''  % matlab expression, possibly containing i, which is replaced by the sweep number, and t, which is a vector of times
    end
    
    methods
        function self = ExpressionStimulusDelegate(parent,varargin)
            self=self@ws.StimulusDelegate(parent);
            pvArgs = ws.filterPVArgs(varargin, {'Expression'}, {});
            propNames = pvArgs(1:2:end);
            propValues = pvArgs(2:2:end);               
            for i = 1:length(propValues)
                self.(propNames{i}) = propValues{i};
            end            
        end  % function
        
        function set.Expression(self, value)
            if ischar(value) && (isempty(value) || isrow(value)) ,
                % Get rid of backslashes, b/c they mess up sprintf()
                valueWithoutBackslashes = ws.replaceBackslashesWithSlashes(value);
                test = ws.Stimulus.evaluateStringSweepTemplate(valueWithoutBackslashes,1);
                if ischar(test) ,
                    % if we get here without error, safe to set
                    self.Expression_ = valueWithoutBackslashes;
                end
%                 if ~isempty(self.Parent) ,
%                     self.Parent.childMayHaveChanged();
%                 end
            end
        end  % function

        function out = get.Expression(self)
            out=self.Expression_;
        end
        
        % digital signals should be returned as doubles and are thresholded at 0.5
        function y = calculateCoreSignal(self, stimulus, t, sweepIndexWithinSet)  %#ok<INUSL>
            %eval(['i=sweepIndexWithinSet; fileNameAfterEvaluation=' self.Expression ';']);
            expression = self.Expression ;
            if ischar(expression) && isrow(expression) ,
                % value should be a string representing an
                % expression involving 'i', which stands for the sweep
                % index, and 't', a vector if times (in seconds) e.g. '10*(i-1)*(3<=t & t<4)'                
                try
                    % try to build a lambda and eval it, to see if it's
                    % valid
                    stringToEval=sprintf('@(t,i)(%s)',expression);
                    expressionAsFunction=eval(stringToEval);
                    y=expressionAsFunction(t,sweepIndexWithinSet);
                catch me %#ok<NASGU>
                    y=zeros(size(t));
                end
            else
                y=zeros(size(t));
            end
        end  % function        
    end  % public methods block

%     methods (Access=protected)
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.StimulusDelegate(self);
%             self.setPropertyTags('AdditionalParameterNames', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('AdditionalParameterDisplayNames', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('AdditionalParameterDisplayUnitses', 'ExcludeFromFileTypes', {'header'});
%         end
%     end
    
    %
    % Implementations of methods needed to be a ws.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.ExpressionStimulusDelegate');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            propertyNamesToCompare={'Expression'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end
    end
    
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
end

