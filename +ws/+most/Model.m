classdef Model < handle
    %MODEL Shared functionality for classes which are identifiable as 'models' (rig/user-level)
    
    %Shared functionality includes:
    %
    %   Property validation: 
    %       * property attributes specify constraints on class & value of properties 
    %   Property serialization:
    %       * store & restore 'property sets', arbitrary collections of 'settable' properties, respecting order in mdlPropAttributes
    %       * readout of all 'gettable' properties
    %   Controller association:
    %       * Controllers initialized/deleted along with model
    %       * Controller 'robot mode' managed when doing large batch property changes in Model
    %   
    %   By convention, 'settable' propeties are referred to as 'configurable' (files storing property sets may be called model configuration files), 
    %   and 'gettable' properties are referred to as 'headerable' (the readout may be stored to model data file headers)
    %   
    %  Subclasses must specify a mdlPropAttributes structure property whose fields
    %  specify attributes for same-named properties of this class
    %   
    %  The property attributes are specified via same-named fields a nested structure, one of:
    %    * 'Classes': Constrain prop to one or more valid classes as defined in ws.most.mimics.validateAttributes
    %    * 'Attributes': Constrain prop to one or more valid classes as defined in ws.most.mimics.validateAttributes
    %    * 'DependsOn': Declare list of properties on whose values this property's value depends
    %
    %   Validation: Validation of properties is provided by the validatePropArg() method
    %
    %   PropSets: The mdlSavePropSet/mdlApplyPropSet/mdlLoadPropSet methods (and related) provide
    %    interface for serialized storing and restoring of full/partial object state. 
    %   
    %   Property Ordering: The order of properties in the mdlPropAttributes struct is honored
    %    for initialization & mdlApplyPropSet() method calls
    %       * Empty-valued property structures may be entered in mdlPropAttributes in order to enforce ordering without other constraints/attributes
    %         
    %   SubModels: This class supports up to one-level of 'submodel' hierarchy, where a Model can
    %   own one or more SubModel classes whose property attributes are stored
    %       * If Class is specified as 'ws.most.Model', the mdlPropAttributes of
    %         that submodel class will be nested into the root model's
    %         mdlPropAttributes struct, during initialize().
    %
    %   DependsOn Specification: Properties can be identified as depending
    %   on other properties of the same Model, or of another Model and
    %   referenced from the DependsOn property Model. 
    %
    %     s.DependentProp = struct('DependsOn',{'prop1' 'hSibling.prop2' 'hParent.prop3' 'hParent.hSibling2.prop4'});
    %   
    %   

    %TODO: Submodel: Any call to save properties in a Most.model object will save all properties to the file
    %      specified in the top level object. The top level object queries each submodel for its properties as well.
    %TODO: Submodel: Any call to load properties in a Most.model object will write values for all properties in the file to the appropriate submodels.
    %TODO: Submodel: Why is loading scanimage so slow?
    
    %TODO: Allow general property-replacement throughout the property metadata table -- could use to specify 'size' attribute of a property, for instance
    %TODO: Use subsref to allow avoiding need to make boilerplate set-access methods
    %TODO: Allow 'Callback' specification in property attributes -- this will only work in concert somehow with subsref scheme
    %TODO: When validation fails with Options list -- error message should provide the list of valid options    
    %TODO: Better handle the case of empty vaues together with Options list..
    %TODO: Resolve issue -- should we expect that initialize() is /always/ called for a Model? (effectively a 'finalizer' method to complement constructor)

    %% ABSTRACT PROPERTIES
    properties (Abstract, Hidden, SetAccess=protected)
        mdlPropAttributes; %A structure effecting Map from property names to structures whose fields are Tags, with associated values, specifying attributes of each property
        
        %OPTIONAL (Can leave empty)
        mdlHeaderExcludeProps; %String cell array of props to forcibly exclude from header
    end
    
    
    %% SUPERUSER PROPERTIES 
    properties (Hidden)
        mdlVerbose = false; %Indicates whether model should provide command-line warnings/messages otherwise suppressed        
        
        mdlInitialized = false; %Flag indicating whether model has been initialized        
        
        mdlApplyingPropSet = false; %Flag indicating whether a batch property set operation is underway
    end
    
    
    %% DEVELOPER PROPERTIES
    %'Friend' properties -- SetAccess would ideally be more restricted
    properties (Hidden,SetAccess=protected)
        hController={}; %Handle to Controller(s), if any, linked to this object 
        mdlHParent; %Handle to parent Model object, for submodels
        
        mdlDependsOnListeners; %Structure, whose fields are names of properties with 'DependsOn' property metadata tag, and whose values are an array of set listener handles        
        mdlSubModelClasses={}; %String cell array of submodels declared for this class. Their mdlPropAttributes will be aggregated into this object's mdlPropAttributes.
        
    end
    
    properties (Access=private,Dependent)
        mdlPropSetVarName; % object-dependent variable name used in propset MAT files
    end
    
    %% CONSTRUCTOR/DESTRUCTOR    
    methods (Hidden)
        
        function obj = Model()
            znstProcessPropAttributes(); %Process property attributes            
       
            function znstProcessPropAttributes()
                
                propNames = fieldnames(obj.mdlPropAttributes);
                
                for i=1:length(propNames)
                    currPropMD = obj.mdlPropAttributes.(propNames{i});
                    
                    %Processing Step 1: Store list of props specifying submodels (ie. Classes constraint is 'ws.most.Model')s
                    if isfield(currPropMD,'Classes')
                        assert(isstruct(currPropMD));
                        
                        x = currPropMD.Classes;
                        if ischar(x)
                            f = {x};
                        else
                            f = fieldnames(x);
                        end
                        
                        if ismember('ws.most.Model', f)
                            assert(isscalar(f) && isscalar(fieldnames(currPropMD)),'Property Class constraint to ws.most.Model cannot be combined with other Class constraints or property attribute specification. Violated for property ''%s''.',propNames{i});
                            
                            obj.mdlSubModelClasses{end+1} = propNames{i};
                        end
                        
                    end
                    
                    %Processing Step 2: Fill in Classes = 'numeric' if 'Classes' not provided and any of Range/Attributes/Size are set (meaning validateattributes() will get called)
                    if ~isfield(currPropMD,'Classes') && any(ismember(fieldnames(currPropMD),{'Range' 'Size' 'Attributes'}))
                        currPropMD.Classes = 'numeric';
                    end                    
                    
                    %Processing Step 3: Fill in AllowEmpty=false if 'AllowEmpty' not specified
                    if ~isfield(currPropMD,'AllowEmpty')
                        currPropMD.AllowEmpty = false;
                    end                    
            
                    obj.mdlPropAttributes.(propNames{i}) = currPropMD;
                end                

            end
            
        end
        
        
        function delete(obj)
            for c = 1:numel(obj.hController)
                ws.most.idioms.safeDeleteObj(obj.hController{c});
                obj.hController{c}=[];
            end
        end
        
    end
    
    methods (Access=protected, Hidden)

        function mdlInitialize(obj)
            %Initialize Model properties & state, as needed
            %post-construction.
            %
            %Calling initialize() post-construction (and after binding of
            %any associated) is the standard convention for ws.most.Model
            %usage; often it is necessary. 
            % 
            %For Models with associated submodel(s), the initialize()
            %method should only be called directly on the root submodel                                                         
             
           
            %Identify root/submodel hierarchy & aggregate mdlPropAttributes
            for i=1:length(obj.mdlSubModelClasses)                
                submodelName = obj.mdlSubModelClasses{i};
                hSub = obj.(submodelName);

                hSub.mdlHParent = obj;
                obj.mdlPropAttributes.(submodelName) = hSub.mdlPropAttributes;
            end    
            
            %Root-model only actions
            if isempty(obj.mdlHParent)
                
                %Process properties with 'DependsOn' tags, using intermediate listeners
                obj.ziniBindDependsOnListeners();
                
                %Where appropriate, auto-initialize props not initialized in class definition file
                %VVV: How is (or isn't) this submodel compatible?
                obj.ziniInitializeOptionProps();
                
                %Iteratively initialize() any associated submodels                
                for i=1:length(obj.mdlSubModelClasses)
                    obj.(obj.mdlSubModelClasses{i}).mdlInitialize()
                end
            end
                       
            
            %Eigenset all settable properties of this Model, and any associated Controller(s)
            obj.zzzSetCtlrRobotMode();
            try 
                obj.ziniInitializeModelProps();
                
                %Initialize Controller object(s) associated with the Root model (if this is the Root)
                if isempty(obj.mdlHParent)                       
                    for i=1:length(obj.hController)
                        obj.hController{i}.initialize();
                    end
                end
            catch ME
                obj.zzzResetCtlrRobotMode();
                ME.rethrow();
            end                
            obj.zzzResetCtlrRobotMode();
                
            %Set flag indicating model has been initialized
            obj.mdlInitialized = true;
        end
    end
    
    methods (Access=private, Hidden)
        
        function ziniInitializeModelProps(obj)
            %Initialize all model object properties with side-effects, respecting any order specified by mdlPropAttributes
            
            mc = metaclass(obj);
            props = mc.Properties;
            propNames = cellfun(@(x)x.Name,props,'UniformOutput',false);
            propNames = obj.zzzOrderPropList(propNames);
            
            for i=1:length(propNames)
                mp = findprop(obj,propNames{i});
                if ~isempty(mp.SetMethod) && isequal(mp.SetAccess,'public')
                    obj.(propNames{i}) = obj.(propNames{i}); %Forces set-access method to be invoked
                end
            end
            
        end
        
        function ziniBindDependsOnListeners(obj)            
            propAttribs = ws.most.util.structOrObj2List(obj.mdlPropAttributes);
            for i=1:length(propAttribs)
                
                k = strfind(propAttribs{i},'.DependsOn');
                
                if ~isempty(k)
                    
                    %Strip off '.DependsOn' to reveal the propName
                    propNameFull = propAttribs{i}(1:k-1);
                    [propName,mdlName] = zlclFull2ShortPropName(propNameFull);
                    
                    %Determine object that directly owns the specified property
                    if isempty(mdlName)
                        hObj = obj;
                    else
                        hObj = eval(['obj.' mdlName]);
                    end                    
                    
                    dependsOnList = eval(['obj.mdlPropAttributes.' propAttribs{i}]);
                    
                    %Ensure/make Tag value a cell string array
                    assert(ischar(dependsOnList) || iscellstr(dependsOnList),'DependsOn tag was supplied for property ''%s'' with incorrect value -- must be a string or string cell array',propNameFull);
                    if ischar(dependsOnList)
                        dependsOnList = {dependsOnList};
                    end
                    
                    %Ensure dependent property has a set property-access method
                    mp = zzzFindPropRecursive(obj,propNameFull); %Use recursive findprop (submodel change)
                    assert(~isempty(mp.SetMethod),'Properties with ''DependsOn'' tag specified must have a set property-access method defined (typically empty). Property ''%s'' violates this rule.',propNameFull);
                    
                    %Bind listener to each of the properties this one 'dependsOn'
                    listenerArray = event.proplistener.empty();
                    
                    
                    for j=1:length(dependsOnList)
                        dpdPropNameFull = dependsOnList{j};
                        
                        [dpdPropName, hDdpPropPath] =  zlclFull2ShortPropName(dpdPropNameFull);
                        
                        if isempty(hDdpPropPath)
                            hDpdObj = hObj;
                        else
                            hDpdObj = eval(['hObj.' hDdpPropPath]);
                        end
                        
                        %Validate that property can be specified as depends-on
                        mpDpd = findprop(hDpdObj, dpdPropName);
                        assert(~isempty(mpDpd) && mpDpd.SetObservable,'Properties specified as ''DependsOn'' tag value must exist and be SetObservable. The DependsOn property ''%s'' for the property ''%s'' violates this rule.',dependsOnList{j},propNameFull);
                        
                        %Add listener to DependsOn dependee prop that executes dummy prop set on the original depender prop
                        listenerArray = [listenerArray hDpdObj.addlistener(dpdPropName,'PostSet',@(src,evnt)znstDummySet(src,evnt,hObj,propName))]; %#ok<AGROW> %TMW: Somehow it's not allowed to use trick of growing array from end to first, with first assignment providing the allocation.
                    end
                    
                    propName_ = strrep(propNameFull,'.','___');
                    obj.mdlDependsOnListeners.(propName_) = listenerArray;
                end
            end
            
            function znstDummySet(~,~,hObj,propName)
                %Set specified property to dummy value -- for purpose of allowing any SetObserving listeners to fire
                hObj.(propName) = nan;
            end            
            
        end
        
        function ziniInitializeOptionProps(obj)
            
            propNames = fieldnames(obj.mdlPropAttributes);
            for i=1:length(propNames)
                propMD = obj.mdlPropAttributes.(propNames{i});
                
                if isfield(propMD,'Options')
                    
                    if isempty(obj.(propNames{i})) && (~isfield(propMD,'AllowEmpty') || ~propMD.AllowEmpty)
                        optionsList = propMD.Options;
                        
                        %TODO: Global/general string replacement in Model property metadata
                        if ischar(optionsList)
                            optionsList = obj.(propMD.Options);
                        end
                        
                        if isnumeric(optionsList)
                            if isvector(optionsList)
                                defaultOption = optionsList(1);
                            elseif ndims(optionsList)
                                defaultOption = optionsList(1,:);
                            else
                                assert(false);
                            end
                        elseif iscellstr(optionsList)
                            defaultOption = optionsList{1};
                        else
                            assert(false);
                        end
                        
                        
                        if isfield(propMD,'List')
                            listSpec = propMD.List;
                            
                            %TODO: Global/general string replacement in Model property metadata
                            if ischar(listSpec) && ~ismember(lower(listSpec),{'vector' 'fullvector'})
                                listSpec = obj.(propMD.List);
                            end
                            
                            if isnumeric(listSpec)
                                if isscalar(listSpec)
                                    initSize = [listSpec 1];
                                else
                                    initSize = listSpec;
                                end
                            else %inf, 'vector', 'fullvector' options -- init with scalar value
                                initSize = [1 1];
                            end
                            
                            obj.(propNames{i}) = repmat({defaultOption},initSize);
                        else
                            obj.(propNames{i}) = defaultOption;
                        end
                        
                    end
                end
            end
        end
        
        
    end

    
    %% EXTERNAL API
    methods (Hidden)
          function val = validatePropArg(obj,propname,val)

            % Validate/convert a property value, using specifications as in
            % ws.most.mimics.validateAttributes.
            %           
            % TAGS
            %
            %   Classes: <String or string cell array> As in ws.most.mimics.validateAttributes.
            %   Attributes: <String or cell array> As in ws.most.mimics.validateAttributes.
            %   AllowEmpty: <0 or 1> Specifies whether to allow empty values. This removes the 'nonempty' attribute supplied by default, and also enables 'AllowEmptyDouble' as in ws.most.mimics.validateAttributes.
            %   Range: <Numeric or cell 2-vector or string> If numeric, as in ws.most.mimics.validateAttributes. If a cell array, string values are the names of object properties supplying the min/max value for the range. If a string, the name of single property supplying the numeric 2-vector range.
            %   Size: <Numeric or cell array or string> If numeric, as in ws.most.mimics.validateAttributes. If a cell array, elements are either numbers (sizes along dimensions) or object property names which return numbers. If a string, the name of a single property supplying the 'size' specification.
            %   Options: <Cell or numeric array, or string>  If a cell or numeric array, as in ws.most.mimics.validateAttributes. If a string, the name of an object property supplying the options specification.
            %   List: <Integer scalar/array, or empty val, or Inf, or string member of {'vector' 'fullvector'}, or string> As in ws.most.mimics.validateAttributes, unless a string. If a string, then the name of an object property supplying the list specification.
            %   CustomValidateFcn: <scalar fcn handle with signature val=f(val). The function should throw an error for invalid values, and return an (optionally) converted value. For property validation, this overrides all other tags. (Other tags may be present in the metadata for other purposes however.)
            %
            % NOTES
            %   * The 'nonempty' attribute is included by
            %   default. This can be overridden by using the
            %   AllowEmpty tag.
            %   The 'scalar' attribute is included by default. This is
            %   overridden when one of {'size' 'vector' 'numel'
            %   'nonscalar'} is included in the Attributes, when Options
            %   are specified, etc.
            %
            % TIPS
            %   Options (of numeric type) and Size tags can be combined for properties which are matrices comprising a list of array-values, with both the array-value options and the length being specifiable (possibly as object properties).
            %   To test for a flexible logical array (either 0/1 or true/false array), specify 'binary' as one of Attributes (no need to specify Classes)
            %
            %   TODO: What to do with AllowEmpty & Options combination?? For numeric Options, at moment empty values are not allowed, but they might want to be in some cases??
            %   TODO: Support for Size more/all of the options that are supported for List (Inf, empty val)
            
            ERRORARGS = {'most:Model:invalidPropVal', ...
                'Invalid value for property ''%s'' supplied:\n\t%s\n',...
                propname};
            
            propMDAll = obj.mdlPropAttributes;
            
            if isfield(propMDAll,propname)
                propMD = propMDAll.(propname);
                
                if isfield(propMD,'CustomValidateFcn')
                    fcn = propMD.CustomValidateFcn;
                    try
                        val = fcn(val);
                    catch ME
                        error(ERRORARGS{:},ME.message);
                    end
                    return;
                end

                if isfield(propMD,'Classes');
                    propMD.Classes = cellstr(propMD.Classes(:)');  
                elseif ~isfield(propMD,'options') && any(isfield(propMD,{'Attributes' 'Size' 'Range'}))
                    % default to numeric
                    propMD.Classes = {'numeric'};
                end
                
                if isfield(propMD,'Attributes');
                    if ischar(propMD.Attributes)
                        propMD.Attributes = {propMD.Attributes};
                    end
                    propMD.Attributes = propMD.Attributes(:)';
                else
                    propMD.Attributes = cell(1,0);
                end
                
                if isfield(propMD,'Range')
                    try
                        rangeAttribs = obj.zzzRangeData2Attribs(propname,propMD.Range);
                    catch ME
                        ME.throwAsCaller();
                    end
                    propMD.Attributes = [propMD.Attributes rangeAttribs];
                end
                
                if isfield(propMD,'Size')
                    try
                        sizeAttribs = obj.zzzSizeData2Attribs(propname,propMD.Size);
                    catch ME
                        ME.throwAsCaller();
                    end
                    propMD.Attributes = [propMD.Attributes sizeAttribs];
                end
                
                if isfield(propMD,'Options')
                    if ischar(propMD.Options)
                        propMD.Options = obj.(propMD.Options);
                    end
                end
                
                if isfield(propMD,'List')
                    listVal = propMD.List;
                    if ischar(listVal)
                        switch lower(listVal)
                            case {'vector' 'fullvector'}
                            otherwise
                                propMD.List = obj.(listVal);
                        end
                    end
                end
                    
                tfAllowEmpty = isfield(propMD,'AllowEmpty') && propMD.AllowEmpty;
                if tfAllowEmpty
                    % At moment, not actively removing 'nonempty' if it's in
                    % attributes with AllowEmpty.
                    %
                    % AL: Strictly speaking the next line is wrong, what if
                    % someone wants to enable empties, but still restrict
                    % the class?
                    propMD.AllowEmptyDouble = true;                    
                else
                    if isfield(propMD,'Options') && iscell(propMD.Options)
                        % attribs ignored when using cell options
                    else                        
                        propMD.Attributes = [propMD.Attributes 'nonempty'];
                    end
                end

                tfCharAttrib = cellfun(@ischar,propMD.Attributes);
                charAttrib = propMD.Attributes(tfCharAttrib);
                if isfield(propMD,'Options')
                elseif isfield(propMD,'AllowEmpty') && propMD.AllowEmpty
                elseif isfield(propMD,'Classes') && any(strcmpi('string',propMD.Classes))
                elseif any(ismember({'nonscalar' 'size' 'numel' 'vector'},lower(charAttrib)))
                else
                    %Add 'scalar' attribute, by "default"
                    propMD.Attributes = [propMD.Attributes 'scalar'];
                end
                                
                cellPV = ws.most.util.structPV2cellPV(propMD);
                try
                    ws.most.mimics.validateAttributes(val,cellPV{:});
                catch ME
                    error(ERRORARGS{:},ME.message);
                end
                
                % AL: we used to convert empty values for cellstr/string
                % classes:
                %                 if isempty(val)
                %                     assert(allowEmpty,errorArgs{:});
                %                     if ismember('cellstr',classesData)
                %                         val = {};
                %                     else
                %                         val = '';
                %                     end
                %                 end
                
            end
            
        end
        

        
        % xxx make this more consistent with config?
        function str = mdlGetHeaderString(obj,subsetType,subsetList,numericPrecision)
            % Get string encoding of the header properties of obj.
            %   subsetType: One of {'exclude' 'include'}

            %   subsetList: String cell array of properties to exclude from or include in header string
            %   numericPrecision: <optional> Number of digits to use in string encoding of properties with numeric values. Default value used otherwise.
            
            if nargin < 4 || isempty(numericPrecision)
                numericPrecision = []; %Use default
            end
            
            if nargin < 2 || isempty(subsetType)
                pnames =  obj.mdlGetHeaderableProps();
            else
                assert(nargin >= 3,'If ''subsetType'' is specified, then ''subsetList'' must also be specified');
                
                switch subsetType
                    case 'exclude'
                        pnames = setdiff(obj.mdlGetHeaderableProps(),subsetList);
                    case 'include'
                        pnames = subsetList;
                    otherwise
                        assert('Unrecognized ''subsetType''');
                end
            end                                                                                               
             
            str = ws.most.util.structOrObj2Assignments(obj,class(obj),pnames,numericPrecision);
        end                     

        
    end
    
    %%% PropSet API
    
    methods (Hidden)
        % Save a propset to the specified MAT-file. The file is assumed to
        % be a MAT-file. The propSet is overwritten/appended to the
        % MAT-file.
        function mdlSavePropSet(obj,propSet,fname)
            assert(isstruct(propSet));
            assert(ischar(fname));

            varname = zlclVarNameForSaveAndRestore(class(obj));
            tmp.(varname) = propSet; %#ok<STRNU>
            
            % if (varname) already exists in the file, it will be
            % overwritten
            if exist(fname,'file')==2
                save(fname,'-struct','tmp','-mat','-append');
            else
                save(fname,'-struct','tmp','-mat');
            end
        end
        
        function mdlSavePropSetFromList(obj,propList,fname)
            propSet = obj.zzzGetPropSet(propList);
            obj.mdlSavePropSet(propSet,fname);            
        end
        
        
        % Apply a propSet to obj. Original values for the affected
        % properties are returned in origPropSet.
        %
        % tfOrderByPropAttribs (optional): bool, default=true. If true,
        % then apply the property sets in the order specified by
        % obj.mdlPropAttributes. If false, apply property sets in the order
        % of fields in propSet.
        function origPropSet = mdlApplyPropSet(obj,propSet,tfOrder)
            assert(isstruct(propSet));
            
            if nargin < 3 || isempty(tfOrder)
                tfOrder = true;
            end
            
            propNames = fieldnames(propSet);
            if tfOrder
                propNames = obj.zzzOrderPropList(propNames);
            end
            
            obj.zzzSetCtlrRobotMode(); %Set controller(s)' robot mode
            obj.mdlApplyingPropSet = true;
            
            try
                origPropSet = struct();
                for c = 1:numel(propNames)
                    pname = propNames{c};
                    try
                        val = obj.(pname);
                        if isobject(val) && ismember(pname,obj.mdlSubModelClasses)
                            obj.(pname).mdlApplyPropSet(propSet.(pname));
                        elseif isobject(val)
                            % do nothing.
                        else
                            origPropSet.(pname) = val;
                            obj.(pname) = propSet.(pname);
                        end
                    catch ME
                        s = warning('backtrace','off');
                        warning('Model:errSettingProp',...
                            'Error getting/setting property ''%s''.\nMessage: %s\n(Line %d of function ''%s'').\n',...
                            pname,ME.message,ME.stack(1).line,ME.stack(1).name);
                        warning(s);
                        if ~isfield(origPropSet,pname)
                            origPropSet.(pname) = [];
                        end
                    end
                end
            catch ME
                obj.mdlApplyingPropSet = false;
                obj.zzzResetCtlrRobotMode();
                ME.rethrow();
            end
            
            obj.zzzResetCtlrRobotMode();
        end
        
        function mdlApplyPropSetFromList(obj,propSet,propList,tfOrder)
            %Apply a propSet to obj. Original values for the affected
            % properties are returned in origPropSet.
            %
            % SYNTAX:
            %   mdlApplyPropSetFromList(obj,propList,tfOrderByPropAttribs)
            %
            %   propSet: Struct containing set of property vlaues to be applied
            %   propList: String cell array listing the properties
            %   tfOrderByPropAttribs (optional): bool, default=true. If true,
            %       then apply the property sets in the order specified by
            %       obj.mdlPropAttributes. If false, apply property sets in
            %       the order of fields in propSet.
            
            if nargin < 4
                tfOrder = [];
            end
            
            propSet = obj.zzzGetPropSet(propList,propSet);
            obj.mdlApplyPropSet(propSet,tfOrder);
            
        end
        
         % Load contents of propSet file to propSet struct.
        function propSet = mdlLoadPropSetToStruct(obj,fname)

            assert(exist(fname,'file')==2,'File ''%s'' not found.',fname);
            if isempty(obj)
                propSet = [];
                return;
            end            
            
            fileVars = load(fname,'-mat');
            varname = zlclVarNameForSaveAndRestore(class(obj));
            if ~isfield(fileVars,varname)
                error('DClass:varNotFound',...
                    'No property information for class ''%s'' found in file ''%s''.',class(obj),fname);
            end
            
            propSet = fileVars.(varname);
        end
        
        function mdlLoadPropSet(obj,fname)
            propSet = obj.mdlLoadPropSetToStruct(fname);
            obj.mdlApplyPropSet(propSet);
        end
    end
    
    %%% CFG/HDR Default Prop API
    methods (Hidden)
        % %This routine will return a cell array of the model's
        % configurable properties, including those from its associated submodels.
        function cell = mdlGetConfigurableProps(obj)
            propList = obj.zzzGetClassConfigurableProps(class(obj));
            propList = [setdiff(propList,obj.mdlSubModelClasses'); obj.mdlSubModelClasses']; %Move handle-to-SubModel props to end of list
                        
            cell = {};
            for c = 1:numel(propList)
                pname = propList{c};
                try
                    val = obj.(pname);
                    if isobject(val) && ismember(pname,obj.mdlSubModelClasses) %Added this case for submodels.
                        cell = [cell; strcat(pname,'.',obj.zzzGetClassConfigurableProps(class(obj.(pname))))];
                    elseif isobject(val)
                        %Do nothing if the config prop is an object (submodel change)
                    else
                        cell = [cell; pname];
                    end
                catch %#ok<CTCH>
                    warning('DClass:mdlGetConfigurableProps:ErrDuringPropGet',...
                        'An error occured while getting property ''%s''.',pname);
                    % do nothing.
                end
            end
        end
        
        %This routine will return a cell array of the model's headerable
        %properties, including those from its associated submodels.
        function cell = mdlGetHeaderableProps(obj,excludeSubmodels)
            propList = setdiff(obj.zzzGetClassHeaderableProps(class(obj)), obj.mdlHeaderExcludeProps);
            propList = [setdiff(propList,obj.mdlSubModelClasses'); obj.mdlSubModelClasses']; %Move handle-to-SubModel props to end of list

            if nargin < 2 || isempty(excludeSubmodels)
                excludeSubmodels = false;
            end
            
            cell = {};
            for c = 1:numel(propList)
                pname = propList{c};
                try
                    val = obj.(pname);
                    if isobject(val)
                        if ismember(pname,obj.mdlSubModelClasses) && ~excludeSubmodels %Added this case for submodels.
                            hSub = val;
                            subPropList = hSub.mdlGetHeaderableProps;
                            cell = [cell; strcat(pname,'.',subPropList)]; %#ok<AGROW>
                        else
                            %no-op
                        end
                    else
                        cell = [cell; pname];
                    end
                catch %#ok<CTCH>
                    warning('DClass:mdlGetHeaderableProps:ErrDuringPropGet',...
                        'An error occured while getting property ''%s''.',pname);
                    % do nothing.
                end
            end
        end
    end    
  
    
    %%% Hidden API
    methods (Hidden)  
                        
        function mdlDummySetProp(obj,val,propName)
            %A standardized function to call from 'dummy' SetMethods defined for properties with 'DependsOn' metadata tag
            %Provides error message close to that which would normally be observed for setting a Dependent property with no SetMethod.
            assert(~obj.mdlInitialized || isnan(val),'In class ''%s'', no (non-dummy) set method is defined for Dependent property ''%s''.  A Dependent property needs a set method to assign its value.', class(obj), propName);
        end
        
        function mdlWarn(obj,warnMsg,varargin)
            if obj.mdlVerbose
                fprintf(2,[warnMsg '\n'],varargin{:});
            end
        end
        
    end
    
    %%% Friend API (use Hidden for simplicty)
    methods (Hidden)
        
        function mdlAddController(obj,hController)
            %hController: Array of Controller objects
            
            validateattributes(hController,{'ws.most.Controller'},{});
            
            for i=1:length(hController)
                obj.hController{end+1} = hController(i);
            end
        end   
        
        
        function options = mdlGetPropOptions(obj,propName)
            %Gets the list of valid values for the specified property, if it exists
            
            options = [];
            
            if isfield(obj.mdlPropAttributes, propName)
                propAtt = obj.mdlPropAttributes.(propName);
                
                if isfield(propAtt,'Options')
                    optionsData = propAtt.Options;
                    if ischar(optionsData)
                        if ~isempty(findprop(obj,optionsData))
                            options = obj.(optionsData);
                        else
                            error('Invalid Options property metadata supplied for property ''%s''.',propName);
                        end
                    else
                        options = optionsData;
                    end
                end
            end
            
        end
        
        function handle = mdlSetPropListenerFcn(obj,pname,event,callbackFcn)       
            %Create property listener object bound to specified property & property event (PreSet,PostSet,etc)
            % pname: Can be a direct property of obj or a dot-notated-prop with obj as the reference (e.g. 'h1.propName' where h1 is an object owned by obj). 
            %        In latter case, the listener is bound to the class directly owning the propName                                  
            
            [pnameShort,mdlName] = zlclFull2ShortPropName(pname); %Get short prop name, i.e. name referenced to its direct owner object (not root-object referenced)
                      
            % try
            if isempty(mdlName)
                handle = obj.addlistener(pnameShort,event,callbackFcn);
            else
                hObj = eval(['obj.' mdlName]);                                
                assert(isobject(hObj),'Unable to extract a Model owned property from the specified ''pname'' argument');                
                
                handle = hObj.mdlSetPropListenerFcn(pnameShort,event,callbackFcn);                          
            end                        
        end
        
    end


    %% INTERNAL METHODS
    methods (Access=private, Hidden)   
        
        %         function propNameFull = zzz2FullPropName(obj,propName)
        %             [basename, propName] = strtok(propName,'.');
        %             if isempty(propName)
        %                 propName = propName(2:end);
        %             end
        %         end
        %
    
        
        %This function is the recursive version of matlab's 'findprop'
        function mp = zzzFindPropRecursive(obj,propName)
            
            [propName_,mdlName] = zlclFull2ShortPropName(propName);
            
            if ~isempty(mdlName)
                mp = obj.(mdlName).zzzFindPropRecursive(propName_);
            else
                mp = findprop(obj,propName_);
            end
        end
        
           
        function sizeAttributes = zzzSizeData2Attribs(obj,propname,sizeData)
            
            ERRORARGS = {'Invalid ''Size'' property metadata supplied for property ''%s''.',propname};
            
            if ischar(sizeData)
                sizeAttributes = obj.zzzSizeData2Attribs(propname,obj.(sizeData));
            elseif isnumeric(sizeData)
                sizeAttributes = {'Size' sizeData};
            elseif iscell(sizeData)
                sizeVal = zeros(size(sizeData));
                for j=1:numel(sizeData)
                    sizeDataVal = sizeData{j};
                    if isnumeric(sizeDataVal)
                        sizeVal(j) = sizeDataVal;
                    elseif ischar(sizeDataVal) && ~isempty(findprop(obj,sizeDataVal))
                        tmp = obj.(sizeDataVal);
                        try
                            validateattributes(tmp,{'numeric'},{'scalar' 'integer' 'nonnegative'});
                        catch %#ok<CTCH>
                            error('most:Model:invalidSize',ERRORARGS{:});
                        end
                        sizeVal(j) = tmp;
                    else
                        error('most:Model:invalidSize',ERRORARGS{:});
                    end
                end
                sizeAttributes = {'Size' sizeVal};
            else
                error('most:Model:invalidSize',ERRORARGS{:});
            end            
        end
        
        function attribs = zzzRangeData2Attribs(obj,propname,rangeMD)
            ERRORARGS = {'Invalid ''Range'' property metadata supplied for property ''%s''.' propname};

            if ischar(rangeMD)
                attribs = obj.zzzRangeData2Attribs(propname,obj.(rangeMD));
            elseif isnumeric(rangeMD)
                assert(numel(rangeMD)==2,ERRORARGS{:});
                attribs = {'Range' rangeMD};
            elseif iscell(rangeMD)
                assert(numel(rangeMD)==2,ERRORARGS{:});
                rangeVal = nan(1,2);
                for idx = 1:2
                    if isnumeric(rangeMD{idx})
                        rangeVal(idx) = rangeMD{idx};
                    elseif ischar(rangeMD{idx})
                        rangeVal(idx) = obj.(rangeMD{idx}); % better be a numeric scalar
                    else
                        error('most:Model:invalidRange',ERRORARGS{:});
                    end
                end
                attribs = {'Range' rangeVal};
            else
                error('most:Model:invalidRange',ERRORARGS{:});
            end
        end
        
    end
        
        
    %%% Controller robot-mode handling    
    %TODO: Eliminate this layer by vectorizing the hController array (and having Controller handle)
    methods (Access=private, Hidden)
        
        function zzzSetCtlrRobotMode(obj)
            for i=1:length(obj.hController)
                obj.hController{i}.robotModeSet();
            end            
        end        
                
        function zzzResetCtlrRobotMode(obj)            
            for i=1:length(obj.hController)
                obj.hController{i}.robotModeReset();
            end
        end  
        
    end
        
    %%%  PropSet API Internals
    methods (Hidden) % Ultimately, protected
        % propList: a cellstr of property names to get
        % propSetIn (optional): a struct, possibly nested, containing property values
        % propSet: a struct going from propNames to property values.
        %
        % If propSetIn is supplied as input argument, that is used as
        % source of property values. Otherwise the supplied object is used.
        % 
        % Property values that are objects are ignored and set to [].
        function propSet = zzzGetPropSet(obj,propList,propSetIn)
            
            if nargin < 3
                src = obj;
            else
                src = propSetIn;
            end
            
            assert(iscellstr(propList),'propList must be a cellstring.');
            propSet = struct();
            for c = 1:numel(propList)
                pname = propList{c};
                try
                    [basename,propName] = strtok(pname,'.');
                    
                    val = src.(basename);
                    if ~isempty(propName)
                        % This has to be done here simply because the expected
                        % return type is a struct. If a struct did not have to
                        % be returned, this recursion could be much cleaner.
                        if isobject(src.(basename).(propName(2:end))) && ismember(basename,obj.mdlSubModelClasses)
                            propSet.(basename).(propName(2:end)) = src.(basename).zzzGetPropSet(cellstr(propName(2:end)));
                        end
                        propSet.(basename).(propName(2:end)) = src.(basename).(propName(2:end));
                    else
                        if isobject(val) && ismember(basename,obj.mdlSubModelClasses)
                            propSet.(basename) = [];
                        elseif isobject(val)
                            propSet.(basename) = [];
                        else
                            propSet.(basename) = val;
                        end
                    end
                catch %#ok<CTCH>
                    warning('DClass:zzzGetPropSet:ErrDuringPropGet',...
                        'An error occured while getting property ''%s''.',pname);
                    propSet.(pname) = [];
                end
            end
        end

        
        % Order property list by mdlPropAttributes. properties not
        % references in mdlPropAttributes are put at the end of the ordered
        % list.
        function propList = zzzOrderPropList(obj,propList)
            assert(iscellstr(propList));
            mdlPropAttribList = fieldnames(obj.mdlPropAttributes);
            [srted, unsrted] = zlclGetSortedSubset(propList,mdlPropAttribList);
            propList = [srted(:);unsrted(:)];
        end        
        
    end
    
    %%% Cfg/Header API
    
    methods (Static,Hidden)
        
        function propNames = zzzGetClassConfigurableProps(clsName)
            %Get configurable props defined by the specified class (not
            %traversing those of any associated parent or submodel classes)
            %If strcmpi returns a logical array, for example, for friend classes
            %where SetAccess and GetAccess returns a cell of classes
            validbase      = @(x) (...
                isequal(x.SetAccess,'public') ...
                && isequal(x.GetAccess,'public') ...
                && ~x.Transient && ~x.Constant && ~x.Hidden);
            
            fcn = @(x) validbase(x) && ~x.Dependent;
            
            % Used to have an allowance for configurable Dependent props 
            % But this does not appear needed in current ws.most.Model usage
            % So now all Dependent props are considered non-configurable - until there's a proven use case
            %             validdependent = @(x) (x.Dependent && x.SetObservable && ~isempty(x.SetMethod));
            %             fcn = @(x) validbase(x) && (validdependent(x) || ~x.Dependent);
            
            propNames = zlclGetAllPropsWithCriterion(clsName,fcn);
        end
        
        function propNames = zzzGetClassHeaderableProps(clsName)
            %Get headerable props defined by the specified class (not
            %traversing those of any associated parent or submodel classes)
            fcn = @(x)(isequal(x.GetAccess,'public') && ~x.Hidden);
            propNames = zlclGetAllPropsWithCriterion(clsName,fcn);
        end
        
    end

    
end              
    

   
% predicateFcn is a function that returns a logical when given a
% meta.Property object
function propNames = zlclGetAllPropsWithCriterion(clsName,predicateFcn)
mc = meta.class.fromName(clsName);
ps = mc.Properties;
tf = cellfun(predicateFcn,ps);
ps = ps(tf);
propNames = cellfun(@(x)x.Name,ps,'UniformOutput',false);
end

% sortedSubset is the subset of list that is in sortedReferenceList.
% sortedSubset is sorted by the reference list. unsortedSubset is the
% remainder of list. Its order is indeterminate.
function [sortedSubset, unsortedSubset] = zlclGetSortedSubset(list,sortedReferenceList)

[tfOrdered, loc] = ismember(list,sortedReferenceList);
sortedSubset = sortedReferenceList(sort(loc(tfOrdered)));
unsortedSubset = setdiff(list,sortedSubset);

end

function n = zlclVarNameForSaveAndRestore(clsName)
    n = regexprep(clsName,'\.','_');
end

function [propName,mdlName] = zlclFull2ShortPropName(propName)
%Extract plain prop name (without model class specifier) from a possibly long-form prop name

mdlName = '';
while true
    [car, cdr] = strtok(propName,'.');
    
    if ~isempty(cdr)
        mdlName = [mdlName '.' car]; %#ok<AGROW>
        propName = cdr(2:end);
    else        
        propName = car;
        break;
    end
end

if ~isempty(mdlName)
    mdlName(1) = [];
end

end



% 
%    function v = get.mdlDefaultConfigProps(obj)
%             v = obj.zzzGetDefaultConfigProps(class(obj));
%             % Note: The following is done because the default config props might
%             % already contain submodels if they are set public (SetObservable). If we
%             % were to simply append mdlSubModelClasses to default config props, then we
%             % would repeat the submodels in the prop list. Therefore, the quickest way
%             % around this is to delete the submodels from the default config props (if
%             % they exist) and add them on again so that they exist only once.
%             v = vertcat(setdiff(v,obj.mdlSubModelClasses'),obj.mdlSubModelClasses'); %Add on Submodels.
%         end
%         
%         function v = get.mdlDefaultHeaderProps(obj)
%             v = obj.zzzGetDefaultHeaderProps(class(obj));           
%             v = vertcat(setdiff(v,obj.mdlSubModelClasses'),obj.mdlSubModelClasses'); %Add on Submodels.
%         end
%         
%         function v = get.mdlPropSetVarName(obj)
%             v = zlclVarNameForSaveAndRestore(class(obj));
%         end 


        
%         % returns true if propName can be utilized as a config prop for the
%         % given class.
%         function tf = isPropConfigable(clsName,propName)
%             mc = meta.class.fromName(clsName);
%             allmp = mc.Properties;
%             tf = cellfun(@(x)strcmp(x.Name,propName),allmp);
%             assert(nnz(tf)==1);
%
%             mp = allmp(tf);
%             tf = strcmpi(mp.SetAccess,'public') && strcmpi(mp.GetAccess,'public');
%         end
%

%         function props = getOrderedSaveableProps(obj)
%             p = fieldnames(obj.mdlPropAttributes);
%             tf = ismember(p,obj.mdlDefaultConfigProps);
%             props = p(tf);    
%         end
        

%         % This saves the specified properties of obj as a struct into the
%         % specified MATfile. The properties are put in the struct in order.
%         % The variable name stored in the MATfile is the classname of obj.      
%         function savePropsInOrder(obj,props,filename)
%             
%             s = obj.zzzGetPropSet(props);
%             
%             % generate a varname to save in the mat file
%             varname = zlclVarNameForSaveAndRestore(class(obj));
%             tmp.(varname) = s; %#ok<STRNU>
%             
%             % if (varname) already exists in the file, it will be
%             % overwritten
%             save(filename,'-struct','tmp');            
%         end
        
              

               
%           function str = genAssertMsg(obj,val)
%             %General error message to use for assertion failure in property  set-access methods
%             %TODO: Factor this out one way or another (smartProperties??)
%             %TODO: Possibly allow property name to be (optionally) specified, and reported in message
%
%             if ischar(val) && isvector(val)
%                 str = sprintf('Value supplied (''%s'') not valid. Property was not set.',val);
%             elseif isnumeric(val)
%                 str = sprintf('Value supplied (''%g'') not valid. Property was not set.',val);
%             else
%                 str = sprintf('Invalid value supplied. Property was not set.');
%             end
%
%         end
%
%
        


    
%     % Header/Config API
%     methods
%         
%         % Save object configuration to file fname. This method starts with
%         % the default configuration properties, then includes optional
%         % 'include' or 'exclude' sets.
%         %
%         % incExcFlag (optional): either 'include' or 'exclude'
%         % incExcList (optional): inclusion/exclusion property list (cellstr)
%         function mdlSaveConfig(obj,fname,incExcFlag,incExcList)
%             
%             if nargin < 3
%                 incExcFlag = 'include';
%                 incExcList = cell(0,1);
%             end
%             assert(ischar(fname),'fname must be a filename.');
%             assert(any(strcmp(incExcFlag,{'include';'exclude'})),...
%                 'incExcFlag must be either ''include'' or ''exclude''.');
%             assert(iscellstr(incExcList),'incExcList must be a cellstring.');
%                         
%             defaultCfgProps = obj.mdlDefaultConfigProps;
%             switch incExcFlag
%                 case 'include'
%                     cfgProps = union(defaultCfgProps,incExcList);
%                 case 'exclude'
%                     cfgProps = setdiff(defaultCfgProps,incExcList);
%             end
%                     
%             obj.mdlSavePropSetFromList(cfgProps,fname);
%         end
%         
%         function cfgPropSet = mdlLoadConfigToStruct(obj,fname)
%             cfgPropSet = obj.mdlLoadPropSetToStruct(fname);            
%         end
%         
%         function mdlLoadConfig(obj,fname)
%             obj.mdlLoadPropSet(fname);
%         end
%         
%         % xxx todo make this look like mdlSaveConfig with the include/exclude
%         function mdlSaveHeader(obj,fname)
%             % Save header properties of obj as a structure in a MAT file.
% 
%             pnames = obj.mdlDefaultHeaderProps;
%             pnames = sort(pnames);
%             obj.mdlSavePropSetFromList(pnames,fname);
%         end

%         % Saves the values of all properties in propList to the config file
%         % fname. The properties will be not necessarily be saved in the
%         % order given by propList. (The order is restricted as necessary by
%         % the ordering of mdlPropAttributes.)
%         function mdlSavePropSetFromList(obj,propList,fname)
%             
%             if numel(obj)~=1
%                 error('DClass:mdlSavePropSetFromList:invalidArg','obj must be a scalar object.');
%             end
%             
%             allSaveableProps = obj.getAllConfigSaveableProps;
%             tfSaveable = ismember(propList,allSaveableProps);
%             if ~all(tfSaveable)
%                 error('DClass:mdlSavePropSetFromList:invalidProp',...
%                       'One or more specified properties cannot be saved to a configuration.');
%             end
%             
%             allOrderedProps = obj.getOrderedSaveableProps;
%             [sortedProps unsortedProps] = zlclGetSortedSubset(propList,allOrderedProps);
%             propList = [sortedProps;unsortedProps];
%             
%             obj.savePropsInOrder(propList,fname);            
%            
%         end


%         function mdlRestorePropSubset(obj,fname)
%              assert(false,'Obsolete');
% %             if isempty(obj)
% %                 return;
% %             end
% %             
% %             s = load(fname,'-mat');
% %             varname = zlclVarNameForSaveAndRestore(class(obj));
% %             if ~isfield(s,varname)
% %                 error('DClass:mdlRestorePropSubset:ClassNotFound',...
% %                     'No information for class ''%s'' found in config file ''%s''.',class(obj),fname);
% %             end
% %             s = s.(varname);
% %             propList = fieldnames(s);
% %             
% %             
% %             % restore in order of current propMetadata (order in saved struct may be different)
% %             allSaveableProps = obj.getAllConfigSaveableProps;
% %             tfSaveable = ismember(propList,allSaveableProps);
% %             notfound = propList(~tfSaveable);
% %             for c = 1:numel(notfound)
% %                 warning('DClass:mdlRestorePropSubset',...
% %                     'Property ''%s'' saved to configuration cannot be restored.',notfound{c});
% %             end
% %             propList = propList(tfSaveable);
% %             
% %             allOrderedProps = obj.getOrderedSaveableProps;
% %             [sortedProps unsortedProps] = zlclGetSortedSubset(propList,allOrderedProps);
% %             propList = [sortedProps;unsortedProps];
% %             
% %             for c = 1:numel(propList)
% %                 pname = propList{c};
% %                 for d = 1:numel(obj)
% %                     try
% %                         obj(d).(pname) = s.(pname);
% %                     catch %#ok<CTCH>
% %                         warning('DClass:mdlRestorePropSubset:ErrDuringPropSet',...
% %                             'An error occured while restoring property ''%s''.',pname);
% %                     end
% %                 end
% %             end            
%         end


        
