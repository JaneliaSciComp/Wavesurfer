classdef SIUnit
    % A class to represent an SI unit, either base or derived.
    %
    % Examples:
    %   string(SIUnit('mV')/SIUnit('pA')) => 'GOhm'
    %   string(SIUnit('pA')/SIUnit('mV')) => 'nS'
    %    string(SIUnit('kg')*(SIUnit('m')/SIUnit('s'))*(SIUnit('m')/SIUnit('s')))
    %     => 'J'  (As in E=m*c^2)
    %
    % Doesn't deal very well with kg (kilogram).  For instance:
    %
    %   SIUnit('mg') => <error>  (Because g is not an SI unit.)
    %   string(SIUnit('kg')*10^-6) => 'ukg'  (I.e. a microkilogram)
    %
    % N.B. Uses 'u' for micro, 'Ohm' for ohm.
    properties (Constant=true, Access=protected)
        NBases=7    % the number of base units
        BaseStems={'kg' 'm' 's' 'C' 'K' 'mol' 'cd'}';    % the base units
        Stems={'kg' 'm' 's' 'C' 'K' 'mol' 'cd' 'A' 'V' 'N' 'Hz' 'Ohm' 'S' 'W' 'Pa' 'J' 'F'}';
           % the useful abbreviations for units
        StemsPowers=  [ 1  0  0  0  0  0  0 ; ...
                        0  1  0  0  0  0  0 ; ...
                        0  0  1  0  0  0  0 ; ...
                        0  0  0  1  0  0  0 ; ...
                        0  0  0  0  1  0  0 ; ...
                        0  0  0  0  0  1  0 ; ...
                        0  0  0  0  0  0  1 ; ...
                        0  0 -1  1  0  0  0 ; ...
                        1  2 -2 -1  0  0  0 ; ...
                        1  1 -2  0  0  0  0 ; ...
                        0  0 -1  0  0  0  0 ; ...
                        1  2 -1 -2  0  0  0 ; ...
                       -1 -2 +1 +2  0  0  0 ; ...
                        1  2 -3  0  0  0  0 ; ...
                        1 -1 -2  0  0  0  0 ; ...
                        1  2 -2  0  0  0  0 ; ...
                       -1 -2  2  2  0  0  0 ];
          % the powers to raise the fundamental units to to a particular derived unit
        PrefixScales=[-24 -21 -18 -15 -12 -9 -6 -3 -2 -1 0 1 2 3 6 9 12 15 18 21 24]';
          % the powers of ten that we have prefixes for
        Prefixes={'y' 'z' 'a' 'f' 'p' 'n' 'u' 'm' 'c' 'd' '' 'da' 'h' 'k' 'M' 'G' 'T' 'P' 'E' 'Z' 'Y'}';
          % the prefixes
    end  % properties

    properties (SetAccess=immutable)
        Scale  % the power of ten by which the stem unit is multiplied, a scalar double
        Powers  % the exponent for each of the base units, a double row vec of length NBases
    end
    
    properties (GetAccess=protected, SetAccess=immutable)
        String_  % If constructed from a string, the string used to construct.  Otherwise [] (not ''!).
    end  % properties
    
    %----------------------------------------------------------------------
    methods
        function unit=SIUnit(varargin)
            % Constructor for SIUnit. Will take 0, 1, or 2 args.
            %   0 args: Returns the pure unit with unit magnitude.
            %   1 arg: Arg must be a string like 'kg', 'nA', 'um', etc.
            %   2 arg: First argument is Scale property, second is Powers.
            %          Scale is the power of ten corresponding to the
            %          prefix, Powers is the power to which each base unit
            %          will be raised: kg m s C K mol cd
            import ws.utility.SIUnit
            isBadArgs=false;
            if (nargin==0)
                % Return pure unity
                unit.Scale=0;
                unit.Powers=zeros(1,SIUnit.NBases);
                unit.String_ = [] ;
            elseif (nargin==1)
                % should just be a string arg
                str=varargin{1};
                if ischar(str)
                    % need to detemine the unit from str, which is assumed
                    % to be an abbreviation
                    [scale,powers] = SIUnit.parseUnitString(str) ;
                    unit.Scale = scale ;
                    unit.Powers = powers ;
                    unit.String_ = str ;
                else
                    isBadArgs=true;
                end
            elseif (nargin==2)
                % first arg sets the Scale (power of ten), 2nd arg is a a 7x1 array of
                % Powers for the base units 'kg' 'm' 's' 'C' 'K' 'mol' 'cd'
                if isscalar(varargin{1}) && size(varargin{2},1)==1 && size(varargin{2},2)==SIUnit.NBases ,
                    unit.Scale=varargin{1};
                    unit.Powers=varargin{2};
                    unit.String_ = [] ;
                else
                    isBadArgs=true;
                end
            else
                isBadArgs=true;
            end
            if (isBadArgs)
               error('SIUnits:badConstructorArgs','Bad arguments to SIUnit constructor');
            end
        end
        
        %------------------------------------------------------------------
        function result=hasIdiomaticPrefix(unit)
            % Whether the unit has an 'idiomatic' prefix, i.e. one of the
            % usual prefixes like k for kilo, M for mega.  Note that no
            % prefix ('') is counted as an idiomatic prefix.
            result=ischar(idiomaticPrefix(unit));
        end

        %------------------------------------------------------------------
        function result=idiomaticPrefix(unit)
            % If the unit has an idiomatic prefix, returns it as a string.
            % if not, returns nan
            import ws.utility.SIUnit
            prefixList=SIUnit.Prefixes(unit.Scale==SIUnit.PrefixScales);
            if isempty(prefixList)
                % doesn't match a specific case
                result=nan;
            else
                result=prefixList{1};
            end
        end
        
        %------------------------------------------------------------------
        function result=nonidiomaticPrefix(unit)
            % Get the nonidiomatic prefix for the unit.  This is a string
            % like '10^3', or '1'.
            if unit.Scale==0 ,
                result='1';
            elseif round(unit.Scale)/unit.Scale-1 < 1e-12
                result=sprintf('10^%d',unit.Scale);
            else
                result=sprintf('10^%g',unit.Scale);
            end
        end
        
        %------------------------------------------------------------------
        function result=prefix(unit)
            % Get the prefix for the unit.  This is the idiomatic prefix is
            % it exits, and the nonidiomatic prefix otherwise.
            result=idiomaticPrefix(unit);
            if isnan(result)
                % doesn't match a specific case
                result=nonidiomaticPrefix(unit);
            end
        end
        
        %------------------------------------------------------------------
        function result=hasIdiomaticStem(unit)
            % Whether the unit has an 'idiomatic' stem, like
            % 'm', 's', 'V', 'mol', etc.
            result=~isnan(idiomaticStem(unit));
        end

        %------------------------------------------------------------------
        function result=idiomaticStem(unit)
            % The 'idiomatic' stem of the unit, like 'm', 's', 'V', 'mol',
            % if it exists.  Otherwise, returns nan.
            import ws.utility.SIUnit
            %nStems=length(SIUnit.Stems);
            %hasIdiomaticStem=false;
            stemsPowers=SIUnit.StemsPowers;
            powerMatches=bsxfun(@eq,unit.Powers,stemsPowers);
            isMatch=all(powerMatches,2);
            iMatch=find(isMatch,1);
            if isempty(iMatch) ,
                result=nan;
            else
                result=SIUnit.Stems{iMatch};
            end
%             for i=1:nStems ,
%                 if all(unit.Powers==SIUnit.StemsPowers(i,:)) ,
%                     result=SIUnit.Stems{i};
%                     hasIdiomaticStem=true;
%                     break
%                 end
%             end
%             if ~hasIdiomaticStem ,
%                 result=nan;
%             end
        end

        %------------------------------------------------------------------
        function result=nonidiomaticStem(unit)
            % The nonidiomatic stem for the unit.  E.g.
            % nonidiomaticStem(SIUnit('W')) => 'kg*m^2*s^-3'
            import ws.utility.SIUnit
            needConjunction=false;
            result='';
            for i=1:SIUnit.NBases ,
                if unit.Powers(i)~=0 ,
                    if unit.Powers(i)==1 ,
                        thisSnippet=SIUnit.BaseStems{i};
                    else
                        if round(unit.Powers(i))==unit.Powers(i) ,
                            thisSnippet=sprintf('%s^%d',SIUnit.BaseStems{i},unit.Powers(i));
                        else
                            thisSnippet=sprintf('%s^%g',SIUnit.BaseStems{i},unit.Powers(i));
                        end
                    end
                    if needConjunction ,
                        result=sprintf('%s*%s',result,thisSnippet);
                    else
                        result=sprintf('%s%s',result,thisSnippet);
                        needConjunction=true;
                    end
                end
            end
        end

        %------------------------------------------------------------------
        function result=stem(unit)
            % Returns the idiomatic stem is the unit has one, otherwise the
            % nonidiomatic stem.
            result=idiomaticStem(unit);
            if isnan(result) ,
                result=nonidiomaticStem(unit);
            end
        end

        %------------------------------------------------------------------
        function result=isPure(unit)
            % Whether the unit is pure, i.e. dimensionless.  The unit can
            % still have a non-zero Scale property, even if this is true.
            result=all(unit.Powers==0);
        end
        
        %------------------------------------------------------------------
        function result=string(unit)
            % A string describing the unit.  In the nicest cases, this is a
            % string containing an idiomatic prefix concatenated to an
            % idiomatic stem.  In other cases, it can be something like 
            % '10^4*kg*m^2*s^-4', or even '(pure)' or '*10^-2'.
            if isempty(unit) ,
                result='';
            elseif isscalar(unit) ,
                result=stringElement(unit);
            else
                % do a cell array in this case (is this really wise?)
                result=cell(size(unit));
                for i=1:numel(unit) ,
                    result{i}=stringElement(unit(i));
                end
            end
        end
        
        %------------------------------------------------------------------
        function result=stringElement(unit)
            % A string describing the unit.  In the nicest cases, this is a
            % string containing an idiomatic prefix concatenated to an
            % idiomatic stem.  In other cases, it can be something like 
            % '10^4*kg*m^2*s^-4', or even '(pure)' or '*10^-2'.
            if ~isscalar(unit) ,
                error('SIUnit:tooBig', ...
                      'The SIUnit.string() method only works on scalar SIUnit arrays'); 
            end
            % If we get here, unit is scalar
            if ischar(unit.String_) ,
                % If the unit was constructed from a string, return that
                % string
                result = unit.String_ ;
            else
                % If the unit was not constructed from a string, compute an
                % equivalent string.
                idiomaticStemThis=idiomaticStem(unit);
                hasIdiomaticStemThis=~isnan(idiomaticStemThis);
                if hasIdiomaticStemThis , 
                    if unit.Scale==0 ,
                        result=idiomaticStemThis;
                    else
                        idiomaticPrefixThis=idiomaticPrefix(unit);
                        if ischar(idiomaticPrefixThis) ,
                            result=[idiomaticPrefixThis idiomaticStemThis];
                        else
                            result=[prefix(unit) '*' idiomaticStemThis];
                        end
                    end
                else
                    % no idiomatic stem
                    if isPure(unit) ,
                        % pure number is a special case
                        if unit.Scale==0 ,
                            result='';
                        else
                            result=['*' nonidiomaticPrefix(unit)];
                        end
                    else
                        if unit.Scale==0 ,
                            result=nonidiomaticStem(unit);
                        else
                            result=[nonidiomaticPrefix(unit) '*' nonidiomaticStem(unit)];
                        end
                    end
                end                
            end
        end
        
        %------------------------------------------------------------------
        function result=toString(unit)
            result=string(unit);
        end

        %------------------------------------------------------------------
        function result=areSummable(unit,otherUnit)
            result=arrayfun(@areSummableScalar, ...
                            unit, ...
                            otherUnit);
        end
        
        %------------------------------------------------------------------
        function result=areSummableScalar(unit,otherUnit)
            result=all(unit.Powers==otherUnit.Powers);
        end

        %------------------------------------------------------------------
        function result=multiplier(unit)
            result=10.^unit.Scale;
        end

%         %------------------------------------------------------------------
%         function disp(unit)
%             fprintf('     %s\n\n',string(unit));
%         end
        
        %------------------------------------------------------------------
        function result=mtimes(arg1,arg2)  % don't want to always have to use .*
            result=times(arg1,arg2);
        end
        
        %------------------------------------------------------------------
        function result=times(arg1,arg2)
            % Take the product of an SIUnit and either an SIUnit or a number.  
            % This does what you'd think.
            import ws.utility.objectFunctionUnary
            import ws.utility.objectFunctionBinary            
            if isscalar(arg1),
                if isscalar(arg2) ,
                    result=timesScalar(arg1,arg2);
                else
                    result=objectFunctionUnary(@(x)(timesScalar(arg1,x)), ...
                                               arg2);
                end
            else
                if isscalar(arg2) ,
                    result=objectFunctionUnary(@(x)(timesScalar(x,arg2)), ...
                                               arg1);
                else
                    result=objectFunctionBinary(@timesScalar, ...
                                                arg1, ...
                                                arg2);
                end
            end            
        end
        
        %------------------------------------------------------------------
        function result=timesScalar(arg1,arg2)
            % Take the product of an SIUnit and either an SIUnit or a number.  
            % This does what you'd think.
            import ws.utility.SIUnit
            if isa(arg1,'SIUnit') ,
                if isa(arg2,'SIUnit')
                    result=SIUnit(arg1.Scale+arg2.Scale,arg1.Powers+arg2.Powers);
                else
                    % arg2 better be a number
                    result=SIUnit(arg1.Scale+log10(arg2),arg1.Powers);
                end
            else
                if isa(arg2,'SIUnit')
                    % arg1 better be a number
                    result=SIUnit(log10(arg1)+arg2.Scale,arg2.Powers);
                else
                    % this shouldn't happen...
                    result=arg1.*arg2;
                end
            end
        end
        
        %------------------------------------------------------------------
        function result=mrdivide(arg1,arg2)  % don't want to always have to use ./
            result=rdivide(arg1,arg2);
        end
        
        %------------------------------------------------------------------
        function result=rdivide(arg1,arg2)
            % Take the quotient of a scalar SIUnit and either a scalar SIUnit or a
            % scalar number.  Does what you'd think.
            import ws.utility.objectFunctionUnary
            import ws.utility.objectFunctionBinary            
            if isscalar(arg1),
                if isscalar(arg2) ,
                    result=rdivideScalar(arg1,arg2);
                else
                    result=objectFunctionUnary(@(x)(rdivideScalar(arg1,x)), ...
                                               arg2);
                end
            else
                if isscalar(arg2) ,
                    result=objectFunctionUnary(@(x)(rdivideScalar(x,arg2)), ...
                                               arg1);
                else
                    result=objectFunctionBinary(@rdivideScalar, ...
                                                arg1, ...
                                                arg2);
                end
            end            
        end
        
        %------------------------------------------------------------------
        function result=rdivideScalar(arg1,arg2)
            % Take the quotient of a scalar SIUnit and either a scalar SIUnit or a
            % scalar number.  Does what you'd think.
            import ws.utility.SIUnit
            if isa(arg1,'SIUnit') ,
                if isa(arg2,'SIUnit')
                    result=SIUnit(arg1.Scale-arg2.Scale,arg1.Powers-arg2.Powers);
                else
                    % arg2 better be a number
                    result=SIUnit(arg1.Scale-log10(arg2),arg1.Powers);
                end
            else
                if isa(arg2,'SIUnit')
                    % arg1 better be a number
                    result=SIUnit(log10(arg1)-arg2.Scale,-arg2.Powers);
                else
                    % this shouldn't happen...
                    result=arg1./arg2;
                end
            end
        end
        
        %------------------------------------------------------------------
        function result=invertScalar(unit)
            % Take the reciprocal of a scalar SIUnit.
            import ws.utility.SIUnit
            result=SIUnit(-unit.Scale,-unit.Powers);
        end
        
        %------------------------------------------------------------------
        function result=invert(arg)
            result=ws.utility.objectFunctionUnary(@invertScalar, ...
                                                  arg);
        end
        
        %------------------------------------------------------------------
        function result=powerScalar(unit,p)
            % Take the an SIUnit to a power.
            import ws.utility.SIUnit
            result=SIUnit(p*unit.Scale,p*unit.Powers);
        end
        
        %------------------------------------------------------------------
        function result=power(arg1,arg2)
            import ws.utility.objectFunctionUnary
            import ws.utility.objectFunctionBinary
            if isscalar(arg1) ,
                if isscalar(arg2) ,
                    result=powerScalar(arg1,arg2);
                else
                    result=ws.utility.objectFunctionUnary(@(x)(powerScalar(arg1,x)), ...
                                                             arg2);
                end
            else
                if isscalar(arg2) ,
                    result=ws.utility.objectFunctionUnary(@(x)(powerScalar(x,arg2)), ...
                                                             arg1);
                else
                    result=ws.utility.objectFunctionBinary(@powerScalar, ...
                                                              arg1, ...
                                                              arg2);
                end
            end                        
        end
        
%         %------------------------------------------------------------------
%         function result=saveobjScalar(unit)
%             % Returns a struct that encodes all the internal state of unit.
%             % This struct can be handed to SIUnit.unpickle() to get back
%             % the original unit value.  unit can be a matrix, but not a N-D
%             % array with N>2.
%             
%             scale=unit.Scale;
%             powers=unit.Powers;
%             result=struct('Scale',{scale}, ...
%                           'Powers',{powers});
%         end
         
        %------------------------------------------------------------------
        function result=saveobj(unit)
            % Returns a struct that encodes all the internal state of unit.
            % This struct can be handed to SIUnit.loadobj() to get back
            % the original unit value.  unit can be a matrix, but not a N-D
            % array with N>2.
            
            [m,n]=size(unit);
            scale=cell([m n]);
            powers=cell([m n]);
            string=cell([m n]);            
            for i=1:m ,
                for j=1:n ,
                    scale{i,j}=unit(i,j).Scale;
                    powers{i,j}=unit(i,j).Powers;
                    string{i,j}=unit(i,j).String_;
                end
            end
            result=struct('Scale',scale, ...
                          'Powers',powers, ...
                          'String_',string);
        end
        
%         %------------------------------------------------------------------
%         function result=saveobj(unit)
%             % Returns a struct that encodes all the internal state of unit.
%             % This struct can be handed to SIUnit.loadobj() to get back
%             % the original unit value.  unit can be a matrix, but not a N-D
%             % array with N>2.
%             %
%             % This version returns a cell array with each element a scalar
%             % struct.  Hopefully this is easier to stuff into an HDF5 file.
%             
%             [m,n]=size(unit);
%             result=cell([m n]);
%             for i=1:m ,
%                 for j=1:n ,
%                     scale=unit(i,j).Scale;
%                     powers=unit(i,j).Powers;
%                     thisElement=struct('Scale',scale, ...
%                                        'Powers',powers);
%                     result{i,j}=thisElement;
%                 end
%             end
%         end
        
        %--------------------------------------------------------------------
        function h5save(unit, file, dataset, useCreate)
            % Method to write unit array to an HDF5 file.  Meant to be used with
            % ws.most.fileutil.h5save().
            import ws.utility.SIUnit
            
            if nargin < 4
                useCreate = false;
            end

            if ischar(file)
                if useCreate
                    fileID = H5F.create(file, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
                else
                    fileID = H5F.open(file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
                end
                c = onCleanup(@()H5F.close(fileID));
            else
                fileID = file;
            end
            
            % Define the layout of the SIUnit structure in the file and in
            % memory
            sizeOfDouble=H5T.get_size('H5T_NATIVE_DOUBLE');
            datatypeID = H5T.create('H5T_COMPOUND',sizeOfDouble+sizeOfDouble*SIUnit.NBases);
            H5T.insert(datatypeID,'Scale'    ,  0*sizeOfDouble,'H5T_NATIVE_DOUBLE');
            H5T.insert(datatypeID,'Power_kg' ,  1*sizeOfDouble,'H5T_NATIVE_DOUBLE');
            H5T.insert(datatypeID,'Power_m'  ,  2*sizeOfDouble,'H5T_NATIVE_DOUBLE');
            H5T.insert(datatypeID,'Power_s'  ,  3*sizeOfDouble,'H5T_NATIVE_DOUBLE');
            H5T.insert(datatypeID,'Power_C'  ,  4*sizeOfDouble,'H5T_NATIVE_DOUBLE');
            H5T.insert(datatypeID,'Power_K'  ,  5*sizeOfDouble,'H5T_NATIVE_DOUBLE');
            H5T.insert(datatypeID,'Power_mol',  6*sizeOfDouble,'H5T_NATIVE_DOUBLE');
            H5T.insert(datatypeID,'Power_cd' ,  7*sizeOfDouble,'H5T_NATIVE_DOUBLE');

            unitAsScalarStructWithArrayFields=unit.toH5Struct();

            %ws.most.fileutil.h5savevalue(fileID, dataset, datatypeID, s);
            %function h5savevalue(fileID, dataset, datatypeID, s, dataspaceID, memtype)
            memtype=datatypeID;  % usually 'H5ML_DEFAULT'
            %H5SAVEVALUE Create an H5 dataset and write the s.

            dims=fif(isempty(unit),[1 1],size(unit));

            dataspaceID = H5S.create_simple(2, fliplr(dims), []);

            datasetID = H5D.create(fileID, dataset, datatypeID, dataspaceID, 'H5P_DEFAULT');

            if ~isempty(unit) ,
                H5D.write(datasetID, memtype, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', unitAsScalarStructWithArrayFields);
            end

            H5D.close(datasetID);
            H5S.close(dataspaceID);
            
            H5T.close(datatypeID);
        end  % function

        %--------------------------------------------------------------------
        function s=toH5Struct(unit)
            % The HDF5 library doesn't seem to deal well with structure
            % arrays.  (Or at least I can't get it to work.)  So we encode
            % unit as a scalar structure with array fields.
            import ws.utility.SIUnit
            m=size(unit,1);
            n=size(unit,2);
            s=struct();
            s.Scale=reshape(cell2mat({unit.Scale}),[m n]);
            powers=zeros([m n SIUnit.NBases]);
            for k=1:SIUnit.NBases ,
                for i=1:m ,
                    for j=1:n ,
                        powers(i,j,k)=unit(i,j).Powers(k);  % argh
                    end
                end
            end
            s.Power_kg=powers(:,:,1);
            s.Power_m=powers(:,:,2);
            s.Power_s=powers(:,:,3);
            s.Power_C=powers(:,:,4);
            s.Power_K=powers(:,:,5);
            s.Power_mol=powers(:,:,6);
            s.Power_cd=powers(:,:,7);
        end  % function

%         %--------------------------------------------------------------------
%         function s=toStruct(unit)
%             % This is used during header encoding
%             import ws.utility.structWithDims
%             dims=size(unit);
%             s=ws.utility.structWithDims(dims,{'Scale' 'Power_kg' 'Power_m' 'Power_s' 'Power_C' 'Power_K' 'Power_mol' 'Power_cd'});
%             for i=1:numel(unit) ,
%                 s(i).Scale=unit(i).Scale;
%                 powers=unit(i).Powers;
%                 s(i).Power_kg=powers(1);
%                 s(i).Power_m=powers(2);
%                 s(i).Power_s=powers(3);
%                 s(i).Power_C=powers(4);
%                 s(i).Power_K=powers(5);
%                 s(i).Power_mol=powers(6);
%                 s(i).Power_cd=powers(7);                
%             end
%         end  % function

        %--------------------------------------------------------------------
        function out = eq(self, other)
            out=true(size(self));
            for i=1:numel(self) ,
                out(i)=self(i).eqScalar_(other(i));
            end
        end
        
        %--------------------------------------------------------------------
        function out = eqScalar_(self, other)
            % equality test used when self, other are scalars
            out = (self.Scale==other.Scale) && ...
                  all(self.Powers==other.Powers) ;              
        end
        
        %--------------------------------------------------------------------
        function out = ne(self, other)
            out = ~eq(self,other);
        end
        
        %--------------------------------------------------------------------
        function [newUnit, newValue] = convertToEngineering(unit, value)
            % If value * unit is a dimensioned quantity, returns an equal
            % quantity newValue * newUnit where newUnit's Scale is equal to 
            % 3*n for some integer n, and 1<=newValue<1000.
            if isempty(unit) ,
                newUnit = unit ;
                newValue = value ;
            else
                scale = reshape([unit.Scale],size(unit));
                nPlusY = (scale+log10(value))/3 ;
                n = floor( nPlusY ) ;  % integer
                newScale = 3*n ;  % integer
                %y = nPlusY - n ;            
                %newValue = 10.^(3*y) ;

                scaleChange = newScale-scale ;  % integer
                newValue = value .* 10.^(-scaleChange) ;

%                 newPowers = unit.Powers ;
%                 newUnit = ws.utility.SIUnit(newScale,newPowers) ;
                
                [m,n] = size(unit) ;
                for j=n:-1:1 ,
                    for i=m:-1:1 ,
                        newUnit(i,j) = ws.utility.SIUnit(newScale(i,j),unit(i,j).Powers) ;
                    end
                end
                
            end
        end
        
        
    end  % public methods block
    
    methods
        function value=isequal(self,other)
            % Custom isequal.
            if ~isa(other,class(self)) ,
                value=false;
                return
            end
            dims=size(self);
            if any(dims~=size(other))
                value=false;
                return;
            end
            n=numel(self);
            for i=1:n ,
                if ~isequalElement_(self(i),other(i)) ,
                    value=false;
                    return
                end
            end
            value=true;
        end                            
    end
    
    methods (Access=protected)
       function value=isequalElement_(self,other)
            % The String_ field is not used when testing for value-equality
            % of units
            value = isequal(self.Scale,other.Scale) && isequal(self.Powers,other.Powers) ;
       end
    end
    
    %--------------------------------------------------------------------
    methods (Static=true)
        function unit=loadobj(s)
            % See saveobj().        
            import ws.utility.SIUnit
            [m,n]=size(s);
            unit=SIUnit.empty();
            unit(m,n)=SIUnit();  % dimension
            if isfield(s,'String_') ,  % for backwards-compatibility
                for i=1:numel(s) ,
                    if ischar(s(i).String_) ,
                        unit(i) = SIUnit(s(i).String_);
                    else
                        unit(i) = SIUnit(s(i).Scale,s(i).Powers);
                    end
                end           
            else
                for i=1:numel(s) ,
                    unit(i) = SIUnit(s(i).Scale,s(i).Powers);
                end           
            end
        end  % function

        function [scale,powers] = parseUnitString(str)
            % need to detemine the unit from str, which is assumed
            % to be an abbreviation, or an expression with some *s and
            % /s in there.
            import ws.utility.SIUnit            
            indicesOfStars = strfind(str,'*') ;
            indicesOfSlashes = strfind(str,'/') ;
            indicesOfMarksUnsorted = [indicesOfStars indicesOfSlashes] ;
            nStars = length(indicesOfStars) ;
            nSlashes = length(indicesOfSlashes) ;
            isStarUnsorted = [true(1,nStars) false(1,nSlashes)] ;
            [indicesOfMarks,sortingPermutation] = sort(indicesOfMarksUnsorted) ;
            isStar = isStarUnsorted(sortingPermutation) ;
            
            indicesOfMarksWithInitialAndFinal = [0 indicesOfMarks length(str)+1] ;
            isStarWithInitial = [true isStar] ;
                    
            scale = 0 ;
            powers = zeros(1,ws.utility.SIUnit.NBases) ;
            nParts = length(isStarWithInitial) ;  % guaranteed to be at least one
            for iPart = 1:nParts ,
                indexOfThisMark = indicesOfMarksWithInitialAndFinal(iPart) ;
                isThisMarkAStar = isStarWithInitial(iPart) ;
                indexOfNextMark = indicesOfMarksWithInitialAndFinal(iPart+1) ;
                thisPart = str(indexOfThisMark+1:indexOfNextMark-1);
                [thisScale,thisPowers] = SIUnit.parseSingleAbbreviationStringWithPossibleExponent(thisPart);
                if isThisMarkAStar ,
                    scale = scale + thisScale ;
                    powers = powers + thisPowers ;
                else
                    % this mark is a slash
                    scale = scale - thisScale ;
                    powers = powers - thisPowers ;
                end
            end
        end  % function

        function [scale,powers] = parseSingleAbbreviationStringWithPossibleExponent(str)
            import ws.utility.SIUnit            
            indicesOfCarets = strfind(str,'^') ;
            nCarets = length(indicesOfCarets) ;            
            if nCarets==0 ,
                [scale,powers] = SIUnit.parseSingleAbbreviationString(str) ;
            elseif nCarets==1 ,
                indexOfCaret = indicesOfCarets ;
                n = length(str) ;
                if indexOfCaret==1 ,
                    error('SIUnits:badConstructorArgs','There seems to be an exponent with no base');
                end
                if indexOfCaret==n ,               
                    error('SIUnits:badConstructorArgs','There seems to be a base with a missing exponent');
                end
                baseString = str(1:indexOfCaret-1);
                exponentString = str(indexOfCaret+1:n);
                [baseScale,basePowers] = SIUnit.parseSingleAbbreviationString(baseString) ;
                exponent=str2double(exponentString) ;
                if isfinite(exponent) 
                    if round(exponent)==exponent ,
                        scale = baseScale * exponent ;
                        powers = exponent * basePowers ;
                    else
                        error('SIUnits:badConstructorArgs','Exponents must be integers');
                    end
                else
                    error('SIUnits:badConstructorArgs','Invalid exponent');                    
                end
            else
                error('SIUnits:badConstructorArgs','Can''t have two carets in a single factor');  
            end
        end  % function
        
        function [scale,powers] = parseSingleAbbreviationString(str)
            % need to detemine the unit from str, which is assumed
            % to be an abbreviation, or an expression with some *s and
            % /s in there.
            import ws.utility.SIUnit            
            nStems=length(ws.utility.SIUnit.Stems);
            bestMatchLength=0;
            for i=1:nStems
                thisAbbrev=SIUnit.Stems{i};
                if length(str)>=length(thisAbbrev) && strcmp(thisAbbrev,str(end-length(thisAbbrev)+1:end)) ,
                    if length(thisAbbrev)>bestMatchLength ,
                        bestMatchLength=length(thisAbbrev);
                        iBest=i;
                    end
                end
            end
            if bestMatchLength==0 , 
                error('SIUnits:badConstructorArgs','Unknown unit string');  
            else
                powers=SIUnit.StemsPowers(iBest,:);
                thisPrefix=str(1:end-length(SIUnit.Stems{iBest}));
            end
            scaleThis=SIUnit.PrefixScales(strcmp(SIUnit.Prefixes,thisPrefix));
            if isempty(scaleThis) ,
                error('SIUnits:badConstructorArgs','Unknown prefix string'); 
            else
                scale=scaleThis;
            end
        end  % function
        
    end  % static methods
    
end
