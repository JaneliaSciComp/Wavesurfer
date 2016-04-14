function result=objectArray(className,dims,varargin)
   % Creates an array of objects of class className, calling the class
   % constructor once for each element.  The resulting array has a size
   % equal to dims (except for a few special cases, see below).  If additional 
   % arguments are passed in, they are passed to each invocation of the
   % class constructor.  If one or more elements of dims is zero, the
   % class's empty() method will be called to produce an empty array with
   % size matching dims.
   %
   % This function is useful for constucting object arrays in a less clumsy
   % way than the way inherently supported by Matlab, especially when one
   % would like to pass arguments to the constructor for each element.
   % Additionally, the guarantee that the constructor is called once per
   % element is often useful and desirable, especially when the constructor 
   % allocates hardware resources.
   if isempty(dims) ,
       result=feval(className,varargin{:});  % return a scalar instance
   else
       nLast=dims(end);
       if nLast==0 ,
           % Special case for dealing with a dimension of size 0
           emptyFunctionName=sprintf('%s.empty',className);
           if isscalar(dims) && dims==0 ,
               dims=[0 1];  % Keep consistent with matlab conventions when dims is [0]
           end
           result=feval(emptyFunctionName,dims);
       else
           % the normal case, where we recurse and then use cat to
           % construct the result.
           allButLastDimensions=dims(1:end-1);
           subResults=cell(1,nLast);
           for i=1:nLast ,
               subResults{i}=ws.objectArray(className,allButLastDimensions,varargin{:});
           end
           result=cat(length(dims),subResults{:});
       end
   end
end
