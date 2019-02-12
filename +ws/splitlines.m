function result = splitlines(lines_as_string)
    newline_indices = strfind(lines_as_string, sprintf('\n')) ;
    newline_indices = [newline_indices length(lines_as_string)+1] ;  % a useful fiction: pretend there's a newline just past end of lines_as_string
    line_count = length(newline_indices) ;
    index_of_newline_for_last_line = 0 ;  % again, a useful fiction
    result = cell(line_count,1) ;
    for i = 1:line_count ,
        index_of_newline_for_this_line = newline_indices(i) ;
        result{i} = lines_as_string(index_of_newline_for_last_line+1:index_of_newline_for_this_line-1) ;
        index_of_newline_for_last_line = index_of_newline_for_this_line ;
    end
end
