function s = array2Str(a)
%ARRAY2STR - Converts an array into a single line string encoding.
%
% Created: Timothy O'Connor 2/25/04
% Copyright: Cold Spring Harbor Laboratories/Howard Hughes Medical Institute 2004
% 
% SYNTAX
%     s = array2Str(a)
%     
% ARGUMENTS
%     a - Any n-dimensional array.
%
% RETURNS
%     s - A single-line string representing the properly shaped array.
%         Scalars are returned as string representations of scalars.
%     
% DESCRIPTION
%  The encoding algorithm works as follows:
%     b = size(a);
%     s = strcat(mat2str(b), '&', mat2str(reshape(a, [1 prod(b)]), 17))
%
%  The encoded string appears as two Matlab style array specifications,
%  such that calling `eval` on them will result in arrays. The two
%  arrays are separated by an ampersand ('&').
%
%  The string may be decoded in the following way: 
%     [bs s] = strtok(s, '&');
%     as = strtok(s, '&');
%     a = reshape(str2num(as), str2num(bs));
%
% EXAMPLES
%     a = zeros(2, 2, 2);
%     a(1, :, :) = magic(2);
%     a(2, :, :) = magic(2);
%     s = ndArray2Str(a)
%     s =
%         [2 2 2]&[1 1 4 4 3 3 2 2]
%
% PROGRAMMER_NOTE
%   Watch out for the 'precision' field on the call to mat2str.
%
%  Changed:
%          3/6/04 Tim O'Connor (TO030604c): Return [] for empty values.
%          3/6/04 Tim O'Connor (TO030504d): Upcast types that aren't supported for stringification.
%           
% See Also NDARRAYFROMSTR, RESHAPE, MAT2STR, STR2NUM

if ~isnumeric(a) && ~islogical(a) 
    error('MATLAB:badopt', 'Input to ndArray2Str must be numeric or logical.');
end

if isempty(a)
    s = '[]';
    return;
end

if numel(a)==1
    s = num2str(a);
    return;
end

b = size(a);

%Encode a string, such that the size preceeds the data, and they're separated by '&'.
%Use 20 digits, since 2^64 ~ 10^19.
%TO102004a - Change the precision to 16 digits, as this is the 'chosen' Matlab precision and lends itself
%to far more manageable strings, with fewer approximations. This may require rethinking, in the future though.
%The string's aesthetic benefits really pay off in GUI edit boxes.
s = strcat(mat2str(b), '&', mat2str(a(:)', 16));

return;