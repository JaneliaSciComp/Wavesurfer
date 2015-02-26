classdef HasMachineDataFile < ws.most.HasClassDataFile
    %HASMACHINEDATAFILE Abstract class implementing concept of Machine Data
    % Classes that inherit from HasMachineDataFile will have a data field
    % (.mdfData) initialized during object construction from user-specified
    % values in an M-file (the machine data file). There is a single
    % machine data file for all classes in a MATLAB session.
    %
    % A typical Machine Data File (MDF) looks like:
    % 
    % %% Machine Data File
    % 
    % %% MyClass1
    % class1prop1 = 'helloworld';
    % class1prop2 = 123;
    %
    % %% MyPack.MyClass2
    % class2prop1 = pi;
    % ...
    %
    % Here MyClass1 and MyPack.MyClass2 inherit from HasMachineDataFile. When
    % an object of class MyClass1 is constructed, the value of its
    % (inherited) .mdfData property will be a struct with fields
    % 'class1prop1' and 'class1prop2' and their respective values. The
    % initialization of .mdfData occurs during the HasMachineDataFile
    % constructor.
    %
    % To use the machine data file in a class, first derive from
    % HasMachineDataFile. Then specify the mdfClassName for your class, which
    % must be the fully-qualified classname of an MDF-derived class. Most
    % of the time, this heading will be your class's classname, but in rare
    % cases it may be the name of another class.
    %
    % In the typical case where the heading of your class is its own
    % classname, you need to also specify values for mdfDependsOnClasses.
    % These represent classes whose mdf headings that should be included in
    % the MDF whenever the class's own heading is added to an MDF.
    %
    % You must also create a model file for your class. This will be copied
    % into any newly-created MDFs or MDFs that are missing a heading for
    % your class. This model file should only have one heading-block, that
    % is, it should start with a cell marker (%%) and your mdfHeader, and
    % then be followed by comments and variable definitions. Note that the
    % mdfHeader in your model file must match the value specified in your
    % class exactly. The model file should look like like
    %
    % %% my MDF header
    % % Some comments here are possible
    % % ...
    % var1 = <val1>; % comment1
    % var2 = <val2>; % comment2
    % ...
    % % Some comments here are possible but discouraged
    % % ...
    %
    % Put this file in the private directory for your class.
    
    %% ********************************************************************
            
    % TODO Allow specification of machineDataFile as a plain filename,
    % using lastMachineDataFilePath
    % TODO Currently the user is prompted to edit the MDF by actually
    % opening the MDF in the editor and then using a uiwait(msgbox). The
    % point is we want the user to hit OK when they are done editing so
    % that we may continue. The effect of the uiwait(msgbox) is to do a
    % nonmodal dialogue. This is not ideal since this dialogue is not tied
    % to the editor in any way (The user can hit done and continue editing,
    % can hit done without saving, etc.) The "best" solution would be a
    % custom GUI that allows editing of the MDF and has Done/Cancel
    % buttons.

    %%% MDF spec %%%
    % Defns: 'MDFc' is the HasMachineDataFile class. 'MDF' is typically the
    % machine data file itself.
    %
    %% Getting an MDF 
    % When HasMachineDataFile requires an MDF, it looks to see if one is
    % already loaded. If not, it prompts the user to either i) specify an
    % existing MDF, or ii) create a new MDF.
    %
    % If the user chooses to create, MDFc prompts the user for a directory
    % to create a new MDF. It creates a brand new MDF in that dir.
    %
    %% Using an MDF for a particular class
    % MDFc uses/requires an MDF anytime it creates an MDFc object (modulo a
    % caching optimization), including when it first creates a brand-new
    % MDF at first-MDFc-object-construction-time.
    %
    % In the MDFc ctor, MDFc looks at the current MDF and looks for the
    % heading of the class being cted. If the heading is not there, MDFc
    % will copy the model file for the class and its dependents into the
    % MDFc. MDFc opens the editor for the user to edit the MDF, since 99%
    % of the time the user will want to edit the values used. After the
    % edit, MDFc confirms that the desired heading exists in the MDF. It
    % then evaluates the section of the M-file under the desired heading
    % and populates the properties of the MDFc object appropriately.
    %
    %% What it looks like to the user
    % * 94% of the time
    % They boot up ML. They run Scanimage. It uses the previous MDF. They
    % never have to do anything.
    % * 3% of the time
    % They boot up ML. They run Scanimage. It says there is no MDF. They
    % say, create new. MDFc brings up the editor. They don’t know all the
    % values they need off the top of their head. They hit cancel. This
    % harderrors. They go find all the numbers/values they need on a
    % notepad. They come back to ML. They run Scanimage. It says there is
    % no MDF. They say, create new. MDFc brings up the editor. They type in
    % the values from their notepad into the MDF. Everything works fine.
    % * 3% of the time
    % They want to change a number in their MDF, either because they
    % realize it is wrong or they have changed their equipment in some way.
    % They edit the MDF and put in the new value. They restart ML.
    % Everything works fine.
    
    %% ABSTRACT PROPERTIES    
    %Value-Required
    properties (Abstract,Constant,Hidden)
        mdfClassName;
        % Fully qualified classname of the 'MDF class' for this class.
        % Typically, mdfClassName will be the same as the class's own name.
        % Right now, this property is used only to determine the directory
        % in which to find a class's model MDF. Leave this empty to opt-out
        % of variable initialization during object construction.
        %
        % Possible todo: just change this to 'modelFilePath', modulo
        % further requirements/design changes.
        
        mdfHeading;
        % The MDF header under which to look up property initializers for
        % objects of this class.
    end
    
    %Value-Optional
    properties (Abstract,Constant,Hidden)
        mdfDependsOnClasses; 
        % Cellstr of fully-qualified classnames. Specifies the other
        % classes this class "depends on" from an MDF point of view. For
        % example, if A.mdfDependsOnClasses = 'B', then when an instance of
        % A is created, headings for both 'A' and 'B' will be put into the
        % MDF (if they are not already there).
        
        mdfDirectProp;
        % Logical. If true, rather than initializing fields of the mdfData
        % structure, HasMachineDataFile initializes properties of the object
        % being instantiated. Defaults to false.
        
        mdfPropPrefix;
        % String. Applies only if mdfDirectProp is true. This string is a
        % prefix for properties to be initialized by HasMachineDataFile. For
        % example, if mdfPropPrefix is 'pre', and the variables in the
        % Machine Data File are 'p1' and 'p2', HasMachineDataFile will
        % initialize the object properties 'prep1' and 'prep2'.
    end
    
    %% HIDDEN PROPERTIES
    
    properties (Hidden)
        mdfData;
        % structure where machine data variables will be stored.
    end
        
    %% CONSTRUCTOR/DESTRUCTOR
    methods (Access = protected)
        function obj = HasMachineDataFile(autoLoadMdf, mdfPath)
            
            if nargin < 1
                autoLoadMdf = true;
            end
            
            if nargin < 2
                mdfPath = '';
            end
            
            if autoLoadMdf
                obj.initializeMdf(mdfPath);
            end
        end
        
        
        function obj = initializeMdf(obj, mdfPath)
            
            if nargin < 2
                mdfPath = '';
            end
            
            varstruct = obj.getMDFVars(mdfPath); % can throw

            if isempty(obj.mdfDirectProp) || ~obj.mdfDirectProp
                obj.mdfData = varstruct;
            else
                pfix = obj.mdfPropPrefix;
                if isempty(pfix)
                    pfix = '';
                end
                varnames = fieldnames(varstruct);
                for i=1:length(varnames)
                    try
                        vname = varnames{i};
                        pname = sprintf('%s%s',pfix,vname);
                        obj.(pname) = varstruct.(vname); %This will call the property access method
                    catch %#ok
                        warnst = warning('off','backtrace');
                        warning('MachineDataFile:errorSettingProp',...
                            'Unrecognized variable ''%s'' under heading ''%s'' in machine data file for class ''%s''.',...
                            vname,obj.mdfHeading,class(obj));
                        warning(warnst);
                    end
                end
                
            end
        end
    end    
       
    %% STATIC METHODS
    methods (Static)
        
        % Reload machine data information from a new machine data file.
        % Call this method after modifying an existing machine data
        % file, or to specify a new machine data file.
        %
        % When called with no arguments, this brings up a uigetfile
        % dialog to select a new machine data file.
        function updateMachineDataFile(machineDataFile)
            if nargin==0
                [mdffile mdfpath] = uigetfile('*.m','Select machine data file');
                if isequal(mdffile,0) || isequal(mdfpath,0)
                    return;
                end
                fullfn = fullfile(mdfpath,mdffile);
                disp(['Machine Data File: <a href="matlab: edit ''' fullfn '''">' fullfn '</a>']);
            else
                if ~ischar(machineDataFile) || ~isvector(machineDataFile)
                    error('MachineDataFile:InvalidFileName',...
                        'The machineDataFile argument must specify a valid M-file containing rig data.');
                end                
                fullfn = which(machineDataFile);
                if isempty(fullfn)
                    % In the end, we will only be using the MDF name to
                    % fopen() the file. fopen() takes files specified with
                    % partial paths from the cwd, or with full paths.
                    % which(), however, only finds things on the path or in
                    % the cwd. For now we check existence of the file with
                    % which(). (If we checked with fopen(), and the user
                    % used path relative to cwd, then the user could change
                    % dirs after this call, and the MDF would not be
                    % found.) The upshot is that currently, to
                    % updateMachineData, you must specify a file that is on
                    % the path or in the cwd, so that MATLAB can find it
                    % with which(). The full filename is saved, so you can
                    % change dirs or your path afterwards and the MDF will
                    % continue to be found.
                    error('MachineDataFile:InvalidFileName',...
                        'Cannot find file ''%s''. Check filename and path.',machineDataFile);
                end
            end
                
            ws.most.HasClassDataFile.setClassDataVarStatic(...
                            'ws.most.HasMachineDataFile',...
                            'lastMachineDataFilePath',fullfn);

            mdf = ws.most.MachineDataFile.getInstance;
            mdf.load(fullfn);
        end
    end
    
    methods (Hidden)
        
        % Get the machine data variables for obj. This may require the user
        % to specify/edit an MDF. If successful, tf is true and vars is a
        % structure containing the vars/values found (could be empty). If
        % unsuccessful, tf is false and s is indeterminate.
        function vars = getMDFVars(obj, mdfPath)
            
            % "opt-out"
            if isempty(obj.mdfClassName)
                vars = struct();
                return;
            end
            
            heading = obj.mdfHeading;
            assert(~isempty(heading));
            
            mdf = ws.most.MachineDataFile.getInstance();
            status = ws.most.HasMachineDataFile.ensureMDFExists(mdfPath);
            switch status
                case {'exist' 'spec'}
                    msgFormatStr = 'Sections added to machine data file ''%s''. Edit file and save.';
                case 'create'
                    msgFormatStr = 'Edit new machine data file ''%s'' and save.';
                case 'cancel'
                    error('MachineDateFile: Operation canceled.');
                case 'fail'
                    error('MachineDateFile:FailedToLoadMDF','Failed to load Machine Data File.');
                otherwise
                    error('Internal error.');
            end
           
            assert(mdf.isLoaded);
            
            tfHeadingAdded = obj.ensureClassAndDependentsAreInMDF(class(obj)); % instead of class(obj), can also use obj.mdfClassName
            if tfHeadingAdded
                edit(mdf.fileName);
                msgStr = sprintf(msgFormatStr,mdf.fileName);
                uiwait(msgbox(msgStr,'Edit machine data file'));
                mdf.reload();
            end
            
            % Now read the MDF for the cls heading (it is still
            % possible that the heading is not there, eg if the
            % user deleted some stuff inadvertently etc)
            if ~mdf.isHeading(heading)
                mdf.unload;
                error('MachineDataFile:MachineDataFileMissingHeadingInfo',...
                    ['The machine data file does not include information for heading ''' heading '''.']);
            end
            
            [tf, vars] = mdf.getVarsUnderHeading(heading);
            if ~tf
                mdf.unload;
                error('MachineDataFile:errorReadingMachineDataFile',...
                    'Parse error reading machine data file for heading ''%s.''',...
                    heading);
            end
        end
        
    end
    
    methods (Static,Hidden)        
       
        % Ensures that there is an MDF loaded. If there isn't a valid
        % MDF loaded, this method prompts the user to specify/create
        % one.
        % status is either 'exist', 'spec', 'create', or 'fail',
        % depending on whether an MDF file is already loaded, the user
        % had to specify an existing MDF file to be loaded, the user
        % created a brand new MDF, or failure, respectively.
        function status = ensureMDFExists(mdfPath)
            mdf = ws.most.MachineDataFile.getInstance;
            
            % if mdf.isLoaded
            %    mdf.reload; 
            % end
            
            if mdf.isLoaded
                status = 'exist';
                return;
            end
            
            [tf specOrCreate path name] = zlclUserSpecifiesOrCreatesMDF(mdfPath);
            if tf
                mdfname = fullfile(path,name);
                disp(['Machine Data File: <a href="matlab: edit ''' mdfname '''">' mdfname '</a>']);
                mdf.load(mdfname);
                if ~mdf.isLoaded
                    status = 'fail';
                else              
                    ws.most.HasClassDataFile.setClassDataVarStatic(...
                        'ws.most.HasMachineDataFile',...
                        'lastMachineDataFilePath',mdfname);
                    status = specOrCreate;
                end
            else
                status = specOrCreate;
            end
        end
        
        % This function walks the mdf class dependency tree starting at
        % mdfCls and returns all dependent classes (including mdfCls
        % itself). The returned dependent classes will be distinct but not
        % in any particular order.
        function allDependentClasses = getAllDependentClasses(mdfCls)
            
            allDependentClasses = {mdfCls};
            dependentclasses = eval([mdfCls '.mdfDependsOnClasses;']);
            dependentclasses = setdiff(dependentclasses,allDependentClasses);
            while ~isempty(dependentclasses)
                % add the dependents
                allDependentClasses = [allDependentClasses;dependentclasses(:)]; %#ok<AGROW>
                
                % get the dependents of the dependents
                newdependents = cell(0,1);
                for c = 1:numel(dependentclasses)
                    tmp = eval([dependentclasses{c} '.mdfDependsOnClasses;']);
                    newdependents = [newdependents; tmp(:)]; %#ok<AGROW>
                end
                
                % eliminate those new deps that we already have, and uniqueify
                dependentclasses = setdiff(newdependents,allDependentClasses);
            end
        end
        
        % Ensures that the heading for the specified class and all its
        % dependents are in the currently loaded MDF. The return value is
        % true if the MDF is changed in any way by this function, ie if at
        % least one heading is added to the MDF.
        function tf = ensureClassAndDependentsAreInMDF(mdfCls)
            
            allClasses = ws.most.HasMachineDataFile.getAllDependentClasses(mdfCls);
            mdf = ws.most.MachineDataFile.getInstance;
            
            tf = false;
            for c = 1:numel(allClasses)
                cls = allClasses{c};
                hding = eval([cls '.mdfHeading']);
                mdfCls = eval([cls '.mdfClassName']);
                if ~mdf.isHeading(hding)
                    modelfn = zlclGetModelFullFileName(mdfCls);
                    mdf.copyModelFile(modelfn);
                    tf = true;
                end
            end
        end

    end  
end

%% HELPER FUNCTIONS
               
% Get the user to either i) create a new or ii) specify an existing MDF. If
% successful (tfsuccess true), mdfPath and mdfName are returned as strings.
% specOrCreate will be either 'spec' or 'create'. If unsuccessful
% (tfsuccess false), specOrCreate, mdfPath, and mdfName are indeterminate.
function [tfsuccess specOrCreate mdfPath mdfName] = zlclUserSpecifiesOrCreatesMDF(mdfPath)

    tfsuccess = false;
    specOrCreate = 'fail';

    [tflastmdf, lastmdf] = zlclGetLastMDFLocation();

    if nargin > 0 && ~isempty(mdfPath)
        if exist(mdfPath,'file')
            tfsuccess = true;
            specOrCreate = 'spec';
            [mdfPath,mdfName,ext] = fileparts(mdfPath);
            mdfName = [mdfName ext];
            if mdfPath(end) ~= filesep
                mdfPath(end+1) = filesep;
            end
            return;
        end
    end

    if tflastmdf
        [mdfName, mdfPath] = uigetfile('*.m','Select machine data file',lastmdf);
        if isequal(mdfName,0) || isequal(mdfPath,0) % user canceled or killed dlg
            resp = questdlg('There is currently no machine data file loaded.',...
                'No Machine Data File',...
                'Create new file','Cancel',...
                'Create new file');
            switch resp
                case 'Create new file'
                    mdfPath = uigetdir(fileparts(lastmdf),'Select directory for new machine data file');
                    if mdfPath
                        [~,mdfName] = ws.most.MachineDataFile.createNewMDF(mdfPath);
                        specOrCreate = 'create';
                        tfsuccess = true;
                    else
                        % none; failure
                    end
                otherwise
                    specOrCreate = 'cancel';
                    % none; failure
            end
        else
            tfsuccess = true;
            specOrCreate = 'spec';
        end
    else
        resp = questdlg('There is currently no machine data file loaded.',...
            'No Machine Data File',...
            'Specify existing file','Create new file','Cancel',...
            'Specify existing file');
        
        switch resp
            
            case 'Specify existing file'        
                [mdfName,mdfPath] = uigetfile('*.m','Select machine data file',lastmdf);
                if isequal(mdfName,0) || isequal(mdfPath,0)
                    % user canceled or killed dlg
                    specOrCreate = 'cancel';
                else
                    tfsuccess = true;
                    specOrCreate = 'spec';
                end
                
            case 'Create new file'
                mdfPath = uigetdir(fileparts(lastmdf),'Select directory for new machine data file');
                if mdfPath
                    [~,mdfName] = ws.most.MachineDataFile.createNewMDF(mdfPath);
                    specOrCreate = 'create';
                    tfsuccess = true;
                else
                    % user canceled or killed dlg
                    specOrCreate = 'cancel';
                end
                
            otherwise
                specOrCreate = 'cancel';
        end    
    end

    if ~tfsuccess
        mdfName = 0;
        mdfPath = 0;
    else
        assert(exist(fullfile(mdfPath,mdfName),'file')==2);
        assert(ismember(specOrCreate,{'spec' 'create'}));
    end
end

% If tf is true, there was a reasonable, nonempty value in the
% lastMachineDataFilePath ClassDataVar. fullfilename is that value.
%
% If tf is false, there was no reasonable, nonempty value in the
% lastMachineDataFilePath classdatavar. Fullfilename is a best guess at a
% reasonable starting point for an MDF path.
%
% fullfilename can be either a path or a (full) filename.
function [tf fullfilename] = zlclGetLastMDFLocation

ws.most.HasClassDataFile.ensureClassDataFileStatic(...
    'ws.most.HasMachineDataFile',struct('lastMachineDataFilePath',''));

lastmdfpath = ws.most.HasClassDataFile.getClassDataVarStatic(...
    'ws.most.HasMachineDataFile','lastMachineDataFilePath');

if ~isempty(lastmdfpath) && ~isempty(fileparts(lastmdfpath))
    % lastmdfpath is nonempty and "reasonable" (could be either path or file)
    tf = true;
    fullfilename = lastmdfpath;
else
    %Machine data file has never been stored
    tf = false;
    fullfilename = userpath;
end
end
  
function fname = zlclGetModelFullFileName(clsName)
    dotPositions = regexp(clsName,'\.');
    dotPositions(end+1) = 0;
    lastdot = max(dotPositions);
    strippedClsName = clsName(lastdot+1:end);
    fname = fullfile(ws.most.util.className(clsName,'classPrivatePath'),[strippedClsName '_model.m']);
end

