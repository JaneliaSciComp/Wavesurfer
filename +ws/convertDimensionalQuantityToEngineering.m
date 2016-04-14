function [newUnit, newValue] = convertDimensionalQuantityToEngineering(unit, value)
    sz = size(unit) ;
    newUnit = cell(sz) ;
    newValue = zeros(sz) ;
    for i=1:numel(unit) ,
        [newUnitThis, newValueThis] = ws.convertScalarDimensionalQuantityToEngineering(unit{i}, value(i)) ;
        newUnit{i} = newUnitThis ;
        newValue(i) = newValueThis ;
    end
end