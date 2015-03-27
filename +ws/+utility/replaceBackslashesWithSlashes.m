function result = replaceBackslashesWithSlashes(string)
    if ischar(string) && (isempty(string) || isrow(string)) ,
        isBackslash = (string=='\');
        result=string;
        result(isBackslash)='/';
    else
        result=string;
    end
end

