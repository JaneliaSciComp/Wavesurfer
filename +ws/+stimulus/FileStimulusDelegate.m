classdef FileStimulusDelegate < ws.stimulus.StimulusDelegate
    properties (Constant)
        TypeString='File'
        AdditionalParameterNames={'Filename'}
        AdditionalParameterDisplayNames={'Filename'}
        AdditionalParameterDisplayUnitses={'path'}
    end
    
    properties (Dependent=true)
        Filename
    end
    
    properties (Access=protected)
        Filename_ = ''  % path
    end
    
    methods
        function self = FileStimulusDelegate(parent,varargin)
            self=self@ws.stimulus.StimulusDelegate(parent);
            pvArgs = ws.most.util.filterPVArgs(varargin, {'Filename'}, {});
            propNames = pvArgs(1:2:end);
            propValues = pvArgs(2:2:end);               
            for i = 1:length(propValues)
                self.(propNames{i}) = propValues{i};
            end            
        end  % function
        
        %e.g. sprintf('C:\\Users\\arthurb\\Documents\\MATLAB\\Wavesurfer\\data\\electrode%d.wav',i)
        function set.Filename(self, value)
            test = ws.stimulus.Stimulus.evaluateTrialExpression(value,1);
            if ischar(test) ,
                % if we get here without error, safe to set
                self.Filename_ = value;
            end
            if ~isempty(self.Parent) ,
                self.Parent.childMayHaveChanged();
            end
        end  % function

        function out = get.Filename(self)
            out=self.Filename_;
        end
    end
    
    methods
        % digital signals should be saved as floats and are thresholded at 0.5
        function y = calculateCoreSignal(self, stimulus, t, trialIndexWithinSet)
            eval(['i=trialIndexWithinSet; tmp=' self.Filename ';']);
            [y,fs] = audioread(tmp);
            y = interp1((0:length(y)-1)./fs, y, t, 'linear', 0);
        end
        
    end

    methods (Access=protected)
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.stimulus.StimulusDelegate(self);
            self.setPropertyTags('AdditionalParameterNames', 'ExcludeFromFileTypes', {'header'});
            self.setPropertyTags('AdditionalParameterDisplayNames', 'ExcludeFromFileTypes', {'header'});
            self.setPropertyTags('AdditionalParameterDisplayUnitses', 'ExcludeFromFileTypes', {'header'});
        end
    end
    
    %
    % Implementations of methods needed to be a ws.mixin.ValueComparable
    %
    methods
        function value=isequal(self,other)
            % Custom isequal.  Doesn't work for 3D, 4D, etc arrays.
            value=isequalHelper(self,other,'ws.stimulus.FileStimulusDelegate');
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement(self,other)
            propertyNamesToCompare={'InitialFrequency' 'FinalFrequency'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end
    end
    
end

