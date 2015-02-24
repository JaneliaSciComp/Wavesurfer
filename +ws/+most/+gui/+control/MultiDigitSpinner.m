classdef MultiDigitSpinner < ws.most.gui.control.PropControl
    %MULTIDIGITSPINNER Pseudo-control for a "spinner", a group of editBoxes
    %and sliders representing a floating point value
    %
    % In a MultiDigitSpinner, each digit of a number is shown in an edit
    % box. These digits may be edited directly in the edit box. Each edit
    % box also has a slider behind it, positioned so that only the up- and
    % down- arrows are visible. Clicking these arrows increment/decrement
    % the corresponding digit.
    
    %% ABSTRACT PROPERTY REALIZATIONS (PropControl)
    properties (Dependent)
        propNames;
        hControls        
    end
    
    %% PUBLIC PROPERTIES
    properties
        hSliders; % col vec of handles to slider uicontrols
        hEdits; % col vec of handles to edit boxes
        base; % scalar int, the base of the numerical representation (typically, 10)
        exponents; % row vec of integer exponents, one for each slider/editbox proceeding from left to right
        maxValue; % scalar int, one greater than the maximum value representable in the spinner
        propName; % the name of the model property backing the spinner
    end
        
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        % obj = MultiDigitSpinner(sliders,edits,baseval,minexponent)
        % sliders/edits: col vec of handles to slider/editbox uicontrols.
        % baseval (optional): base value of numerical representation.
        % defaults to 10.
        % minexponent (optional): the exponent for the least significant
        % (rightmost) digit. defaults to 0. For example, if the spinner has
        % three digits and the last digit represents 1/10ths, then
        % minexponent==-1.
        function obj = MultiDigitSpinner(sliders,edits,baseval,minexponent)
            error(nargchk(2,4,nargin,'struct'));
            
            if numel(sliders)~=numel(edits)
                error('MultiDigitSpanner:InputArgDimMismatch',...
                    'The number of slider controls must equal the number of edit controls.');
            end
            if ~all(ishandle(sliders(:))) || ~all(strcmp(get(sliders,{'Style'}),'slider'))
                error('MultiDigitSpanner:InputArgInvalidType',...
                    'All sliders must be uicontrol handles of Style ''slider''.');
            end
            if ~all(ishandle(edits(:))) || ~all(strcmp(get(edits,{'Style'}),'edit'))
                error('MultiDigitSpanner:InputArgInvalidType',...
                    'All edits must be uicontrol handles of Style ''edit''.');
            end
            
            if nargin < 3
                baseval = 10;
            end
            validateattributes(baseval,{'numeric'},{'scalar';'positive';'integer';'finite'});
            
            if nargin < 4
                minexponent = 0;
            end
            validateattributes(minexponent,{'numeric'},{'scalar';'integer';'finite'});

            % set slider/editbox uicontrol props
            set(sliders,'Min',-1);
            set(sliders,'Max',baseval);
            set(sliders,'SliderStep',[1/(baseval+1) 0]);

            Ndigits = numel(sliders);
            obj.hSliders = sliders(:);
            obj.hEdits = edits(:);
            obj.base = baseval;
            obj.exponents = ((minexponent+Ndigits-1):-1:minexponent)';
            obj.maxValue = obj.base^(obj.exponents(1)+1);
        end

        % For a MultiDigitSpinner, metadata is a struct with one field, the
        % prop name (the value is unused)
        function init(obj,metadata)
            pname = fields(metadata);
            assert(numel(pname)==1);
            obj.propName = pname{1};
        end
    end
    
    %% PROPERTY ACCESS
    methods
        function hControls = get.hControls(obj)
            hControls = [obj.hSliders;obj.hEdits];
        end
        
        function propNames = get.propNames(obj)
            propNames = {obj.propName};
        end
    end
    
    %% PUBLIC METHODS
    methods
        function [status propname val] = decodeFcn(obj,hObject,~,~)
            
            % first compute the new value
            switch get(hObject,'style')
                case 'slider'
                    val = obj.getValueFromSliders();
                case 'edit'
                    val = obj.getValueFromEdits();
                otherwise
                    assert(false);
            end
            
            propname = obj.propName;

            % keep the slider "within bounds" by reverting if it strays
            % outside the interval [0,maxValue)
            if val >= obj.maxValue || val < 0
                status = 'revert';
            else
                status = 'set';
            end
        end
        
        function encodeFcn(obj,~,newVal)
            if newVal >= obj.maxValue || newVal < 0
                warning('MultiDigitSpinner:outOfBounds',...
                    'Value out of bounds.');
                newVal = mod(newVal,obj.maxValue);
            end
            exps = obj.exponents;
            bse = obj.base;
            slds = obj.hSliders;
            edits = obj.hEdits;
            for c = 1:numel(edits)
                chunk = bse^exps(c);
                % special treatment for last digit to deal with rounding
                % error
                if c==numel(edits)
                    digit = round(newVal/chunk);
                else
                    digit = floor(newVal/chunk);
                end
                set(edits(c),'String',num2str(digit));
                set(slds(c),'Value',digit);
                newVal = newVal-digit*chunk;
            end
        end        
    end
        
    %% PRIVATE/PROTECTED METHODS
    methods (Access=protected)
        function v = getValueFromEdits(obj)
            digits = cellfun(@str2num,get(obj.hEdits,{'String'}));
            vals = digits.*(obj.base).^(obj.exponents);
            v = sum(vals);
        end
        
        function v = getValueFromSliders(obj)
            digits = cell2mat(get(obj.hSliders,{'Value'}));
            vals = digits.*(obj.base).^(obj.exponents);
            v = sum(vals);
        end        
      
    end
    
end


