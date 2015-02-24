classdef Spinner < ws.most.gui.control.PropControl
    %SPINNER Pseudo-control for a single-valued "spinner", a pairing of an editBox
    %and slider representing an adjustable numeric valuevalue

    % TODO: Deal with positive, negative, nonnegative, etc type model property attributes, each of which should replace one of '<=' or '>=' attribute requirements
    % TODO: Reject any model property attributes incompatible with spinner control
    % TODO: Deal with 'even' and 'nonzero' model property attribute case
    % TODO: Handle dynamic range values from model, perhaps adding listener(s) to any model properties reflecting range, so that control can be automatically updated
    
    
    %% ABSTRACT PROPERTY REALIZATIONS (PropControl)
    properties (Dependent)
        propNames;
        hControls        
    end
    
    %% SUPERUSER PROPERTIES 
    properties
        hSlider; % handle to slider uicontrols
        hEdit; % col vec of handles to edit boxes
        propName; % the name of the model property backing the spinner
    end
    
    properties (Dependent)        
        propRange; %2 element array specifying range of property
        stepVal; %Scalar or 2 element array specifying step value for slider control, [arrowStep barStep]. If barStep is not specified, it is assumed 10x larger than arrowStep.
    end
    
    %% DEVELOPER PROPERTIES
    properties (Hidden,SetAccess=protected)
        integerOnly = false; %Logical indicating if only integer values are to be supported
        viewPrecision; % Either {} for no viewPrecision, or a cell array containing an integer indicating number of significant digits to use in editbox
    end
        
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        % obj = Spinner(hSlider,hEdit,pvArgs)
        % hSlider, hEdit: col vec of handles to slider/editbox uicontrols.
        % pvArgs: Optional property-value pairs used to set object properties on construction
        
        function obj = Spinner(hSlider,hEdit,varargin)
            error(nargchk(2,inf,nargin,'struct'));           

            if ~isscalar(hSlider) || ~ishandle(hSlider) || ~strcmpi(get(hSlider,{'Style'}),'slider')
                error('Spinner:InputArgInvalidType',...
                    'hSlider must be uicontrol handle of Style ''slider''.');
            end
            
            if ~isscalar(hEdit) || ~ishandle(hEdit) || ~strcmpi(get(hEdit,{'Style'}),'edit')
                error('Spinner:InputArgInvalidType',...
                    'hEdit must be uicontrol handles of Style ''edit''.');
            end
            
            obj.hSlider = hSlider;
            obj.hEdit = hEdit;            
        end

        % metadata is a struct with one field, the prop name. The value for
        % this field is the default PropControl data.
        function init(obj,metadata)
            pname = fieldnames(metadata);
            assert(numel(pname)==1);
            pname = pname{1};
            metadata = metadata.(pname);
            
            obj.propName = pname;
            
            % Init viewPrecision
            if isfield(metadata,'ViewPrecision')
                validateattributes(metadata.ViewPrecision,{'numeric'},{'positive' 'integer' 'scalar'});
                obj.viewPrecision = {metadata.ViewPrecision};
            else
                obj.viewPrecision = {};
            end
           
            %Initialize slider range 
            assert(isfield(metadata,'ModelPropAttribs'));
            hPropData = metadata.ModelPropAttribs;
            
            errMsg = sprintf('The property ''%s'' is bound to a Spinner control without specifying Range in model property metadata.',pname);
            if isfield(hPropData,'Range')
                range = hPropData.Range;
            elseif isfield(hPropData,'Attributes')
                % AL: this doesn't look like it is going to work, ismember
                % will expect hPropData.Attributes to be a cellstr
                [tf loc] = ismember({'>=' '<='},hPropData.Attributes);
                assert(all(tf),errMsg);
                range = [hPropData.Attributes{loc(1)+1}; ...
                         hPropData.Attributes{loc(2)+1}];
            else
                error(errMsg); %#ok<SPERR>
            end
            
            % Scale range per viewScaling
            if isfield(metadata,'ViewScaling')
                range = range*metadata.ViewScaling;
            end

            set(obj.hSlider,'Min',range(1),'Max',range(2));
            
            %Determine if integer-only constraint exists
            obj.integerOnly = isfield(hPropData,'Attributes') && ismember('integer',lower(hPropData.Attributes));
                        
            %Initialize slider step, if needed
            if obj.integerOnly
                obj.stepVal = obj.stepVal; %Will apply integer constraint
            end
            
        end
    end
    
    %% PROPERTY ACCESS
    methods

        function hControls = get.hControls(obj)
            hControls = [obj.hSlider;obj.hEdit];
        end
        
        function propNames = get.propNames(obj)
            propNames = {obj.propName};
        end
        
        function val = get.propRange(obj)
            min = get(obj.hSlider,'Min');
            max = get(obj.hSlider,'Max');
            val = [min max];
        end
        
        function val = get.stepVal(obj)
            sliderStep = get(obj.hSlider,'SliderStep');                    
            val = sliderStep * diff(obj.propRange);
        end
        
        function set.stepVal(obj,val)
            validateattributes(val,{'numeric'},{'vector' 'finite' 'positive'});
            assert(numel(val)<=2,'Value must be scalar or a two-element array');
                
            propRange = obj.propRange;
            
            %Compute arrow/bar step values
            arrowStep = znstConvertStep(val(1));
            if numel(val) < 2
                barStep = 10 * arrowStep;
            else
                barStep = znstConvertStep(val(2));
            end        
            
            %Set slider step property
            set(obj.hSlider,'SliderStep',[arrowStep barStep]);
            
            return;
            
            function fracStep = znstConvertStep(incrementStep)
                fracStep = incrementStep / propRange;
                
                if obj.integerOnly
                   fracStep = round(fracStep); 
                end
            end
        end
        
    end
    
    %% PUBLIC METHODS
    methods
        function [status propname val] = decodeFcn(obj,hObject,~,~)
            
            % first compute the new value
            switch get(hObject,'style')
                case 'slider'
                    val = get(hObject,'Value');
                case 'edit'
                    val = str2double(get(hObject,'String'));
                otherwise
                    assert(false);
            end
            
            propname = obj.propName;
            status = 'set'; %Always set, leave it to model to handle validation/reversion, as needed
        end
        
        function encodeFcn(obj,~,newVal)
            set(obj.hSlider,'Value',newVal);
            strVal = num2str(newVal,obj.viewPrecision{:});
            set(obj.hEdit,'String',strVal);
        end
    end
        

    
end


