classdef ColumnArrayTable < ws.most.gui.control.PropControl
    %TABLECOLUMN A pseudo-control for a uitable where each table column represents an array value of a single type
    
    % NOTES
    %   TODO: Interpret NaN values as a non-entry for numeric options
    %   TODO(?): Add concept of 'table data' (shared by multiple properties) -- this could include means for setting the row names according to some template
       
    %% ABSTRACT PROPERTY REALIZATIONS (PropControl)
    properties (Dependent)
        propNames;
        hControls;
    end
        
    %% PUBLIC PROPERTIES
    properties (Dependent)
        nRows;
    end
    
    properties
        hTable; % the uitable handle
        NTableCols; % number of cols in the table
        colFormats; % NTableCols x 1 struct array with fields 'format' and 'info'
        colToPropName; % NTableCols x 1 cellstr. appPropNames{i} is the appPropName associated with the ith tabel column
        propToCol; % scalar struct. fields are propnames. vals are col idxs.
        rowHeadingPattern; % optional C-style format string for row heading names (with single '%d' to be replaced with row index). If not specified, rows are numbered.
		minNumRows; % optional number of blank rows to always maintain. At the moment this is only supported for read-only tables, ie tables for which decodeFcn is never called.
        tfReadOnly; % At the moment, a table is readonly whenever minNumRows>0
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods 

        % rowHeadingPattern (optional): C-style format string. See comment for property with this name.
        % minNumRows (optional): Minimum number of rows displayed in the table.
        function obj = ColumnArrayTable(uiTable,rowHeadingPattern,minNumRows)
            if nargin < 3
                minNumRows = 0;
            end
            if nargin < 2
                rowHeadingPattern = [];
            end
            
            assert(~isempty(uiTable) && ishandle(uiTable) && strcmp(get(uiTable,'Type'),'uitable'));
            obj.hTable = uiTable;
            obj.NTableCols = numel(get(uiTable,'ColumnFormat'));
            obj.rowHeadingPattern = rowHeadingPattern;
			obj.minNumRows = minNumRows;
            obj.tfReadOnly = (obj.minNumRows > 0); % For now, this is the case
            obj.labelTableRows();
        end
        
        function init(obj,metadata)
            % metadata should be a struct where the fieldnames are property
            % names and the values are scalar structs with the base
            % required fields 'columnIdx', 'format', in addition to any
            % "Default PropControlData" fields. There are additional
            % format-specific required/optional fields as described below.
            %
            % Available values of 'format':
            % * 'numeric': Prop is an array of numerics
            % * 'logical': Prop is array of logicals 
            % * 'logicalindices': Prop is indices of true values within array of logicals 
            % * 'cellstr' Prop is a cellstr
            % * 'options': Prop is one of an enumerated array of values
            %    specified in the required 'options' field. There is an
            %    additional, optional field 'prettyOptions'.
            %
            % ViewPrecision (in the "Default PropControlData") applies only
            % when format=='numeric'.
            %
            % Special handling for format=='options' and
            % 'options'==<numeric array> or <numeric cell array>:
            % * metadata must have an additional field
            %   'optionsForceArrayCell' whose value is a scalar logical. If
            %   true, the value of the model property corresponding to this
            %   table column is treated as a cell array (rather than a
            %   numeric array), ie encodeValue accepts a cell array and
            %   decodeValue produces a cell array.
            % * 'options' may contain a nan, indicating that "<empty>" is a
            %   valid option in the table. This requires that
            %   optionsForceArrayCell be true.
            %
            % The optional fields 'customEncodeFcn' and 'customDecodeFcn'
            % specify custom encode/decode functions that are applied to
            % table values after/before the regular formatting machinery
            % respectively. (At the moment only customEncodeFcn is
            % implemented).
            propNames = fieldnames(metadata);
            Nprops = numel(propNames);
            tableColFormat = get(obj.hTable,'ColumnFormat');
            assert(Nprops<=numel(tableColFormat)); % Nprops will be less than tableColFormat when a table has "empty" cols
            
            col2prop = cell(obj.NTableCols,1);
            prop2col = struct();
            colfmts = struct('format',cell(obj.NTableCols,1),...
                             'info',cell(obj.NTableCols,1),...
                             'customEncodeFcn',cell(obj.NTableCols,1));
            
            % ColumnArrayTable internally uses a "column format" data
            % structure that specifies the format of each column in the
            % table. colfmt (column format) spec:
            %
            % available formats: 'numeric', 'logical', 'logicalindices', 'cellstr', 'options'.
            %
            % if format is 'numeric', colfmt has optional additional field
            % 'ViewPrecision'.
            % 
            % if format is 'options', then colfmt has 'info' field. info has fields 
            % type (str enum: {'cellstr','numeric'}), tfPrettify (bool). 
            % * If info.type is 'cellstr' and info.tfPrettify==true, info
            % will also have 'reg2pret' and 'pret2reg' fields.
            % * If info.type is 'numeric', info will have a 'numericOptions'
            % field (cell array of numerics) and a 'isPropCell' field (bool). 
            % if info.tfPrettify==true, info will also have a 'prettyOptions' 
            % field (cellstr) and a numstr2pretty field (map).
            %
            % Optional colfmt fields: 'customEncodeFcn' and 'customDecodeFcn'. 

            for c = 1:Nprops
                pname = propNames{c};
                md = metadata.(pname);
                colIdx = md.columnIdx;
                
                prop2col.(pname) = colIdx;
                assert(isempty(col2prop{colIdx}));
                col2prop{colIdx} = pname;
                colfmts(colIdx).format = md.format;
                
                if isfield(md,'customEncodeFcn')
                    colfmts(colIdx).customEncodeFcn = md.customEncodeFcn;
                end
                
                % setup tableColFormat and rest of colfmts
                switch md.format
                    case 'numeric'
                        assert(ischar(tableColFormat{colIdx}) && ~iscell(tableColFormat{colIdx}) && ~ismember(tableColFormat{colIdx}, {'logical'}));
                        if isfield(md,'ViewPrecision')
                            assert(strcmp(tableColFormat{colIdx},'char'));
                            colfmts(colIdx).ViewPrecision = md.ViewPrecision;
                        end
                    case 'logical'
                        assert(ischar(tableColFormat{colIdx}) && strcmp(tableColFormat{colIdx},'logical'));
                    case 'logicalindices'
                        assert(ischar(tableColFormat{colIdx}) && strcmp(tableColFormat{colIdx},'logical'));
                    case 'cellstr'
                        assert(ischar(tableColFormat{colIdx}) && strcmp(tableColFormat{colIdx},'char'));
                    case 'options'
                        assert(isfield(md,'options'));
                        mdOptions = md.options;
                        colfmts(colIdx).format = 'options';
                        
                        if isnumeric(mdOptions) || all(cellfun(@isnumeric,mdOptions))
                            % numeric options
                            
                            colfmts(colIdx).info.type = 'numeric';

                            % set up colfmts.info.numericOptions (always a cell of numerics). 
                            % colfmts.info.numericOptions is only actually used if tfPrettify is true (below), 
                            % but for convenience just store it.
                            if isnumeric(mdOptions)
                                numOptions = size(mdOptions,1);
                                cellOpts = cell(numOptions,1);
                                for d = 1:numOptions
                                    cellOpts{d} = mdOptions(d,:);
                                end
                                colfmts(colIdx).info.numericOptions = cellOpts;
                            else % cell of numerics
                                colfmts(colIdx).info.numericOptions = mdOptions;
                            end
    
                            % deal with output type
                            colfmts(colIdx).info.isPropCell = md.optionsForceArrayCell;
                            
                            % If numericOptions has a row with only NaNs in
                            % it, it means that "<empty>" is a valid value
                            % for an element of this property. This only
                            % works if isPropCell is true.
                            tfNan = cellfun(@(x)all(isnan(x)),colfmts(colIdx).info.numericOptions);
                            if any(tfNan)
                                assert(colfmts(colIdx).info.isPropCell,...
                                    'If a numeric options list includes NaN, then optionsForceCellArray must be true.');
                                colfmts(colIdx).info.numericOptions(tfNan) = {nan}; % make "all nan" cells just a scalar nan
                            end
                            
                            % deal with prettiness
                            colfmts(colIdx).info.tfPrettify = isfield(md,'prettyOptions');
                            if colfmts(colIdx).info.tfPrettify
                                assert(iscellstr(md.prettyOptions));
                                assert(numel(md.prettyOptions)==numel(colfmts(colIdx).info.numericOptions));
                                colfmts(colIdx).info.prettyOptions = md.prettyOptions(:);
                                numstrs = cellfun(@mat2str,colfmts(colIdx).info.numericOptions,'UniformOutput',false);
                                assert(numel(numstrs)==numel(md.prettyOptions));
                                colfmts(colIdx).info.numstr2Pretty = containers.Map(numstrs(:),md.prettyOptions(:));
                            end                            
                            
                            % set up tableColFormat
                            if colfmts(colIdx).info.tfPrettify
                                tableColFormat{colIdx} = colfmts(colIdx).info.prettyOptions;
                            else
                                tabColFmt = cellfun(@mat2str,colfmts(colIdx).info.numericOptions,'UniformOutput',false);
                                tabColFmt(tfNan) = {'<empty>'};
                                tableColFormat{colIdx} = tabColFmt; 
                            end
                            
                        elseif iscellstr(mdOptions)
                            colfmts(colIdx).info.type = 'cellstr';
                            colfmts(colIdx).info.tfPrettify = isfield(md,'prettyOptions');
                            if colfmts(colIdx).info.tfPrettify
                                assert(iscellstr(md.prettyOptions));
                                assert(numel(md.prettyOptions)==numel(mdOptions));
                                colfmts(colIdx).info.pret2reg = cell2struct(mdOptions(:),md.prettyOptions(:),1);
                                colfmts(colIdx).info.reg2pret = cell2struct(md.prettyOptions(:),mdOptions(:),1);
                                tableColFormat{colIdx} = md.prettyOptions;
                            else
                                tableColFormat{colIdx} = mdOptions;
                            end
                        else 
                            assert(false); %Validation should have been done by Controller
                        end                        
                                                
                        %Ensure options are encoded as a row vector
                        tableColFormat{colIdx} = tableColFormat{colIdx}(:)';                        

                    otherwise
                        assert(false,'Unsupported format');
                end
            end
            
            set(obj.hTable,'ColumnFormat',tableColFormat);
            
            obj.colFormats = colfmts;
            obj.colToPropName = col2prop;
            obj.propToCol = prop2col;           
        end        
      
    end
    
    %% PROPERTY ACCESS METHODS
    methods        
        function v = get.propNames(obj)
            v = obj.colToPropName;
        end
        function v = get.hControls(obj)
            v = obj.hTable;            
        end
        function v = get.nRows(obj)
            d = get(obj.hTable,'Data');
            v = size(d,1);
        end
    end
    
    %% PUBLIC METHODS
    methods
        function [status propName val] = decodeFcn(obj,hObject,evtdata,~)
            assert(~obj.tfReadOnly,'Read only table.');
            
            %rowIdx = evtdata.Indices(1);
            colIdx = evtdata.Indices(2);
            propName = obj.colToPropName{colIdx};
            fmt = obj.colFormats(colIdx);
            
            % get data and convert according to col format
            data = get(hObject,'Data');
            val = data(:,colIdx);
            val = obj.decodeValue(val,fmt);
            status = 'set';
        end
        
        function encodeFcn(obj,propname,newVal)
            % newVal is encoded according to the format of the relevant column
            %
            % For read/write tables, numel(newVal) must match the current
            % number of rows. For readonly tables, numel(newVal) may be
            % smaller than the current number of rows. This is to support a
            % usage (at the moment, due to minNumRows) where the "real"
            % data is smaller than the displayed data.
            
            assert(isfield(obj.propToCol,propname));
            colIdx = obj.propToCol.(propname);
            fmt = obj.colFormats(colIdx);

            % encode new value
            data = get(obj.hTable,'Data');
            newVal = obj.encodeValue(newVal,fmt,size(data,1));            

            if obj.tfReadOnly
                assert(numel(newVal)<=size(data,1));
            else
                assert(numel(newVal)==size(data,1));
            end

            if numel(newVal) == size(data,1)
                data(:,colIdx) = newVal(:);
            else % numel(newVal) < size(data,1)
                data(1:numel(newVal),colIdx) = newVal(:);
                data(numel(newVal)+1:end,colIdx) = {[]};
            end
                            
            set(obj.hTable,'Data',data);
        end
        
        % This resizes the table to have the given number of rows.
        % Subsequent calls to encodeFcn must be made with data sized
        % appropriately for the new table dimensions.
        %
        % When a table grows as a result of resizing, new rows are padded
        % with the empty matrix []. The caller is expected to follow up any
        % such resize with calls to encodeFcn that populate the table with
        % appropriately-sized data. If this is not done and the table is
        % editable, the table will not be operational after the resize.
        %
        % Resize respects minNumRows, ie tables cannot be resized smaller
        % than minNumRows (when minNumRows is defined).
        function resize(obj,nrows)
            nrows = max(obj.minNumRows,nrows);
            
            data = get(obj.hTable,'Data');
            currentnrows = size(data,1);
            if nrows > currentnrows
                data(currentnrows+1:nrows,:) = cell(nrows-currentnrows,size(data,2));
            else
                data = data(1:nrows,:);
            end
            set(obj.hTable,'Data',data);
            obj.labelTableRows();

            %VI: Should we update model here?
		end
		
		function dims = getTableSize(obj)
			dims = size(get(obj.hTable,'Data'));
		end
		
    end

    %% PROTECTED/PRIVATE METHODS
    methods (Access=private)
        % label table rows based on rowHeadingPattern
        function labelTableRows(obj)
            if ~isempty(obj.rowHeadingPattern)
                nrows = size(get(obj.hTable,'Data'),1);
                rowNames = arrayfun(@(x)sprintf(obj.rowHeadingPattern,x),1:nrows,'UniformOutput',false);
                set(obj.hTable,'RowName',rowNames);
            end
        end
    end
    
    methods (Static,Access=private)
        
        % Decode a value v (a column of the table) according to a column format.
        function v = decodeValue(v,colfmt)
            assert(iscell(v));
            switch colfmt.format
                case 'numeric'
                    v = cell2mat(v);
                    if(ischar(v)), v=str2num(v); end
                case 'logical'
                    v = cell2mat(v);
                case 'logicalindices'
                    v = find(cell2mat(v));
                case 'cellstr'
                    % none
                case 'options'
                    switch colfmt.info.type
                        case 'cellstr'
                            if colfmt.info.tfPrettify
                                v = cellfun(@(x)colfmt.info.pret2reg.(x),v,'UniformOutput',false);
                            else
                                % no-op
                            end
                        case 'numeric'
                            if colfmt.info.tfPrettify
                                [tf,idxs] = ismember(v,colfmt.info.prettyOptions);
                                assert(all(tf));
                                v = colfmt.info.numericOptions(idxs);
                                tfNan = cellfun(@(x)all(isnan(x)),v);
                                v(tfNan) = {[]};
                            else
                                % Note: str2num('<empty>')==[].
                                v = cellfun(@str2num,v,'UniformOutput',false);
                            end
                            
                            if ~colfmt.info.isPropCell
                                v = cell2mat(v);
                            end
                        otherwise
                            assert(false);
                    end
                    
                otherwise
                    assert(false);
            end
        end
        
        % Encode array value v to a column of the table, according to the
        % column format. n is the number of rows in the table.
        function v = encodeValue(v,colfmt,n)
            switch colfmt.format
                case 'numeric'
                    assert(isnumeric(v));
                    if isfield(colfmt,'ViewPrecision')                       
                        v = v(:); %Force into column vector
                        v = num2str(v,colfmt.ViewPrecision); %#ok<ST2NM>
                        v = mat2cell(v,ones(1,size(v,1)),size(v,2));
                    else
                        v = num2cell(v);
                    end
                case 'logical'
                    assert(islogical(v)); % could also convert to logical
                    v = num2cell(v);
                case 'logicalindices'
                    assert(isnumeric(v));
                    newcol = false(n,1);
                    newcol(v) = true;
                    v = num2cell(newcol);
                case 'cellstr'
                    if(ischar(v)),v={v}; end
                    assert(iscellstr(v));                    
                case 'options'
                    switch colfmt.info.type
                        case 'cellstr'
                            if colfmt.info.tfPrettify
                                v = cellfun(@(x)colfmt.info.reg2pret.(x),v,'UniformOutput',false);
                            end
                        case 'numeric'
                            % put incoming value into a cell array
                            if colfmt.info.isPropCell
                                assert(iscell(v));
                                cellv = v;
                            else
                                % cellv = cell(n,1);
                                for c = size(v,1):-1:1
                                    cellv{c,1} = v(c,:);
                                end
                            end
                            
                            tfEmpty = cellfun(@isempty,cellv);
                            if colfmt.info.tfPrettify
                                cellv(tfEmpty) = {nan};
                                v = cellfun(@mat2str,cellv,'UniformOutput',false);
                                v = cellfun(@(x)colfmt.info.numstr2Pretty(x),v,'UniformOutput',false);
                            else
                                v = cellfun(@mat2str,cellv,'UniformOutput',false);
                                v(tfEmpty) = {'<empty>'};
                            end
                            
                        otherwise
                            assert(false);
                    end
                otherwise
                    assert(false);
            end
            
            if isfield(colfmt,'customEncodeFcn') && ~isempty(colfmt.customEncodeFcn)
                v = cellfun(colfmt.customEncodeFcn,v,'UniformOutput',false);
            end                
        end        
        
    end
    
end
