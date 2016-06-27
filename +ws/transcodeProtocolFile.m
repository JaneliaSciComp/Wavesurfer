function transcodeProtocolFile(protocolFileName, newProtocolFileName)       
    % Note: whatever version of WS was used to generate the original
    % protocol file should be installed when you run this function.

    s = load(protocolFileName, '-mat') ;
    s.ws_WavesurferModel = transcode(s.ws_WavesurferModel) ;
    save(newProtocolFileName,'-mat','-struct','s') ;
end

function result = transcode(thing)        
    % This is a function to convert the pickled representation of
    % ws.WavesurferModel in an older (circa 0.8) protocol file to something
    % with a similar structure that contains only objects of the the
    % built-in Matlab classes.  The returned things is an "encoding
    % container": a scalar struct with two fields: className and encoding.
    % The className gives, well, the classname of the encoded object, and
    % the encoding gives an encoding of that object (which consists only of
    % built-in object types).  Typically, if you load in an old config
    % (using load -mat), then do:
    %
    %   ws_WavesurferModel = transcode(ws_WavesurferModel) ;
    %
    % and then save under a different name, it will be easier to get that
    % new 'protocol file' to load in a recent version of Matlab.
    
    if isstruct(thing) && isscalar(thing) && isfield(thing,'className') && isfield(thing, 'encoding') ,
        % This is an encoding container
        className = thing.className ;
        encoding = thing.encoding ;
        if isnumeric(encoding) || ischar(encoding) || islogical(encoding) ,
            transcoded = encoding ;
        elseif iscell(encoding) ,
            transcoded=cell(size(encoding));
            for j=1:numel(encoding) ,
                transcoded{j} = transcode(encoding{j});
            end
        elseif isstruct(encoding) ,
            fieldNames=fieldnames(encoding);
            transcoded = structWithDims(size(encoding),fieldNames) ;
            for i=1:numel(encoding) ,
                for j=1:length(fieldNames) ,
                    thisFieldName=fieldNames{j};
                    %if isequal(thisFieldName, 'AnalogChannelUnits_') ,
                    %    keyboard ;
                    %end
                    if isequal(thisFieldName,'Parent') || isequal(thisFieldName,'Parent_')
                        % skip
                    else
                        transcoded(i).(thisFieldName) = transcode(encoding(i).(thisFieldName)) ;
                    end
                end
            end
        else
            error('An encoding container has an encoding with an odd type: %s', class(encoding)) ;
        end
        result = struct('className', {className}, 'encoding', {transcoded}) ;
    elseif isnumeric(thing) || ischar(thing) || islogical(thing) ,
        result = thing ;
    elseif iscell(thing) ,
        result=cell(size(thing));
        for j=1:numel(thing) ,
            result{j} = transcode(thing{j});
        end
    elseif isstruct(thing) ,
        fieldNames=fieldnames(thing);
        result = structWithDims(size(thing),fieldNames) ;
        for i=1:numel(thing) ,
            for j=1:length(fieldNames) ,
                thisFieldName=fieldNames{j};
                if isequal(thisFieldName, 'AnalogChannelUnits_') ,
                    keyboard ;
                end                
                if isequal(thisFieldName,'Parent') || isequal(thisFieldName,'Parent_')
                    % skip
                else
                    result(i).(thisFieldName) = transcode(thing(i).(thisFieldName)) ;
                end
            end
        end
    elseif isa(thing,'ws.stimulus.StimulusLibrary') || isa(thing,'ws.stimulus.Stimulus') || isa(thing,'ws.stimulus.StimulusMap') || ...
           isa(thing,'ws.stimulus.StimulusSequence') || isa(thing,'ws.stimulus.StimulusDelegate') || isa(thing,'ws.ElectrodeManager') || ...
           isa(thing,'ws.Electrode') || isa(thing,'ws.EPCMasterSocket') || isa(thing,'ws.MulticlampCommanderSocket') ,
        if isscalar(thing) ,
            originalState=ws.utility.warningState('MATLAB:structOnObject');
            warning('off','MATLAB:structOnObject')
            s = struct(thing) ;  
            warning(originalState,'MATLAB:structOnObject');
            encoding = transcode(s) ;
            result = struct('className', {class(thing)}, 'encoding', {encoding}) ;  % containerize this thing while we're at it
        else
            encoding=cell(size(thing));
            for j=1:numel(thing) ,                
                encoding{j} = transcode(thing(j)) ;
            end
            result = struct('className', {'cell'}, 'encoding', {encoding}) ;  % containerize this thing while we're at it
        end        
    elseif isa(thing,'event.listener') ,
        result = struct('className', {'double'}, 'encoding', {[]}) ;
    elseif isa(thing,'ws.utility.DoubleString') ,
        encoding=zeros(size(thing));
        for j=1:numel(thing) ,
            encoding(j) = thing(j).toDouble() ;
        end
        result = struct('className', {'double'}, 'encoding', {encoding}) ;
    elseif isa(thing,'ws.ElectrodeMode') ,
        encoding=cell(size(thing));
        for j=1:numel(thing) ,            
            encoding{j} = thing(j).toCodeString() ;
        end
        result = struct('className', {'cell'}, 'encoding', {encoding}) ;  % containerize this thing while we're at it
    elseif isa(thing,'ws.utility.SIUnit') ,
        encoding=cell(size(thing));
        for j=1:numel(thing) ,            
            encoding{j} = thing(j).string() ;
        end
        result = struct('className', {'cell'}, 'encoding', {encoding}) ;  % containerize this thing while we're at it
    else                
        error('transcode:dontKnowHowToTranscode', ...
              'Don''t know how to transcode a thing of class %s', ...
              class(thing));
    end    
end

function result=structWithDims(dims,fieldNames)
    % dims a row vector of dimensions
    % fieldNames a cell array of strings
    
    if length(dims)==0 , %#ok<ISMT>
        dims=[1 1];
    elseif length(dims)==1 ,
        dims=[dims 1];
    end
    
    if isempty(fieldNames) ,
        wasFieldNamesEmpty=true;
        fieldNames={'foo'};
    else
        wasFieldNamesEmpty=false;
    end
        
    template=cell(dims);
    nFields=length(fieldNames);
    args=cell(1,2*nFields);
    for fieldIndex=1:nFields ,
        argIndex1=2*(fieldIndex-1)+1;
        argIndex2=argIndex1+1;
        args{argIndex1}=fieldNames{fieldIndex};
        args{argIndex2}=template;  
    end
    
    result=struct(args{:});
    
    if (wasFieldNamesEmpty) ,
        result=rmfield(result,'foo');
    end
    
end
