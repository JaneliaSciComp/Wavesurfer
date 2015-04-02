classdef FileStimulusDelegate < ws.stimulus.StimulusDelegate
    properties (Constant)
        TypeString='File'
        AdditionalParameterNames={'FileName'}
        AdditionalParameterDisplayNames={'Audio File Name'}
        AdditionalParameterDisplayUnitses={''}
    end
    
    properties (Dependent=true)
        FileName
    end
    
    properties (Access=protected)
        FileName_ = ''  % path, possibly containing %d, which is replaced by the trial number
    end
    
    methods
        function self = FileStimulusDelegate(parent,varargin)
            self=self@ws.stimulus.StimulusDelegate(parent);
            pvArgs = ws.most.util.filterPVArgs(varargin, {'FileName'}, {});
            propNames = pvArgs(1:2:end);
            propValues = pvArgs(2:2:end);               
            for i = 1:length(propValues)
                self.(propNames{i}) = propValues{i};
            end            
        end  % function
        
        %e.g. sprintf('C:\\Users\\arthurb\\Documents\\MATLAB\\Wavesurfer\\data\\electrode%d.wav',i)
        function set.FileName(self, value)
            if ischar(value) && (isempty(value) || isrow(value)) ,
                % Get rid of backslashes, b/c they mess up sprintf()
                valueWithoutBackslashes = ws.utility.replaceBackslashesWithSlashes(value);
                test = ws.stimulus.Stimulus.evaluateStringTrialTemplate(valueWithoutBackslashes,1);
                if ischar(test) ,
                    % if we get here without error, safe to set
                    self.FileName_ = valueWithoutBackslashes;
                end
                if ~isempty(self.Parent) ,
                    self.Parent.childMayHaveChanged();
                end
            end
        end  % function

        function out = get.FileName(self)
            out=self.FileName_;
        end
    end
    
    methods
        % digital signals should be returned as doubles and are thresholded at 0.5
        function y = calculateCoreSignal(self, stimulus, t, trialIndexWithinSet)  %#ok<INUSL>
            %eval(['i=trialIndexWithinSet; fileNameAfterEvaluation=' self.FileName ';']);
            fileNameAfterEvaluation = ws.stimulus.Stimulus.evaluateStringTrialTemplate(self.FileName,trialIndexWithinSet);
            if isempty(fileNameAfterEvaluation) ,
                y=zeros(size(t));
            else
                try
                    [yInFile,fs] = audioread(fileNameAfterEvaluation);
                    tInFile = (0:length(yInFile)-1)./fs ;
                    y = interp1(tInFile, yInFile, t, 'linear', 0);
                catch me
                    if isequal(me.identifier,'MATLAB:audiovideo:audioread:fileNotFound') ,
                        y=zeros(size(t));
                    else
                        rethrow(me);
                    end
                end                
            end
        end  % function
        
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
            propertyNamesToCompare={'FileName'};
            value=isequalElementHelper(self,other,propertyNamesToCompare);
       end
    end
    
end

