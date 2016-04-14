function value=fif(test,trueValue,falseValue)
  % A handy function, like C's ?: operator 
  % Of course, in this version both trueValue and falseValue get evaluated,
  % so don't use if either will take a long time.
  if isscalar(test) ,
      % This is so fif(true,'true','false') yields 'true', for instance
      if test ,
          value=trueValue;
      else
          value=falseValue;
      end
  else
      % This is so we can use fif() when all args have the same size().
      value=trueValue;
      value(~test)=falseValue(~test);
  end
end
