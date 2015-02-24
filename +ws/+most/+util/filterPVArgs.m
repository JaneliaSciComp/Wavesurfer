function [filteredPVArgs,otherPVArgs] = filterPVArgs(argList,validProps, mandatoryProps)
%Filter out particular property-value pairs from supplied argList of property-value pairs
%% SYNTAX
%[filteredPVArgs,otherPVArgs] = filterPVArgs(argList, validProps, mandatoryProps)
%   validProps: Cell array list of properties to extract from argList
%   mandatoryProps: <Optional> Cell array list specifying subset of validProps which are mandatory; if they are not found in argList, an error is thrown.
%
%   filteredPVArgs: Cell array of selected property-value pairs
%   otherPVArgs: Cell arrray of remaining (unselectd) property-value pairs
%
%% NOTES
%   TODO: Further error checking!
%   TODO: Eliminate the otherPVArgs output arg
%   
%   TMW: This method passes back the arguments for caller function to do the setting, since in many cases (private or protected properties) it's not possible to set the properties from within this function.
%
%% CREDITS
%   Created 5/11/11, by Vijay Iyer
%% **********************************************

if nargin < 3
    mandatoryProps = {};
else
    assert(isempty(setdiff(mandatoryProps,validProps)), 'Argument ''mandatoryProps'' must be a subset of the argument ''validProps''');
end


%Verify that 
try
    assert(rem(length(argList),2)==0 && iscellstr(argList(1:2:end)), 'Specified arguments failed to conform to expected property-value pair format');
    
    %Extract constructor properties (and the mandatory subset) from supplied argument list
    foundMandatoryProps = intersect(argList(1:2:end), mandatoryProps);    
        
    %Determine if there are any missing mandatory properties
    missingMandatoryProps= setdiff(mandatoryProps,foundMandatoryProps);
    if ~isempty(missingMandatoryProps)
        error('The following required property/value pairs was expected, but not supplied: %s', missingMandatoryProps{1}); %TODO: Find way to (elegantly) display all missing props
    end
catch ME
    ME.throwAsCaller();
end

%Extract and sort valid properties
[validProps,ia,ip] = intersect(argList(1:2:end), validProps); %ia=indices into arg list; ip=indices into valid property list

[~,sortOrder] = sort(ip);
validProps = validProps(sortOrder);
validPropIndices = ia(sortOrder);

%Output the 'filtered' PV args
filteredPVArgs = cell(1,2*length(validProps));
if ~isempty(validProps)
    filteredPVArgs(1:2:end) = validProps;
    filteredPVArgs(2:2:end) = argList(2*validPropIndices);    
else
    filteredPVArgs = {};
end

otherPVArgs = argList;

end



