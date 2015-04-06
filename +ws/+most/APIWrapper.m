classdef APIWrapper < ws.most.HasClassDataFile %& ws.most.DClass
    %APIWRAPPER A type of DClass which represents a 'wrapper' of a C-language API (a DLL), e.g. a device driver
    %Wrapped C-language APIs are expected to have a header file (.H) and a DLL file (.DLL)
    %This superclass generalizes how multiple versions of the API are managed by the Matlab wrapper class.
    
    %Key functionalities provided by this class:
    %   1) Standardized handling of header/DLL versions, loading of DLL, and calls to DLL functions with response-validation (if applicable)
    %   2) Standardized mechanism for storing cached API data, for installed version of API, and access of this data by concrete subclasses
    %   3) General methods provided for extracting some standard/common types of API data
    
    %HIGH-PRIORITY
    %TODO: Ideally machine data file section would have list of apiSupportedVersions automatically inserted as a comment
    %TODO: Need to restore some static method/means to update API data when a driver has changed, etc..right now it shoudl work when driver number has changed, but no means to update when driver changes without change in version number (often occurs during development)
    %TODO: When API Data File is deleted and recomputed for a particular class, the persistent API data store entry for that class should be flushed too somehow
    
    %TO REVIEW
    %TODO: Provide some options related to smartLoadLibrary() to allow for (possibly version-dependent) variations in load options
    %TODO: Consider making option to automatically unload DLL on delete() (likely with instance counting) -- currently DLL is /never/ unloaded
    %TODO: Consider making option for 'checkout' model on construction for some subclass -- this would require use of machineData specifying the 'available' items for checkout
    %TODO: Should we deprecate apiCachedDataPath? Why wouldn't we store API cached data in class private directory?? If there's a good reason, supporting 'class','package','packageParent' shorthand would be good
    %TODO: For apiResponseCodeProcessor, if the subclass is to specify a map, it should probably do so directly, rather than through an apiResponseCodeMapHookFcn -- need to think if there was any reason for this.
    
    
    %OTHERS
    %TODO: Determine if there is any situation where it's useful/necessary to supply some of the abstract properties as a constructor argument -- in which case, support this as an additional option
    
    %% NOTES
    %   * The decision to /never/ unload DLLs wrapped by this class is currently baked into this class design.
    %
    %   If auto-version detection is not used, and there is more than one supported version, then subclasses should
    %   typically inherit from MachineDataFile -- this provides a means to initialize the apiCurrentVersion property.
    
    %% ABSTRACT PROPERTIES
    
    %Some of the following properties are 'version-indexed' (as noted). These
    %properties are ultimately encoded as a containers.Map whose keys are the
    %version strings provided by apiSupportedVersionNames and whose values are
    %the value pertaining to each version.
    %They may be specified directly, or as a cell array of just the values,
    %or as a scalar value (which is then auto-"scalar-expanded").
    
    %Following MUST be supplied with  values for each concrete subclass
    properties (Abstract, Constant, Hidden)
        apiPrettyName;  %A unique descriptive string of the API being wrapped
        apiCompactName; %A unique, compact string of the API being wrapped (must not contain spaces)
        apiSupportedVersionNames; %A cell array of shorthand names (strings) for API versions supported by this wrapper class
        
        apiDLLNames; %version-indexed. The name of the DLL sans the '.dll' extension.
        apiHeaderFilenames; %version-indexed. The name of the header file (with the '.h' extension - OR a .m or .p extension).
        
        apiCachedDataPath; %Specifies path of apiData MAT file for this API wrapper class. If specified as empty(''), the class private directory will be used as default.
        %NOTE: The apiCachedDataPath might otherwise be in section below (i.e. not require that a value be specified), but it must be a Constant value, in order to be accessible from Static methods (and avoid using 'dummy' object scheme)
    end
    
    %Following properties are sometimes supplied values by concrete subclasses, or they can be left empty when realized - in which case default values are used.
    properties (Abstract, SetAccess=protected, Hidden)
        
        %API 'pre-fab' cached data variables
        apiStandardFuncRegExp; %Regular expression used to parse function prototypes and identify 'standard' functions of the API, about which standard API data (e.g. methodNargoutMap, responseCodeMap) will be stored. If not supplied, data will be stored for /all/ functions found in library.
        apiHasFuncNargoutMap; %<LOGICAL - Default=false> If true, 'funcNargoutMap' API data var is extracted from list of 'standard' functions, using extractFuncNargoutMap() method.
        
        %API response code handling
        %If API provides a responseCode duruing many or all of its API calls, the apiResponseCodeSuccess can be specified to identify the code for success -- all others are assumed to imply an error occurred
        %Subclasses can optionally utilize 1) a responseCodeMap API data var or 2) implement an apiResponseCodeFcn() method to convert a status code into meaningful string(s) for user
        %The value of Map or return value of method is either 1) a simple string specifying 'errorName', or 2) a structure with fields 'errorName' and 'errorDescription', containing short and longer string descriptors, respectively.
        %For case of responseCodeMap API data var, subclass can either 1) implment an apiResponseCodeMapFcn, or 2) suply a regular expression as the apiResponseCodeProcessor value, which will be supplied to extractCodeMaps() to extract/save the responseCodeMap API data var
        apiResponseCodeSuccess; %<NUMERIC> If specified, the first output argument of API 'standard' functions is taken to be a response code, with the specified response value(s) indicating call was successful.
        apiResponseCodeProcessor; %<One of {'none', 'apiResponseCodeMapHookFcn','apiResponseCodeHookFcn', <responseCodeMap regular expression>} - Default = 'none'>
        
        %API 'custom' cached data variables
        apiCachedDataVarMap; %A Map whose keys (strings) specify custom class-specific data variables to store to API Data file, and whose values (strings) specify method names used to extract each of the 'apiCachedDataVars'. If same name is used for more than one variable, method is only invoked once.
        
        %API Version auto-detection
        %For APIs which support it, auto-version detection is recommened, avoiding need for user specification
        %For a subclass to support API version auto-detection, the following should be satisfied:
        %   1) Set apiVersionDetectEnable=true
        %   2) Implement a method apiVersionDetectHookFcn(), which determines apiCurrentVersion value
        %   3) <RECOMMENDED> 'apiDLLNames' should /not/ be version-indexed and 'apiDLLPaths' should be empty or a non-version-indexed value
        %   4) <RECOMMENDED> A prototype file, apiVersionDetect.m, should be created in the apiHeaderRootPath, which selects  subset of API functions required for auto-version detection (to be used in apiVersionDetectHookFcn())
        % If either conditions 3 or 4 are not met, then the apiVersionDetect() method should be overridden
        apiVersionDetectEnable; %<LOGICAL - Default=false> If true, indicates that subclass implements an 'apiVersionDetectHookFcn' method which performs auto-detection of API version installed on system, and returns apiCurrentVersion value. If false, the centrally maintained apiVersionData file is used for version specification of this API.
        
        %Location of files associated with this API.
        %apiHeaderRootPath and apiHeaderFinalPaths work in tandem.
        %APIWrapper uses apiHeaderPaths = <apiHeaderRootPath>\<apiHeaderFinalPaths(ver)>
        %Derived classes may override apiHeaderRootPath only, or apiHeaderPaths only, or both.
        %TIP: If either apiHeaderRootPath or apiHeaderFinalPaths is specified as an empty string ('') -
        %   then other property can specify whole path or version-indexed cell-array or Map of paths (latter only possible with apiHeaderFinalPaths)
        apiHeaderRootPath; %NOT version-indexed. Either 'class', 'package', or <real path>. 'class' and 'package' indicate class or package private path, respectively.
        apiHeaderFinalPaths; %version-indexed. Default is map where values are [<apiHeaderPathStem>_<apiSupportedVersionNames with dots replaced by fileseps>].
        apiHeaderPathStem; %NOT version-indexed. Default is <apiCompactName>.
        apiHeaderPlatformPaths; %NOT version-indexed. If supplied, either 'standard' or a 2-element string cell array. Default is 'none'. Specifies 32 & 64-bit subfolders of apiHeaderFinalPaths in which to find platform-specific header files. Value of 'standard' implies: {'win32' 'x64'}.
        
        apiDLLPaths; %version-indexed. By default, no path will be used, implying the system default location. To use the same version-indexed paths as apiHeaderPaths, set apiDLLPaths to be the scalar string 'useApiHeaderPaths'. This is useful e.g. when the DLL is distributed with the headers.
        apiDLLPlatformPaths; %NOT version-indexed. If supplied, either 'standard' or a 2-element string cell array. Default is 'none'. Specifies 32 & 64-bit subfolders of apiDLLPaths in which to find platform-specific header files. Value of 'standard' implies: {'win32' 'x64'}.
        
        apiAuxFile1Names; %version-indexed.
        apiAuxFile1Paths; %version-indexed. By default, the class private directory will be used. Also can specify 'useApiHeaderRootPath' or 'useApiHeaderPaths'.
        
        apiAuxFile2Names; %version-indexed.
        apiAuxFile2Paths; %version-indexed. By default, the class private directory will be used. Also can specify 'useApiHeaderRootPath' or 'useApiHeaderPaths'.
    end
    
    
    %% SUPERUSER PROPERTIES
    properties (Hidden)
        apiCurrentVersion; % Identifies which version among the 'apiSupportedVersionNames' is currently installed.
    end
    
    properties (SetAccess=private,Hidden)
        apiHeaderPaths; %Version-indexed Map of full paths to header file(s) corresponding to various version(s). Determined from apiHeaderRootPath, apiHeaderFinalPaths, and (optionally) apiHeaderPathStem.
    end
    
    properties (SetAccess=private,Dependent,Hidden)
        apiDLLName; %Current library (DLL) loaded
        
        apiHeaderFileName; %Full filename of header file associated with current API version
        apiAuxFileName1; %Full filename of auxiliary file #1 associated with current API version
        apiAuxFileName2; %Full filename of auxiliary file #1 associated with current API version
    end
    
    %% DEVELOPER PROPERTIES
    
    properties (SetAccess=protected, Hidden)
        % Property used to specify response codes to filter (ignore). These are respected by both apiCall() and apiCallFiltered().
        apiFilteredResponseCodes; % A list of API response codes to ignore globally (due to their irrrelevance in certain contexts)
    end
    
    properties (SetAccess=private,Dependent,Hidden)
        apiDataFullFileName;
        
        apiCachedDataVars; %The keys of 'apiCachedDataVarMap' -- the custom class-specific API data variables for this class
        apiStandardFuncPrototypes; %The prototypes of 'standard' functions in the API DLL, where 'standard' means functions picked out by 'apiStandardFuncRegExp', if supplied. Otherwise, this reflects /all/ functions in the DLL.
    end
    
    properties (Constant, Hidden)
       %apiDLLDefaultPath = fullfile(ws.most.idioms.startPath,'windows','system32'); %This is default location for both Win32 and x64 platforms
       apiDLLDefaultPath = fullfile(getenv('WINDIR'),'system32'); %This is default location for both Win32 and x64 platforms
    end
    
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj = APIWrapper()
            
            %Validate subclass Abstract property realizations
            assert(iscellstr(obj.apiSupportedVersionNames),'The ''apiSupportedVersionNames'' property must be a string cell array');  %Prevent infinite loop on spec error
            
            %Ensure (create if needed) class data file, specific to this abstract class
            obj.ensureClassDataFile(struct('lastAPIVersionFilePath','','showLoadLibraryWarnings',false),mfilename('class'));
            
            %Set defaults for properties where empty means to use default
            ziniSetDefaultValues();
            
            %Convert version-indexed properties into Maps, if supplied as a single value
            %NOTE: We cannot convert apiDLLNames and apiHeaderFilenames, because they are configured as Constant properties
            %      For those, the ensureVersionIndexedProp() method is used on each property access
            cellfun(@(propName)znstConvertVersionIndexedPropToMap(propName), ...
                {'apiHeaderFinalPaths' 'apiDLLPaths' 'apiAuxFile1Names' 'apiAuxFile1Paths' 'apiAuxFile2Names' 'apiAuxFile2Paths'});
            
            function znstConvertVersionIndexedPropToMap(propName)
                obj.(propName) = obj.ensureVersionIndexedProp(propName);
            end
            
            %Set apiHeaderPaths and associated vars
            ziniSetHeaderPathProps();
            
            %Get API current version (reading from apiVersionData.m file, if not done so already)
            try
                ziniGetAPICurrentVersion();
            catch ME
                obj.cancelConstruct = true;
                rethrow(ME);
            end
            if isempty(obj.apiCurrentVersion) %A cancellation or error occurred
                obj.cancelConstruct = true; %Signal to subclasses that construction should be aborted
                return;
            end
            
            %Ensure/Initialize API Data file
            ziniInitializeAPIDataFile();
            
            % Load the driver
            if ~libisloaded(obj.apiDLLName)
                obj.smartLoadLibrary();
            end
            
            return;
            
            function ziniSetDefaultValues()
                defaultValMap = containers.Map();
                %defaultValMap('apiCachedDataPath') = obj.classPrivatePath; %apiCachedDataPath has to be a Constant, for Static access, so can't re-set its value
                defaultValMap('apiHeaderRootPath') = 'class';
                defaultValMap('apiHeaderPathStem') = obj.apiCompactName;
                
                defaultValMap('apiStandardFuncRegExp') = '';
                defaultValMap('apiResponseCodeSuccess') = [];
                defaultValMap('apiHasFuncNargoutMap') = false;
                
                defaultValMap('apiResponseCodeProcessor') = 'none';
                defaultValMap('apiCachedDataVarMap') = containers.Map('KeyType','char','ValueType','char');
                defaultValMap('apiVersionDetectEnable') = false;
                
                defaultValMap('apiAuxFile1Names') = '';
                defaultValMap('apiAuxFile1Paths') = ws.most.util.className(obj,'classPrivatePath');
                defaultValMap('apiAuxFile2Names') = '';
                defaultValMap('apiAuxFile2Paths') = ws.most.util.className(obj,'classPrivatePath');
                
                %Handle apiDLLPath default -- can be specified in MDF
                if ~isa(obj,'ws.most.HasMachineDataFile') || ~isfield(obj.mdfData,'apiDLLPath')
                    defaultVal = '';
                else
                    val = obj.mdfData.apiDLLPath;
                    assert(ischar(val) && isvector(val),'Invalid specification of apiDLLPath for class ''%s'' in Machine Data File',obj.mdfClassName);
                    assert(isdir(val),'Specified value of apiDLLPath for class ''%s'' in Machine Data File must be a valid directory name',obj.mdfClassName);
                    defaultVal = obj.mdfData.apiDLLPath;
                end
                
                defaultValMap('apiDLLPaths') = containers.Map(obj.apiSupportedVersionNames, ...
                    repmat({defaultVal},1,numel(obj.apiSupportedVersionNames))); % TMW: putting in the scalar value '' leads to the value [] being put in the map! This breaks subsequent scalar expansion code
                
                for propNameCell=defaultValMap.keys
                    propName = propNameCell{1}; %not sure why it's a cell array
                    if isempty(obj.(propName)) && isnumeric(obj.(propName)) %Check for empty numeric - i.e. no value was set
                        obj.(propName) = defaultValMap(propName);
                    end
                end
                
                %Handle shorthand specification of common apiHeaderRootPath values
                switch obj.apiHeaderRootPath
                    case 'class'
                        obj.apiHeaderRootPath = ws.most.util.className(obj,'classPrivatePath');
                    case 'package'
                        obj.apiHeaderRootPath = ws.most.util.className(obj,'packagePrivatePath');
                    otherwise
                        % "real path", no-op.
                end
                
                %Handle 'apiHeaderFinalPaths', whose default depends on another property with an overridable default
                tmp = cellfun(@(x)znstConvertVersionNameToFolderName(x),obj.apiSupportedVersionNames,'UniformOutput',false);
                if isempty(obj.apiHeaderFinalPaths) && isnumeric(obj.apiHeaderFinalPaths)
                    obj.apiHeaderFinalPaths = containers.Map(obj.apiSupportedVersionNames,strcat(obj.apiHeaderPathStem,'_',tmp(:)));
                end
                
                function folderName = znstConvertVersionNameToFolderName(verName)
                    % Utility to convert verName like "1.0.2" to folder name like "1_0_2"
                    assert(ischar(verName) && ~isempty(verName));
                    folderName = regexprep(verName,'\.','\_');
                end
                
            end
            
            function ziniSetHeaderPathProps()
                
                %Set apiHeaderPaths property
                obj.apiHeaderPaths = containers.Map('KeyType','char','ValueType','char');
                for i=1:length(obj.apiSupportedVersionNames)
                    versionKey = obj.apiSupportedVersionNames{i};
                    
                    obj.apiHeaderPaths(versionKey) = fullfile(obj.apiHeaderRootPath, obj.apiHeaderFinalPaths(versionKey));
                end
                
                %Handle 'useApiHeaderPaths' & 'useApiHeaderRootPath' directives
                allowAPIUseHeaderPaths = {'apiDLLPaths' 'apiAuxFile1Paths' 'apiAuxFile2Paths'};
                allowAPIUseHeaderRootPath = {'apiAuxFile1Paths' 'apiAuxFile2Paths'};
                allHeaderPropReps = union(allowAPIUseHeaderPaths,allowAPIUseHeaderRootPath);
                
                for i=1:length(allHeaderPropReps)
                    propName = allHeaderPropReps{i};
                    propMap = obj.(propName);
                    
                    propVals = propMap.values();
                    
                    if ischar(propVals{1}) && ismember(lower(propVals{1}),{'useapiheaderpaths' 'useapiheaderrootpath'})
                        
                        switch lower(propVals{1})
                            case 'useapiheaderpaths'
                                assert(ismember(propName, allowAPIUseHeaderPaths), 'Directive ''useApiHeaderPaths'' not allowed for property ''%s''',propName);
                                
                                for i=1:length(obj.apiSupportedVersionNames)
                                    versionKey = obj.apiSupportedVersionNames{i};
                                    propMap(versionKey) = obj.apiHeaderPaths(versionKey);
                                end
                            case 'useapiheaderrootpath'
                                assert(ismember(propName, allowAPIUseHeaderRootPath), 'Directive ''useApiHeaderRootPath'' not allowed for property ''%s''',propName);
                                
                                for i=1:length(obj.apiSupportedVersionNames)
                                    versionKey = obj.apiSupportedVersionNames{i};
                                    propMap(versionKey) = obj.apiHeaderRootPath;
                                end
                            otherwise
                                assert(false);
                        end
                    end
                end
                
                %Append platform paths as appropriate
                pathPropNames = {'apiHeaderPaths' 'apiDLLPaths'};
                platformPropNames = {'apiHeaderPlatformPaths' 'apiDLLPlatformPaths'};
                
                for i=1:length(platformPropNames)
                    
                    platformPaths = obj.(platformPropNames{i});
                    pathMap = obj.(pathPropNames{i});
                    
                    if isempty(platformPaths)
                        continue;
                    else
                        if ischar(platformPaths) && strcmpi(platformPaths,'standard')
                            platformPaths = {'win32' 'x64'};
                        else
                            assert(iscellstr(platformPaths) && numel(platformPaths) >= 2,...
                                'Invalid value specified for abstract property ''%s''',platformPropName);
                        end
                    end
                    
                    for j=1:length(obj.apiSupportedVersionNames)
                        ver = obj.apiSupportedVersionNames{j};
                        
                        val = pathMap(ver);
                        
                        switch computer
                            case 'PCWIN'
                                newval = fullfile(val,platformPaths{1});
                            case 'PCWIN64'
                                newval = fullfile(val,platformPaths{2});
                        end
                        
                        %Allow versions to opt out of platform subfolders
                        %by simply not including them
                        if exist(newval,'dir')
                            pathMap(ver) = newval;
                        end
                    end
                end
                
                
            end
            
            function ziniGetAPICurrentVersion()
                % There are two ways to set obj.apiCurrentVersion: using
                % the MachineDataFile, or by auto-detection. In the event
                % that auto-detection is on and there is also an entry in
                % the MachineDataFile, the MDF entry trumps the
                % auto-detect. The rationale is that a user may want to
                % override autodetect.
                
                %Handle case where there is only one supported version;
                if length(obj.apiSupportedVersionNames) == 1
                    obj.apiCurrentVersion = obj.apiSupportedVersionNames{1};
                    return;
                end
                
                %Initialize persistent store of auto version-detect results
                persistent apiVersionDetectMap; % keys: apiCompactNames. vals: version strings
                if isempty(apiVersionDetectMap)
                    apiVersionDetectMap = containers.Map();
                end
                
                %apiCurrentVersion may have been set by MachineDataFile -- use this
                if isa(obj,'ws.most.HasMachineDataFile')
                    if ~isempty(obj.mdfData) && isfield(obj.mdfData,'apiCurrentVersion')
                        obj.apiCurrentVersion = obj.mdfData.apiCurrentVersion;
                    end
                    
                    if ~isempty(obj.apiCurrentVersion)
                        if ~ismember(obj.apiCurrentVersion,obj.apiSupportedVersionNames)
                            versionListString = deblank(sprintf('''%s'' ',obj.apiSupportedVersionNames{:}));
                            error('Version of the ''%s'' API is set in the machine data file to be ''%s'', which is not one of the apiSupportedVersions for this class. Choose a supported version from {%s}.',obj.apiPrettyName,obj.apiCurrentVersion,versionListString);
                        end
                    end
                end
                
                %Use auto-detect version or previously detected version
                
                if isempty(obj.apiCurrentVersion)
                    if apiVersionDetectMap.isKey(obj.apiCompactName) && ismember(apiVersionDetectMap(obj.apiCompactName),obj.apiSupportedVersionNames)
                        % cached version from auto-detect looks good.
                        obj.apiCurrentVersion = apiVersionDetectMap(obj.apiCompactName);
                    elseif obj.apiVersionDetectEnable
                        currentVersion = obj.apiVersionDetect();
                        if isempty(currentVersion)
                            error('Version of the ''%s'' API could not be automatically detected, as was expected\n',obj.apiPrettyName);
                        elseif ~ismember(currentVersion,obj.apiSupportedVersionNames)
                            error('Version of the ''%s'' API was detected to be ''%s'', which is not one of the apiSupportedVersions for this class',obj.apiPrettyName,currentVersion);
                        end
                        %Cache value to persistent data store
                        apiVersionDetectMap(obj.apiCompactName) = currentVersion;
                        obj.apiCurrentVersion = currentVersion;
                    else
                        % version should have been set one way or another (auto-detect, MachineData, etc) but it wasn't.
                        error('Version of the ''%s'' API was not specified and was not auto-detected. Cannot proceed.',obj.apiPrettyName);
                    end
                end
                
                assert(~isempty(obj.apiCurrentVersion) && ismember(obj.apiCurrentVersion,obj.apiSupportedVersionNames),'Logical Error');
                
            end
            
            function ziniInitializeAPIDataFile()
                
                %Create/update the APIDataFile for this API, if needed
                if ~exist(obj.apiDataFullFileName,'file')
                    ziniUpdateAPIDataFile();
                else
                    %Ensure the APIDataFile contains all expected values
                    foundAPIData =  who('-file',obj.apiDataFullFileName);
                    if ~isempty(setdiff(obj.apiCachedDataVars,foundAPIData)) %Some properties weren't found
                        fprintf(1,'WARNING(%s): The apiDataFile for class ''%s'' was found, but it appears corrupted. Attempting to refresh.\n');
                        ziniUpdateAPIDataFile();
                    elseif  ~strcmpi(obj.apiCurrentVersion, obj.accessAPIDataVar('apiCurrentVersion'))
                        %Version change!
                        ziniUpdateAPIDataFile();
                    end
                end
                
                return;
                
                function ziniUpdateAPIDataFile()
                    %Create/update APIDataFile for /this/ API
                    
                    %fprintf(1,[obj.apiPrettyName ': Caching API Data...']);
                    
                    try
                        
                        %Update selection-dependent vars
                        apiDataStruct = struct();
                        apiDataStruct.apiCurrentVersion = obj.apiCurrentVersion;
                        
                        %Extract API data vars using 'pre-fab' methods, as needed
                        apiDataStruct.apiStandardFuncPrototypes = obj.extractStandardFuncPrototypes();
                        apiDataStruct.apiFuncNargoutMap = obj.extractFuncNargoutMap();
                        
                        %Extract responseCodeMap API data var, as needed
                        switch obj.apiResponseCodeProcessor
                            case 'apiResponseCodeMapHookFcn'
                                %Subclass-specific responseCodeMap extraction is implemented
                                apiDataStruct.apiResponseCodeMap = feval('apiResponseCodeMapHookFcn', obj);
                            case {'apiResponseCodeHookFcn' 'none'}
                                %No responseCodeMap to be stored
                            otherwise
                                %The 'apiResponseCodeProcessor' is a regular expression string containing 2 tokens -- first for code name and second for code value -- which are extracted from pertinent lines in the header file
                                [~,apiDataStruct.apiResponseCodeMap] = obj.extractCodeMap(obj.apiResponseCodeProcessor, obj.apiHeaderFileName);
                        end
                        
                        
                        %Extract custom cached API values, as needed
                        uniqueExtractors = {};
                        for i=1:length(obj.apiCachedDataVars)
                            varName = obj.apiCachedDataVars{i};
                            extractor = obj.apiCachedDataVarMap(varName);
                            if ~ismember(extractor,uniqueExtractors)
                                uniqueExtractors{end+1} = extractor;
                                val = feval(obj.apiCachedDataVarMap(varName),obj);
                                
                                if isstruct(val) && isfield(val,varName) %Extractor function returns structure containing multiple API Data var values (including varName)
                                    varNames = fieldnames(val);
                                    for j=1:length(varNames)
                                        apiDataStruct.(varNames{j}) = val.(varNames{j});
                                    end
                                else  %Extractor returns just value for current varName
                                    apiDataStruct.(varName) = val;
                                end
                            end
                        end
                        
                        %Save variables to file & update the classData
                        save(obj.apiDataFullFileName,'-struct','apiDataStruct');
                    catch ME
                        %fprintf(1,'\n');
                        ME.rethrow();
                    end
                    
                    %fprintf(1,'Done!\n');
                end
            end
            
            
            
        end
        
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        
        function val = get.apiDLLName(obj)
            apiDLLNames = obj.ensureVersionIndexedProp('apiDLLNames'); %#ok<PROP>
            val = apiDLLNames(obj.apiCurrentVersion); %#ok<PROP>
        end
        
        function val = get.apiDataFullFileName(obj)
            %NOTE: This is much easier to implement directly than to defer to separate Static method implementation
            if isempty(obj.apiCachedDataPath)
                cachedDataPath = ws.most.util.className(obj,'classPrivatePath');
            else
                cachedDataPath = obj.apiCachedDataPath;
            end
            val = fullfile(cachedDataPath,[obj.apiCompactName '_APIData.mat']);
        end
        
        function val = get.apiCachedDataVars(obj)
            val = obj.apiCachedDataVarMap.keys();
        end
        
        function val = get.apiStandardFuncPrototypes(obj)
            if isempty(obj.apiStandardFuncRegExp)
                val = libfunctions(obj.apiDLLName,'-full');
            else
                val = obj.accessAPIDataVar('apiStandardFuncPrototypes');
            end
        end
        
        function val = get.apiHeaderFileName(obj)
            %apiHeaderPaths = obj.ensureVersionIndexedProp(obj.apiHeaderPaths); %#ok<PROP>  %VI031011A: Use apiHeaderPaths prop directly
            apiHeaderFilenames = obj.ensureVersionIndexedProp('apiHeaderFilenames'); %#ok<PROP> %VI: This extra step is needed because apiHeaderFilenames is specified as a 'Constant' prop
            
            %val = fullfile(obj.apiHeaderRootPath,obj.apiHeaderPaths(obj.apiCurrentVersion),apiHeaderFilenames(obj.apiCurrentVersion));  %VI041411A: Removed %VI031011A: Use apiHeaderPaths prop directly %#ok<PROP>
            val = fullfile(obj.apiHeaderPaths(obj.apiCurrentVersion),apiHeaderFilenames(obj.apiCurrentVersion)); %VI041411A
            
            %Try m->p substitution, if appropriate           
            if ~exist(val,'file')
                [~,~,ext] = fileparts(val);
                if strcmpi(ext,'.m')
                    newVal = val;
                    newVal(end) = 'p'; 
                    if exist(newVal,'file')
                        val = newVal;
                    end
                end
            end            
            
        end
        
        function val = get.apiAuxFileName1(obj)
            val = fullfile(obj.apiAuxFile1Paths(obj.apiCurrentVersion),obj.apiAuxFile1Names(obj.apiCurrentVersion));
        end
        
        function val = get.apiAuxFileName2(obj)
            val = fullfile(obj.apiAuxFile2Paths(obj.apiCurrentVersion),obj.apiAuxFile2Names(obj.apiCurrentVersion));
        end
        
    end
    
    %Helpers for property-access methods
    methods (Access=protected)
        function val = ensureVersionIndexedProp(obj,propName)
            val = obj.(propName);
            if ischar(val)
                val = containers.Map(obj.apiSupportedVersionNames,repmat({val},1,length(obj.apiSupportedVersionNames)));
            elseif iscell(val)
                assert(numel(val) == numel(obj.apiSupportedVersionNames),'Invalid ''version-indexed'' property %s: Number of elements must match length of ''apiSupportedVersionNames''',propName);
                val = containers.Map(obj.apiSupportedVersionNames,val);
            end
        end
        
    end
    
    
    %% PUBLIC METHODS
    % Generic implementations of API call and API error handling -- can/should override if generic implementations are not applicable.
    methods (Hidden)
        function varargout = apiCall(obj,funcName,varargin)
            % Method to wrap calls to API functions. If API signals an error, then a Matlab error is thrown.
            % funcName: name of API function to call
            % varargin: an optional list of input arguments
            
            %Determine # of output arguments
            varargout = cell(nargout,1);
            
            %Call the driver function
            if ~isempty(obj.apiResponseCodeSuccess)
                [responseCode varargout{:}] = calllib(obj.apiDLLName,funcName,varargin{:});
                
                if ~ismember(responseCode,[obj.apiResponseCodeSuccess obj.apiFilteredResponseCodes])
                    %Further process response, throwing error if needed
                    try
                        obj.apiProcessErrorResponseCode(responseCode,funcName);
                    catch ME
                        ME.throwAsCaller();
                    end
                end
            else
                [varargout{:}] = calllib(obj.apiDLLName,funcName,varargin{:});
            end
        end
        
        function varargout = apiCallFiltered(obj,funcName,filteredResponseCodes,varargin)
            % A variant of apiCall(), where response codes to filter (ignore) are specified as an additional argument
            % The filteredResponseCodes supplied are /in addition/ to those currently set by the 'apiFilteredResponseCodes' property
            % see apiCall() documentation.
            
            %Determine # of output arguments
            varargout = cell(nargout,1);
            
            originalAPIFilteredResponseCodes = obj.apiFilteredResponseCodes;
            try
                if ~verLessThan('matlab','8.1') %2013a or later
                    obj.apiFilteredResponseCodes = union(obj.apiFilteredResponseCodes, filteredResponseCodes,'legacy'); %Use 'legacy' indicator to preserve dimensionality of obj.apiFilteredResponseCodes in case where filteredResponseCodes is empty
                else %2012b or earlier
                    obj.apiFilteredResponseCodes = union(obj.apiFilteredResponseCodes, filteredResponseCodes);
                end

                [varargout{:}] = obj.apiCall(funcName,varargin{:});
                
                obj.apiFilteredResponseCodes = originalAPIFilteredResponseCodes;
            catch ME
                obj.apiFilteredResponseCodes = originalAPIFilteredResponseCodes;
                ME.throwAsCaller();
            end
            
        end
        
        function varargout = apiCallRaw(obj,funcName,varargin)
            % A variant of apiCall() allowing API functions to be called without response extraction/validation
            % see apiCall() documentation.
            
            %Determine # of output arguments
            varargout = cell(nargout,1);
            
            %Call the DAQmx driver function
            [varargout{:}] = calllib(obj.apiDLLName,funcName,varargin{:});
        end
        
        function apiProcessErrorResponseCode(obj, responseCode, funcName)
            % Generic handler when responseCode returned by an API call indicates an error. Throws a Matlab error.
            % Method's behavior is modulated by the value of 'apiResponseCodeProcessor'
            % If none of the provided behaviors is appropriate, this method can also be overridden.
            
            errorString = '';
            warningOnly = false;
            
            responseCodeInfo = [];
            switch obj.apiResponseCodeProcessor
                
                case 'apiResponseCodeHookFcn'
                    try
                        responseCodeInfo = obj.apiResponseCodeHookFcn(responseCode);
                    catch ME
                        errorString = sprintf('Received response code indicating error (%d). Unable to decode.\n',responseCode);
                    end
                case 'none'
                    errorString = getDefaultErrorString(nargin);
                otherwise
                    %A responseCodeMap is used
                    
                    responseCodeMap = obj.accessAPIDataVar('apiResponseCodeMap');
                    
                    if ~responseCodeMap.isKey(responseCode)
                        errorString = getDefaultErrorString(nargin);
                    else
                        responseCodeInfo = responseCodeMap(responseCode);
                    end
            end
            
            if isempty(errorString)
                
                if ischar(responseCodeInfo)
                    errorName = responseCodeInfo;
                    errorDescription = '';
                elseif isempty(responseCodeInfo)
                    errorName = num2str(responseCode);
                    errorDescription = '';
                elseif isstruct(responseCodeInfo)
                    errorName = responseCodeInfo.errorName;
                    errorDescription = responseCodeInfo.errorDescription;
                    if isfield(responseCodeInfo,'warningOnly')
                        warningOnly = responseCodeInfo.warningOnly;
                    end
                else
                    error('Unexpected responseCode information supplied by either responseCodeMap or ''apiResponseCodeFcn'' ');
                end
                
                if warningOnly
                    responseType = 'warning';
                else
                    responseType = 'error';
                end
                
                errorString = sprintf('%s %s', obj.apiPrettyName, responseType);
                
                if ~isempty(errorName)
                    errorString = [errorString sprintf(' (%s)', errorName)];
                end
                
                if nargin >= 3
                    errorString = [errorString sprintf(' in call to API function ''%s''', funcName)];
                end
                
                if ~isempty(errorDescription)
                    errorString = [errorString sprintf(':\n %s',errorDescription)];
                end
                
                %                 if isempty(errorName) && isempty(errorDescription)
                %                     errorString = getDefaultErrorString(nargin);
                %                 elseif isempty(errorDescription)
                %                     errorString = [errorString errorName];
                %                 elseif isempty(errorName)
                %                     errorString = [errorString sprintf('\n %s',errorDescription)];
                %                 else
                %                     errorString = [errorString sprintf('\n (%s) %s',errorName,errorDescription)];
                %                 end
            end
            
            %Issue warning or exception
            if warningOnly
                s = warning('query','backtrace');
                warning([ws.most.util.className(obj) ':APICallWarning'],errorString);
                warning(s.state, 'backtrace');
            else
                ME = MException([ws.most.util.className(obj) ':APICallError'],errorString);
                ME.throwAsCaller();
            end
            
            function errorString = getDefaultErrorString(narginVal)
                if narginVal  < 3
                    errorString = [obj.apiPrettyName ' error (' num2str(responseCode) ')'];
                else
                    errorString = [obj.apiPrettyName ' error (' num2str(responseCode) ') in call to API function ''' funcName ''''];
                end
            end
        end
    end
    
    %% PROTECTED/PRIVATE METHODS
    
    methods (Hidden)
        function val = accessAPIDataVar(obj,varName)
            val = obj.accessAPIDataVarStatic(class(obj),varName);
        end
    end
    
    methods (Access=protected)
        
        function apiCurrentVersion = apiVersionDetect(obj)
            %Method implementing automatic version detection, using the apiVersionDetectHookFcn() defined by subclass
            %Method enforces/facilitates several conventions for API automatic version detection, e.g.
            % apiDLLNames and apiDLLPaths must /not/ be version-indexed 
            %If these conventions/rules are not applicable to particular subclass, override this method! (e.g., can make it simply pass-through for apiVersionDetectHookFcn())
            %
            %
            origPath = pwd();
            %fprintf(1,[obj.apiPrettyName ': Detecting API version...']);
            
            try
                %Unload previously-loaded library
                if libisloaded(obj.apiDLLNames)
                    unloadlibrary(obj.apiDLLNames);
                end
                
                %Load minimal version of API, just for version detection
                cd(obj.apiHeaderRootPath);
                s = warning('query','MATLAB:loadlibrary:FunctionNotFound');
                warning('off','MATLAB:loadlibrary:FunctionNotFound'); %Sometimes, the prototype file will define functions available only in certain versions of the API
                
                switch computer
                    case 'PCWIN'
                        apiVDFcn = @apiVersionDetect;
                    case 'PCWIN64'
                        apiVDFcn = @apiVersionDetect64;
                end
                
                if all(cellfun(@isempty,obj.apiDLLPaths.values())) %try system default location used
                    if exist(fullfile(obj.apiDLLDefaultPath,[obj.apiDLLNames '.dll']),'file')
                        apiDLLPath = obj.apiDLLDefaultPath;
                    else
                        apiDLLPath = ''; %don't supply path, so loadlibrary() will do search itself (with potentially unpredictable results)
                    end
                else
                    %obj.apiDLLPaths must NOT be version-indexed
                    apiDLLPaths = obj.apiDLLPaths.values();
                    apiDLLPath = apiDLLPaths{1}; %All values should be the same
                end
                loadlibrary(fullfile(apiDLLPath,obj.apiDLLNames),apiVDFcn);

                warning(s.state,'MATLAB:loadlibrary:FunctionNotFound');
                cd(origPath);
                
                %Invoke apiVersionDetectHookFcn() to detect apiCurrentVersion
                apiCurrentVersion = obj.apiVersionDetectHookFcn();
                
                %Unload minimal API
                unloadlibrary(obj.apiDLLNames);
                
            catch ME
                fprintf(1,'\n');
                cd(origPath);
                if libisloaded(obj.apiDLLNames)
                    unloadlibrary(obj.apiDLLNames);
                end
                ME.throwAsCaller();
            end
            
            if ~isempty(apiCurrentVersion) && ismember(apiCurrentVersion,obj.apiSupportedVersionNames)
                %fprintf(1,'Done! (%s)\n',apiCurrentVersion);
            else
                %fprintf(1,'\n');
            end
            
        end
        
        
        
        
        function standardFuncPrototypes = extractStandardFuncPrototypes(obj)
            %Method for extracting subset of the DLL function prototypes as the 'standard' functions (i.e. those for which methodNargoutMap, responseCode extraction, etc, will apply)
            
            %Do we need to identify a subset of 'standard' function prototypes
            if isempty(obj.apiStandardFuncRegExp)
                standardFuncPrototypes = [];
                return;
            end
            
            %Load the API DLL, if not done so already
            obj.smartLoadLibrary();
            
            %Start with /all/ the DLL function prototypes
            standardFuncPrototypes = libfunctions(obj.apiDLLName,'-full');
            
            %Apply regular expression to filter the function prototypes
            tokens = regexp(standardFuncPrototypes,obj.apiStandardFuncRegExp,'tokens','once'); %Captures the output arguments of each function
            standardFuncPrototypes = cat(1,tokens{:}); %Converts from nested cell array to Nx1 cell array
        end
        
        function funcNargoutMap = extractFuncNargoutMap(obj)
            %Method for extracting number of output argument outputs for all functions in API DLL (or subset of 'standard' functions, if applicable)
            
            %Do we need this Map?
            if ~obj.apiHasFuncNargoutMap
                funcNargoutMap = containers.Map();
                return;
            end
            
            %Load the API DLL, if not done so already
            obj.smartLoadLibrary();
            
            %Identify the 'standard' function prototypes
            prototypes = obj.apiStandardFuncPrototypes;
            
            %Determine funcNargoutMap
            tokens = regexp(prototypes,'(\w*|\[.*\])\s*(\w*)','tokens','once'); %Captures the output arguments of each function
            tokens = cat(1,tokens{:}); %Converts from nested cell array to Nx2 cell array
            outArgs = tokens(:,1);
            funcNames = tokens(:,2);
            
            numOutArgs = cellfun(@(x)countOutArgs(x),outArgs);
            
            if ~isempty(obj.apiResponseCodeSuccess) %First argument is a response code for all 'standard' functions
                numOutArgs = max(0,numOutArgs - 1);
            end
            
            funcNargoutMap = containers.Map(funcNames',num2cell(numOutArgs'));
            
            function numOutArgs = countOutArgs(outArgString)
                if isempty(outArgString)
                    numOutArgs = 0;
                else
                    numOutArgs = length(strfind(outArgString,',')) + 1;
                end
            end
            
        end
        
        function [codeNameMap, codeValueMap] = extractCodeMap(obj,codeNameRegExp,fileName)
            %Method for extracting Maps, keyed by name and numeric value respectively, extracted from a text file (header file, or otherwise)
            %Numeric value specifications supported: direct numeric value, a hexadecimal value (prefixed by 0x), or a C bitwise operation
            %Method processes specified file line-wise, i.e. assumes that code name and value can be extracted from individual lines in text file
            %
            %   codeNameRegExp: Regular expression containing two tokens, identifying the name and numeric value, respectively, to extract and include in the required Map(s) from each line of text
            %   fileName: <OPTIONAL - Default = obj.apiHeaderFileName> Specifies full filename of file to parse
            
            
            if nargin < 3 || isempty(fileName)
                fileName = obj.apiHeaderFileName;
            end
            
            codeNameMap = containers.Map({'dummy'},{1}); codeNameMap.remove('dummy');
            
            fid = fopen(fileName,'r');
            assert(fid >= 0, 'The file ''%s'' was not found or could not be opened.',fileName);
            
            while (~feof(fid))
                currentLine = fgetl(fid);
                
                tokens = regexp(currentLine,codeNameRegExp,'tokens','once');
                
                if ~isempty(tokens) %Found new entry to add to Map(s)
                    
                    codeName = tokens{1};
                    codeValue = tokens{2};
                    
                    %Determine type of code value
                    
                    if regexp(codeValue, '^0x') %Hexadecimal value
                        codeValue = hex2dec(codeValue(3:end));
                    elseif ~isempty(strfind(codeValue,'<<')) || ~isempty(strfind(codeValue,'>>')) %Bit-shift value
                        res=regexp(codeValue, '\(?\s*(?<base>\d+)\s*(?<shiftop><<|>>)\s*(?<shift>\d+)\s*\)?', 'names');
                        if strcmpi(res.shiftop,'<<')
                            codeValue = bitshift(str2double(res.base), str2double(res.shift));
                        elseif strcmpi(res.shiftop,'>>')
                            codeValue = bitshift(str2double(res.base), -str2double(res.shift));
                        else
                            error('Unrecognized bit-shift operator.'); %This should never happen
                        end
                    elseif ~isnan(str2double(codeValue)) %Simple numeric value
                        codeValue = str2double(codeValue);
                    else
                        codeValue = [];
                    end
                    
                    if ~isempty(codeValue)
                        codeNameMap(codeName) = codeValue;
                    end
                end
            end
            
            fclose(fid);
            
            %Create codeValueMap with reverse-lookup by code value, if requested
            if nargout > 1
                codeValueMap = containers.Map(codeNameMap.values,codeNameMap.keys);
            end
            
        end
        
        function smartLoadLibrary(obj)
            
            %fprintf(1,[obj.apiPrettyName ': Loading DLL...']);
            try
                %Cache current state of loadlibrary warnings
                warningIDs = {'MATLAB:loadlibrary:parsewarnings' 'MATLAB:loadlibrary:FunctionNotFound' 'MATLAB:loadlibrary:TypeNotFound' 'MATLAB:loadlibrary:cppoutput'};
                warningStateMap = containers.Map(warningIDs,cellfun(@(warnID)warning('query',warnID),warningIDs,'UniformOutput',false));
                
                %Set loadlibrary warning states as specified
                showLoadLibWarnings = obj.getClassDataVar('showLoadLibraryWarnings');
                if showLoadLibWarnings
                    cellfun(@(warnID)warning('on',warnID),warningIDs);
                    fprintf(1,'\n');
                else
                    cellfun(@(warnID)warning('off',warnID),warningIDs);
                end
                
                if ~libisloaded(obj.apiDLLName)
                    
                    DLLPath =  obj.apiDLLPaths(obj.apiCurrentVersion);
                    if isempty(DLLPath) && exist(fullfile(obj.apiDLLDefaultPath,[obj.apiDLLName '.dll']),'file')
                        DLLPath = obj.apiDLLDefaultPath;
                    end                
                    
                    [headerPath,headerFile,headerExt] = fileparts(obj.apiHeaderFileName);
                    
                    if strcmpi(headerExt,'.h')
                        loadlibrary(fullfile(DLLPath,obj.apiDLLName),obj.apiHeaderFileName);
                    elseif any(strcmpi(headerExt,{'.m' '.p'}))
                        currPath = cd;
                        try
                            cd(headerPath);
                            loadlibrary(fullfile(DLLPath,obj.apiDLLName),str2func(headerFile));
                            cd(currPath);
                        catch ME
                            cd(currPath);
                            ME.rethrow();
                        end
                    else
                        error('Unexpected extension supplied for API header file');
                    end
                end
                
                %VI090311: Following is a nice idea, but unwieldy since there are so many warnings to sift through
                %                 %Warn, even if warnings are blocked, in case that cpp message specifies 'error'
                %                 if ~showLoadLibWarnings && ~isempty(loadLibWarnings)
                %                     loadLibWarnings = textscan(loadLibWarnings,'%s');
                %                     loadLibWarnings = loadLibWarnings{1};
                %
                %                     lccErrorIdxs = cellfun(@(s)~isempty(strfind(s,'lcc')) && ~isempty(strfind(s,'error')),'UniformOutput',1);
                %                     if ~isempty(lccErrorIdxs)
                %                         fprintf(1,'\n');
                %                         warning('on','MATLAB:loadlibrary:cppoutput');
                %                         for i=1:length(lccErrorIdxs)
                %                             warning('MATLAB:loadlibrary:cppoutput',loadLibWarnings{i});
                %                         end
                %                     end
                %                 end
                
                %Restore original loadlibrary warning states
                cellfun(@(warnID)warning(warningStateMap(warnID).state,warnID),warningIDs);
                
            catch ME
                %fprintf(1,'\n');
                ME.rethrow();
            end
            
            if ~showLoadLibWarnings
                %fprintf(1,'Done!\n');
            end
        end
        
    end
    
    %% STATIC METHODS
    methods (Static, Access=protected)
        
        %         function varargin = assignNamedArgs(namedArgs,varargin)
        %             %Helper method for processing varargin arrays, assigning contents to named variables
        %             %   namedArgs: Cell string array of names for arguments in the varargin array, starting from the beginning.
        %
        %             numNamedArgs = min(length(namedArgs),length(varargin));
        %
        %             for i=1:numNamedArgs
        %                 assignin('caller',namedArgs{i},varargin{i});
        %             end
        %             varargin(1:numNamedArgs) = [];
        %         end
        
        % Utility method for VAPI property naming convention.
        function newname = standardizePropName(name)
            % name (string): name of an API property.
            % This method takes name and converts it to the VAPI case convention. The following list enumerates cases for
            % (raw API name) -> (VAPI conventionalized name)
            %
            % * MyProp -> myProp
            % * myProp -> myProp
            % * Myprop -> myprop
            % * myprop -> myprop
            % * MYPROP -> MYPROP
            % * MYProp -> MYProp
            
            assert(ischar(name));
            if length(name)<=1 || (name(1)==upper(name(1)) && name(2)==upper(name(2)))
                newname = name;
            else
                newname = name;
                newname(1) = lower(newname(1));
            end
        end
        
        
        function val = apiCachedDataPathStatic(className)
            apiCachedDataPathSpec = eval([className '.apiCachedDataPath']);
            if isempty(apiCachedDataPathSpec)
                val = ws.most.util.className(className,'classPrivatePath');
            else
                val = apiCachedDataPathSpec;
            end
        end
        
        function val = apiDataFullFileNameStatic(className)
            val = fullfile(feval([mfilename('class') '.apiCachedDataPathStatic'],className),[eval([className '.apiCompactName']) '_APIData.mat']);
        end
        
    end
    
    methods (Static, Hidden)
        
        function showLoadLibraryWarnings()
            ws.most.DClass.setClassDataVarStatic(mfilename('class'),'showLoadLibraryWarnings',true);
        end
        
        function hideLoadLibraryWarnings()
            ws.most.DClass.setClassDataVarStatic(mfilename('class'),'showLoadLibraryWarnings',false);
        end
        
        
        function val = accessAPIDataVarStatic(className,varName)
            %Method allowing API data to be accessed quickly, on a per-variable basis
            %Concrete subclasses employing APIData variables should reimplement this method. Can simply invoke this version and supply classname argument (use mfilename('class')).
            
            persistent APIDataStructMap %Persistent data store for APIData for /all/ concrete subclasses which access API data
            
            if isempty(APIDataStructMap)
                APIDataStructMap = containers.Map();
            end
            
            %Load APIData for this class to persistent data store, if not done so already
            if ~APIDataStructMap.isKey(className)
                %obj = feval(className, 'dummy'); %This dummy object should be cleaned up
                %apiDataStruct = load(obj.apiDataFullFileName);
                
                apiDataStruct = load(feval([mfilename('class') '.apiDataFullFileNameStatic'],className));
                
                APIDataStructMap(className) = apiDataStruct;
            end
            
            %Now Get the specified varName
            val = APIDataStructMap(className).(varName);
        end
        
        
        
    end
    
    
end

