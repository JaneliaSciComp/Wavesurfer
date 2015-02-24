classdef PropertyTable < ws.most.gui.control.PropControl
  %PROPERTYTABLE PseudoControl for a property table (PV pairs)
  %
  % A PropertyTable is a scrollable list of P-V pairs implemented as a
  % UITable. The properties are listed in alphabetical order and are not
  % editable. Typically the properties correspond to properties in an
  % underlying model object. The values are editable as strings;
  % property-specific type conversions are performed based on format
  % specifications.
  
  %% PUBLIC PROPERTIES
  properties
    alphabetize = true;
  end
  
  %% ABSTRACT PROPERTY REALIZATIONS (PropControl)
  properties (Dependent)
    propNames;
    hControls;
  end
  
  properties (Access=private)
    fHTable; % the uitable handle
    fPropNames; % N x 1 cellstr of property names, one for each table row
    fProp2Row; % struct from prop name -> row idx
    fFormatInfo; % N x 1 struct with fields 'format' and 'info'. avail formats: 'numeric', 'cell', 'logical', 'char', 'map'. The 'info' field contains the optional 'ViewPrecision' field
    % Note: Unfortunately, 'map' support is currently incomplete for
    % the typical MVC usage because of the way MATLAB subsasgn works.
    % Suppose for example that an App (derived from Model) object 'obj'
    % has a property 'p' which holds a containers.Map. Now code such as
    %
    % obj.p(key) = val;
    %
    % will NOT trigger the PostSet event for 'p', since the value of p
    % has not changed (it is the same handle it was before). Thus
    % command-line changes to a containers.Map prop will not update any
    % views.
    %
    % On the other hand, changes made to a PropertyTable will be
    % reflected in the model.
  end
  
  methods
    function set.alphabetize(obj,val)
      validateattributes(val,{'numeric' 'logical'},{'scalar' 'binary'});
      obj.alphabetize = val;
    end
    
    
    function v = get.propNames(obj)
      v = obj.fPropNames;
    end
    function v = get.hControls(obj)
      v = obj.fHTable;
    end
  end
  
  methods
    
    function obj = PropertyTable(uiTable)
      assert(ishandle(uiTable));
      obj.fHTable = uiTable;
      obj.reset();
    end
    
    % Metadata is a struct whose fields are property names:
    % eg: metadata.prop1 = struct('format','numeric',...<default PropControl data for prop1>);
    %     metadata.prop2 = struct('format','cell',...<default PropControl data for prop2>);
    %       etc
    function init(obj,metadata)
      assert(ishandle(obj.fHTable));
      set(obj.fHTable,'ColumnFormat',{'char' 'char'});
      set(obj.fHTable,'Data',cell(0,2));
      obj.addProps(metadata);
    end
    
    % Add (dynamically) one or more properties to the PropertyTable.
    % New properties do *not* have their values initted (they start
    % with '').
    % metadata: a struct in the same format as that provided to
    % PropertyTable::init.
    function addProps(obj,metadata)
      assert(isstruct(metadata));
      
      % check for dup properties
      newPropNames = fieldnames(metadata);
      assert(~any(ismember(newPropNames,obj.fPropNames)),'Name conflict with existing prop.');
            
      allPropNames = [obj.fPropNames;newPropNames];
      if obj.alphabetize
        allPropNames = sort(allPropNames);
      end
      NAllProps = numel(allPropNames);
      
      data = cell(NAllProps,2);
      data(:,1) = allPropNames;
      
      allProp2Row = struct();
      allFormatInfo = struct('format',cell(0,1),'info',cell(0,1));
      for c = 1:NAllProps
        pname = allPropNames{c};
        allProp2Row.(pname) = c;
        if isfield(obj.fProp2Row,pname) % this is an existing prop
          oldRowIdx = obj.fProp2Row.(pname);
          allFormatInfo(c).format = obj.fFormatInfo(oldRowIdx).format; % use existing format
        else % new prop
          allFormatInfo(c).format = metadata.(pname).format;
          if isfield(metadata.(pname),'ViewPrecision')
            allFormatInfo(c).info.ViewPrecision = metadata.(pname).ViewPrecision;
          end
          data{c,2} = ''; % new props have unset vals
        end
      end
      
      obj.fPropNames = allPropNames;
      obj.fProp2Row = allProp2Row;
      obj.fFormatInfo = allFormatInfo;
      set(obj.fHTable,'Data',data);
    end
    
    % Reset propertyTable to clean/"empty" state.
    function reset(obj)
      set(obj.fHTable,'Data',cell(0,2));
      obj.fPropNames = cell(0,1);
      obj.fProp2Row = struct();
      obj.fFormatInfo = struct('format',cell(0,1),'info',cell(0,1));
    end
    
    function [status propname val] = decodeFcn(obj,~,evtdata,~)
      rowIdx = evtdata.Indices(1);
      assert(evtdata.Indices(2)==2);
      propname = obj.fPropNames{rowIdx};
      finfo = obj.fFormatInfo(rowIdx);
      
      status = 'set';
      try
        val = obj.decodeValue(evtdata.NewData,finfo);
      catch %#ok<CTCH>
        status = 'revert';
        val = [];
      end
    end
    
    function encodeFcn(obj,propname,newVal)
      rowIdx = obj.fProp2Row.(propname);
      finfo = obj.fFormatInfo(rowIdx);
      
      newVal = obj.encodeValue(newVal,finfo);
      data = get(obj.fHTable,'Data');
      data{rowIdx,2} = newVal;
      set(obj.fHTable,'Data',data);
    end
    
  end
  
  methods (Static,Access=private)
    
    % Convert a value to a displayable string according to fmtInfo
    function v = encodeValue(v,fmtInfo)
      switch fmtInfo.format
        case 'numeric'
          if isfield(fmtInfo.info,'ViewPrecision')
            v = mat2str(v,fmtInfo.info.ViewPrecision);
          else
            v = mat2str(v);
          end
        case {'char' 'logical' 'cell' 'map'}
          v = ws.most.util.toString(v);
        otherwise
          assert(false);
      end
    end
    
    % Convert a string to a value according to fmtInfo.
    % Throws if decode fails.
    function v = decodeValue(v,fmtInfo)
      switch fmtInfo.format
        case {'char' 'numeric' 'logical' 'cell'}
          v = eval(v);
        case 'map'
          v = ws.most.util.str2map(v);
        otherwise
          assert(false);
      end
    end
    
  end
  
end

