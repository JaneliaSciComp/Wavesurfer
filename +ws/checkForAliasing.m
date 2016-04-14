function [isAliasing,pathOfAliasing]=checkForAliasing(thing1,thing2)
    pathSoFarInitial='';
    [isAliasing,pathOfAliasing]=checkForAliasingHelper(thing1,thing2,pathSoFarInitial);
end



function [isAliasing,pathOfAliasing]=checkForAliasingHelper(thing1,thing2,pathSoFar)
    if (isa(thing1,'handle') || isstruct(thing1)) && (isa(thing2,'handle') || isstruct(thing2)) ,
        % we assume both things are scalar...
        if isa(thing1,'handle') && isa(thing2,'handle') ,
            if (thing1==thing2) ,
                isAliasing=true;
                pathOfAliasing=pathSoFar;
                return
            else
                % check common slots for aliasing
                [isAliasing,pathOfAliasing]=checkSlotsForAliasing(thing1,thing2,pathSoFar);
            end
        else
            % check common slots for aliasing
            [isAliasing,pathOfAliasing]=checkSlotsForAliasing(thing1,thing2,pathSoFar);
        end
    elseif iscell(thing1) && iscell(thing2) ,
        % Check the elements they have in common
        size1=size(thing1);
        size2=size(thing2);
        commonSize=min(size1,size2);
        isAliasing=false;  % fallback in case prod(commonSize)==0
        pathOfAliasing='';  % fallback in case prod(commonSize)==0
        for i=1:commonSize(1) ,
            for j=1:commonSize(2) ,
                pathThis=sprintf('%s{%d,%d}',pathSoFar,i,j);
                [isAliasing,pathOfAliasing]=checkForAliasingHelper(thing1{i,j},thing2{i,j},pathThis);
                if isAliasing ,
                    return
                end
            end
        end
    else
        % must be a value type, so no aliasing possible, or two
        % incommensurate things...
        thing1
        isAliasing=false;
        pathOfAliasing='';
    end
end



function [isAliasing,pathOfAliasing]=checkSlotsForAliasing(thing1,thing2,pathSoFar)
    slotNames1=slotNames(thing1);
    slotNames2=slotNames(thing2);
    commonSlotNames=intersect(slotNames1,slotNames2);
    commonSlotNamesEdited=setdiff(commonSlotNames,{'Parent' 'Parent_'});
    for i=1:length(commonSlotNamesEdited) ,
        slotName=commonSlotNamesEdited{i};
        slot1=thing1.(slotName);
        slot2=thing2.(slotName);        
        pathThis=sprintf('%s.%s',pathSoFar,slotName);
        [isAliasing,pathOfAliasing]=checkForAliasingHelper(slot1,slot2,pathThis);
        if isAliasing ,
            return
        end        
    end    
end



function names=slotNames(thing)
    if isstruct(thing) ,
        names=fieldnames(thing);
    elseif isa(thing,'handle') ,
        names=properties(thing);
    else
        names=cell(0,1);
    end
end

