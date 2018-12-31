function result = deleteColumns(A, indices)
    result = A ;
    result(:, indices) = [] ;
end
