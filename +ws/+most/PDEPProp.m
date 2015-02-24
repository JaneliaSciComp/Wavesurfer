classdef PDEPProp < ws.most.DClass
    % Abstract mixin class that adds support for pseudo-dependent
    % properties
    %
    
    %% NOTES (2011-01-13)
    %   PDEPProp now has methods pdepSet/GetWithErr that will generate hard errors if set/get operations are succesful
    %   PDEPProp now has pdepSetSuccess event generated when a pdep set operation is successful
    %
    %   In future, we might look at overloading subsref/subsassign to make pdepGet/SetWithErr behavior occur automatically on all get/set operations 
    %   This was non-trivial though (see AL notes from 1/8/11) because get/set operations may involve chains of property/handle access.
    %
    %   SoAt moment, if classes need hard get/set-error behavior, they must expclicitly call pdepSet/GetWithErr
    %   PDEPProp does not compel this, but subclasses may choose/want to overload their set/get methods to automatically use pdepSet/GetWithErr()
    %
    %% NOTES (Original)
    %
    % 
    % The 'pseudo-dependent' property feature is intended to address following issues:
    %   * Allows abstract superclass to define and document concrete properties, while subclasses simply implement pseudo property-access methods. Avoids copy&paste of properties to preserve documentation strings. %TMW: Abstract property documentation inheritance would reduce some need for this. (WF: Similar restriction in JavaDoc)
    %   * Allows for inheritance/overriding of property-access methods, e.g. subclasses can override property access for each individual property and can likewise defer to superclass logic  %TMW: Current property-access methods do not support inheritance
    %   * Allows for a single switch-yard get/set methods to be defined at each subclass, which can decide between individuated, grouped, or default (this or superclass) handling of each property     %TMW: Some mechanism for get.(tag) or set.(tag) property-access methods might obviate this need
    %   * Allows superclass to (additionally) define property-specific set-access methods which can do error/type-checking without pushing that into subclass logic
    %   * Subclasses can make Hidden properties that are defined in a higher-level subclass, but this requires property be Abstract in the higher-level. %TMW: Would be nice to have ability to make subclass properties Hidden, without being an Abstract property (or, otherwise, preserving documentation)
    % Many of these features are particularly valueable for situations where class properties are connected to a hardware device's properties
    % There are some weaknesses of 'pseudo-dependent' properties:
    %   * Error conditions generated during set/get occur in callbacks (property access listeners) and do not generate an exception interrupting program flow (just a warning)
    %   * (Related) The variable still has a value even when in an error condition, so it becomes decoupled from device
    %
    %TODO: Improve specification of pdep properties -- i.e. don't necessarily blindly asssume /all/ set&get-observable properties are pdep properties
    %TODO: Consider whether we should /always/ use the PreSet listener, even if not using 'restoreCached' setErrorStrategy
    %
    %%  CHANGES
    %  TO091210A: Added some sane error messaging that's helpful in actually solving the problem. -- Tim O'Connor 9/12/10

    %% ABSTRACT PROPERTIES
    properties (Abstract, Constant, Hidden)
        % Either 'leaveErrorValue, 'setEmpty', 'restoreCached', or 'setErrorHookFcn'.
        % * leaveErrorValue': do nothing when error is caught setting prop.
        % * setEmpty: set prop to [] when error is caught setting prop.
        % * restoreCached: restore value from prior to the set action when error is caught setting prop.
        % * setErrorHookFcn: The subclass implements its own setErrorHookFcn() to handle set errors in subclass-specific manner.
        pdepSetErrorStrategy;
    end

    %% PRIVATE/PROTECTED PROPERTIES
    properties (Hidden, Transient)
        %Locks are used so that get/set listener methods do not invoke
        %their counterpart listener method in process of surreptitiously
        %getting/setting method. When lock is true, all but the original
        %pdep set/get operation are ineffectual.
        pdepPropGlobalLock=false;
        pdepPropLockMap;        

        pdepCachedPropertyValue;
        
        pdepSetAssertSuppress=false; %Flag used to handle special-case where unavailable prop is set to 'N/A'

        %Following properties should be added to subclasses, sans 'Raw', to override these defaults
        pdepPropGetListRaw = {}; %Itemized list of properties which will use psuedo-dependent get access. If empty, /all/ GetObservable properties will be presumed.
        pdepPropSetListRaw = {}; %Itemized list of properties which will use psuedo-dependent set access. If empty, /all/ SetObservable properties will be presumed.
    end
    
    properties (Access=private)
        pdepErrState = 'none'; % At runtime, either 'none', 'pend', or 'err'
        pdepErrInfo;
    end
    
    %% EVENTS
    events (NotifyAccess=private)
        pdepSetSuccess;
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    
    methods
        function obj = PDEPProp()
            obj.pdepPropLockMap = containers.Map({'dummy'}, {false}); %TMW: unnecessary in R2010a
            obj.pdepPropLockMap.remove('dummy');
            obj.pdepPropInitialize();
        end
    end


    %% ABSTRACT METHODS
    methods (Abstract, Access=protected)

        pdepPropHandleGet(obj, src, evnt);
        pdepPropHandleSet(obj, src, evnt);

        %A typical pdepPropHandleGet/Set implementation is:
        %
        %     function pdepPropHandleGet(obj,src,evnt)
        %             propName = src.Name;
        %
        %             switch propName
        %                 case {<List of Props with Individidual get<propName> methods}
        %                     obj.pdepPropIndividualGet(src,evnt);
        %                 case {<List of Props with particular grouped get method>}
        %                     obj.pdepPropGroupedGet(<groupGetMethod1>,src,evnt);
        %                 case {<List of Props with particular grouped get method>}
        %                     obj.pdepPropGroupedGet(<groupGetMethod2>,src,evnt);
        %                 .... etc
        %                 case {<List of Props to treat as ordinary pass-through property, with storage>}
        %                     %Do nothing --> pass-through
        %                 case {<List of Props to defer to superclass for handling>}
        %                     obj.pdepPropHandleGet@<superclassName>(src,evnt)
        %                 case {<List of Props for which get access returns simply 'N/A' indicating property irrelevance for subclass>}
        %                     obj.pdepPropGetUnavailable(src,evnt)
        %                 otherwise %Designate the Get/Set operation as disallowed (displays error (red) message, but does not generate error or set error condition)
        %                     obj.pdepPropGetDisallow(src,evnt)
        %             end
        %       end
        %
        % Depending on the mix of properties and their categorizations, the
        % category assigned to 'otherwise' can be selected,
        %   i.e. 'otherwise' can be used for the largest grouping of
        %   properties, reserving others for 'special cases'
        % 
    end
    
    %% SUPERUSER METHODS
    methods (Hidden)
        function val = pdepGetDirect(obj, propName)
            lockOrigVal = obj.pdepPropLockMap(propName);
            
            obj.pdepPropLockMap(propName) = true;
            val = obj.(propName);
            obj.pdepPropLockMap(propName) = lockOrigVal;
        end
        
        function pdepSetDirect(obj, propName, val)
            lockOrigVal = obj.pdepPropLockMap(propName);
            
            obj.pdepPropLockMap(propName) = true;
            obj.(propName) = val;
            obj.pdepPropLockMap(propName) = lockOrigVal;
        end
        
        % Returns true if propname is a PDEP prop from a get point of view
        % (has a preget listener).
        function tf = isGetListenProp(obj,propname)
            assert(~isempty(obj));
            tf = ismember(propname,obj(1).pdepPropGetListRaw);
        end
        
        % Returns true if propname is a PDEP prop from a set point of view
        % (has a preset, postset listener).
        function tf = isSetListenProp(obj,propname)
            assert(~isempty(obj));
            tf = ismember(propname,obj(1).pdepPropSetListRaw);
        end        
        
    end
        
    % Derived classes may find these utilities useful while implementing
    % their pdepPropHandleGet/Set methods.
    methods (Access=protected)

        function pdepPropGetDisallow(obj, src, evnt) %#ok<INUSD>
            propName = src.Name;
            fprintf(2, 'Specified property (%s) cannot be accessed for objects of class %s\n', propName, class(obj));
            
            obj.pdepSetAssertSuppress = true;
            try
                obj.(propName) = []; %Non-implemented property will be returned as empty
            catch ME
                obj.pdepSetAssertSuppress = true;
                ME.rethrow();
            end
        end
        
        function pdepPropSetDisallow(obj, src, evnt) %#ok<INUSD>
            propName = src.Name;
            fprintf(2, 'Specified property (%s) cannot be set for objects of class %s\n', propName, class(obj));
            obj.restoreCachedValue(propName); %Restore previous value
        end
        
        function pdepPropGetUnavailable(obj, src, evnt) %#ok<INUSD>
            propName = src.Name;
            obj.pdepSetAssertSuppress = true;
            try
                obj.(propName) = 'N/A';
            catch ME
                obj.pdepSetAssertSuppress = false;
                ME.rethrow();
            end
        end
        
        function pdepPropIndividualGet(obj, src, evnt) %#ok<INUSD>
            propName = src.Name;
            obj.(propName) = feval(['get' upper(propName(1)) propName(2:end)], obj);
        end
        
        function pdepPropIndividualSet(obj, src, evnt) %#ok<INUSD>
            propName = src.Name;
            feval(['set' upper(propName(1)) propName(2:end)], obj, obj.(propName));
        end
        
        function pdepPropGroupedGet(obj, methodHandle, src, evnt) %#ok<INUSD>
            propName = src.Name;
            obj.(propName) = feval(methodHandle, propName);
        end
        
        function pdepPropGroupedSet(obj,methodHandle, src, evnt) %#ok<INUSD>
            propName = src.Name;
            feval(methodHandle, propName, obj.(propName));
        end
        
        function pdepSetAssert(obj, inVal, assertLogical, errorMessage, varargin)
            %Subclasses with pseudo-dependent properties with set-property-access methods used for error/type-checking should use this method in lieu of 'assert'
            if ~obj.pdepSetAssertSuppress && ~assertLogical && ~(obj.errorCondition && isempty(inVal)) %Allows empty value to be set during error conditions, as done by this class, regardless of assertLogical condition requirements
                throwAsCaller(obj.DException('', 'PropSetAccessError', errorMessage, varargin{:}));
            end
        end
        
        function estr = pdepErrorMessage(obj,src,ME)
            estr = sprintf('Unable to access property ''%s'' in class ''%s'' because of the following error:\n\t%s\n',src.Name,class(obj),ME.message);
        end
    end
    
    %% DEVELOPER METHODS
    
    methods (Hidden)
        
        % Helper for pdepGet/SetWithErr
        function pdepPollErrState(obj,eid)
            switch obj.pdepErrState
                case 'err'
                    einfo = obj.pdepErrInfo;
                    obj.pdepErrInfo = [];
                    obj.pdepErrState = 'none';                   
                    error(eid,einfo);
                otherwise
                    obj.pdepErrState = 'none';
            end
        end
        
        % Throws a hard error if there is a failure during get (in the PDEP preget listener)
        function v = pdepGetWithErr(obj,propname)
            obj.pdepErrState = 'pend';
            v = obj.(propname);
            obj.pdepPollErrState('PDEPProp:GetError');
        end
        
        % Throws a hard error if there is a failure during set (in the PDEP postget listener)
        function pdepSetWithErr(obj,propname,v)
            obj.pdepErrState = 'pend';
            obj.(propname) = v;
            obj.pdepPollErrState('PDEPProp:SetError');
        end
        
        % AL 1/8/2011: Notes on pdepGetWithErr, pdepSetWithErr.
        % These methods exist because in some situations we want a failure
        % during set/get to result in a hard error. The pdep mechanism is
        % currently implemented using get/set listeners (callbacks), and
        % errors that occur during one of these callbacks (eg if a device
        % doesn't accept a value to be set) are not thrown as MEs in the
        % main ML thread; as a substitute we instead print an error message to
        % std error.
        %
        % Hard errors are prefered when the caller wants to try-catch the
        % property set or get on a PDEP device in order to trap errors and
        % maintain consistency of state with that device.
        %
        % We came up with two solutions to this issue:
        % i) Don't use set/get listeners in PDEP, instead overload
        % subsref/set. Then any errors that occur during set/get get thrown
        % as MEs into the caller.
        % ii) (Currently implemented) Callers that want a hard error call
        % pdepSet/GetWithErr. These methods 1. set an err bit, 2. perform
        % the set/get action (with resulting synchronous set/get
        % callbacks), and then 3. poll the bit, which is changed by the
        % callback if an err condition occurs.
		

    end
    
    methods 
		
		function varargout = subsref(obj,s)	
            try 
                switch s(1).type
                    case '.'
                        dotArg = s(1).subs;
                        if ~isempty(obj) && obj.isGetListenProp(dotArg)
                            assert(numel(obj)>=nargout);
                            if numel(s)==1
                                for c = 1:numel(obj)
                                    varargout{c} = pdepGetWithErr(obj(c),dotArg);
                                end
                            else
                                assert(numel(obj)==1); % multiple refs only supported for scalar obj
                                dotVal = pdepGetWithErr(obj,dotArg);
                                [varargout{1:nargout}] = subsref(dotVal,s(2:end));
                            end
                        else
                            [varargout{1:nargout}] = builtin('subsref',obj,s);
                        end
                    otherwise
                        if numel(s)==1
                            [varargout{1:nargout}] = builtin('subsref',obj,s(1));
                        else
                            base = builtin('subsref',obj,s(1));
                            [varargout{1:nargout}] = subsref(base,s(2:end));
                        end
                end
            catch ME
                ME.throwAsCaller();
            end
		end
		
		% This overloaded subsasgn will call pdepSetWithErr when
		% setting a isSetListenProp via dot access. Note: this
		% implementation supports the usage when obj contains other
		% pdep objects in a property. For example, if obj.prop1 is a
		% pdep object, obj.prop1.prop2 = 1 will call pdepSetWithErr on
		% the second object if 'prop2' is a set-listen-prop. However,
		% if obj can indirectly contain other pdep objects through eg
		% structs or cells, deeply-indexed assignments into such
		% objects may not result in pdepSetWithErr being called. (See
		% subsasgn notes below.)
		function obj = subsasgn(obj,s,b)
            try 
                if numel(s)==1
                    switch s.type
                        case '.'
                            dotArg = s.subs;
                            if obj.isSetListenProp(dotArg)
                                pdepSetWithErr(obj,dotArg,b);
                            else
                                obj = builtin('subsasgn',obj,s,b);
                            end
                        otherwise
                            obj = builtin('subsasgn',obj,s,b);
                    end
                else
                    v1 = subsref(obj,s(1));
                    v1 = subsasgn(v1,s(2:end),b);
                    
                    if isa(v1,'handle') && strcmp(s(2).type,'.')
                        % In this situation there is no need to reassign to obj.
                    else
                        obj = subsasgn(obj,s(1),v1);
                    end
                end
            catch ME
                ME.throwAsCaller()
            end
		end
		
		% Subsasgn notes:
		% Suppose classes C1 and C2 inherit from pdep, and c1 and c2 are instances.
		%
		% With the code
		%   c1.c1prop = c2;
		%   c1.c1prop.c2prop = 3;
		%
		% If in pdep::subsasgn you call builtin('subsasgn',...) for the second
		% indexing, pdep::subsasgn does not get called. If in pdep::subsasgn
		% you call subsasgn(...) for the second indexing, pdep::subsasgn DOES
		% get called.
		%
		% With the code
		%  c1.c1prop = struct('foo',c2);
		%  c1.c1prop.foo.p2 = 123;
		%
		% Whether in pdep::subsasgn you call builtin('subsasgn',...) OR
		% subsasgn(...) for the rest of the indexing, pdep::subsasgn DOES NOT
		% get called again.
		%
		% Presumably these are manifestations of "indexing within class
		% methods does not lead to calls of that class's
		% subsref/subsasgn". On the other hand, if c2 is replaced with
		% an instance of another class, then that instance's subsasgn
		% does indeed get called separately.
		
		% Advanced indexing unsupported:
		% [a.pp1{[2 1]}] = deal('no error','no error!!!');
		
		% Older subsasgn notes:
		% Anyway, something like the following may be a sketch of the
		% algorithm. Given a general indexed asgn like a1(i1).a2{i2}.a3... : 1.
		% Find the latest (right-most) handle object aH in the set (a1,a2,a3).
		% If PDEP::subsasgn is getting called, there is at least one handle,
		% the first object(s). This leaves you with H(i1).a1(i2).a2(i3)... 2.
		% Create the chain v1 = H(i1).a1; v2 = v1(i2).a2; v3 = v2(i3).a3 ... 3.
		% Perform the right-most assignment, then assign back up the chain
		%    ... v1(i2).a2 = v2; H(i1).pdepSetWithErr('a1',v1). Since H is the
		%    right-most handle obj, there are no other handle objs and hence no
		%    other PDEP objs in this chain.
		%
		% This code is necessary to support the general case. Natural questions:
		% Q. Is there ever a nested PDEP-within-a-PDEP case?
		% A. At least one, although it is a special case: the LSM object has a
		% PMT, so something like SIApp.hLSM.hPMT.prop = 1 is theoretically
		% possible.
		% Q. Can PDEP properties be complex-indexable values, like nonscalar
		% arrays, cells, structs?
		% A. Nonscalar arrays and cells, definitely. Structs, possibly. So
		% complex indexing definitely needs to be supported.
		
	end

    
    %True listener methods for pre-get, pre-set, post-set events
    methods (Hidden)
        % Helper for pdepPropHandleGet/SetHidden
        function pdepHandleErr(obj,src,ME)
            estr = obj.pdepErrorMessage(src,ME);
            switch obj.pdepErrState
                case 'pend'
                    obj.pdepErrState = 'err';
                    obj.pdepErrInfo = estr;
                case 'none'
                    fprintf(2,'WARNING: %s',estr);
                    assert(isempty(obj.pdepErrInfo));
                otherwise
                    assert(false);
            end                     
        end
        
        function pdepPropHandleGetHidden(obj, src, evnt)

            propName = src.Name;

            if ~obj.pdepPropGlobalLock && ...
                    (~obj.pdepPropLockMap.isKey(propName) || ~obj.pdepPropLockMap(propName))
                
                try
                    obj.pdepPropLockMap(propName) = true;
                    obj.pdepPropHandleGet(src, evnt);
                    obj.pdepPropLockMap(propName) = false;
                catch ME
                    obj.(propName) = [];
                    obj.pdepPropLockMap(propName) = false;
                    obj.pdepHandleErr(src,ME);
                    %fprintf(2, 'WARNING(%s): Unable to access property ''%s'' because of following error:\n\t%s\n%s\n', class(obj), propName, ME.message, getLastErrorStack(ME));%TO091210A
                    %ME.rethrow(); %Don't throw error, since this is a callback
                end                              
            end
        end

        function pdepPropHandlePreSetHidden(obj, src, evnt) %#ok<INUSD>
            % Caches the existing value before continuing with set operation

            % We want to cache the stored value (not actually 'get' the
            % device value), so use pdepPropLock
            if obj.pdepPropLockMap.isKey(src.Name)
                existingPropLock = obj.pdepPropLockMap(src.Name);
            else
                existingPropLock = false;
            end

            obj.pdepPropLockMap(src.Name) = true;    
            obj.pdepCachedPropertyValue = obj.(src.Name);                
            obj.pdepPropLockMap(src.Name) = existingPropLock;
        end

        function pdepPropHandleSetHidden(obj, src, evnt)

            propName = src.Name;

            if ~obj.pdepPropGlobalLock && ...
                    (~obj.pdepPropLockMap.isKey(propName) || ~obj.pdepPropLockMap(propName))
                
                tfErr = false;
                try
                    obj.pdepPropLockMap(propName) = true;
                    obj.pdepPropHandleSet(src, evnt);
                    obj.pdepPropLockMap(propName) = false;
                catch ME
                    tfErr = true;
                    if strcmp(obj.pdepSetErrorStrategy,'setErrorHookFcn')
                        assert(false); %TODO: implement this case
                    else
                        switch obj.pdepSetErrorStrategy
                            case 'leaveErrorValue'
                                %do nothing
                            case 'setEmpty'
                                obj.(propName) = [];
                            case 'restoreCached'
                                obj.restoreCachedValue(propName);
                            otherwise
                                assert(false);
                        end
                    end
                    
                    obj.pdepPropLockMap(propName) = false;
                    obj.pdepHandleErr(src,ME);
                end

                if ~tfErr
                    notify(obj,'pdepSetSuccess',ws.most.PDEPPropEventData(propName));
                end

                obj.pdepCachedPropertyValue = [];                
            end
        end
    end

    methods (Access=private)
        % Initialize pdep props by adding pdepprop listeners to appropriate properties
        function pdepPropInitialize(obj)

            mc = metaclass(obj);
            props = mc.Properties;

            overridableProps = {'pdepPropGetList' 'pdepPropSetList'};
            overrideProps =  props(cellfun(@(x)ismember(x.Name, overridableProps), props));

            for i=1:length(overrideProps)
                obj.([overrideProps{i}.Name 'Raw']) = obj.(overrideProps{i}.Name);
            end

            getListenProps = obj.pdepPropGetListRaw;
            if isempty(getListenProps)
                getListenProps = props(cellfun(@(x)x.GetObservable, props));
	            obj.pdepPropGetListRaw = cellfun(@(x)x.Name,getListenProps,'UniformOutput',false);
			end

            setListenProps = obj.pdepPropSetListRaw;
            if isempty(setListenProps)
                setListenProps = props(cellfun(@(x)x.SetObservable, props));
	            obj.pdepPropSetListRaw = cellfun(@(x)x.Name,setListenProps,'UniformOutput',false);
			end

            for i=1:length(getListenProps)
                obj.addlistener(getListenProps{i}, 'PreGet', @obj.pdepPropHandleGetHidden);
            end

            for i=1:length(setListenProps)
                obj.addlistener(setListenProps{i}, 'PostSet', @obj.pdepPropHandleSetHidden);
                obj.addlistener(setListenProps{i}, 'PreSet', @obj.pdepPropHandlePreSetHidden);
            end                       
        end
        
        function restoreCachedValue(obj, propName)
            obj.pdepPropLockMap(propName) = true;
            obj.(propName) = obj.pdepCachedPropertyValue;
            obj.pdepPropLockMap(propName) = false;
        end
    end
end
