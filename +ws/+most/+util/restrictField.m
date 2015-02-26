function snew = restrictField(s,flds)
% snew = restrictField(s,flds)
% Restrict fields of structure s to those in the cellstr flds. The fields
% of snew are the intersection of the fields of s and flds.

assert(isstruct(s));
assert(iscellstr(flds));

fldsToRemove = setdiff(fieldnames(s),flds);
snew = rmfield(s,fldsToRemove);

end