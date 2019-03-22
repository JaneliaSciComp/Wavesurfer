function result = renameInCellString(cellString, oldString, newString)
    isMatch = strcmp(cellString, oldString) ;
    result = cellString ;
    result(isMatch) = {newString} ;
end
