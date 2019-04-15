function destination = copy(source)
    %other = self.copyGivenParent([]) ;
    className = class(source) ;
    destination = feval(className) ;  % class must have a zero-arg constructor
    destination.mimic(source) ;
end  % function
