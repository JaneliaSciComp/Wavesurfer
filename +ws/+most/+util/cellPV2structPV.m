function structpv = cellPV2structPV(cellpv)

if iscell(cellpv) && isempty(cellpv)
    structpv = struct();
    return;
end
   
assert(iscell(cellpv) && isvector(cellpv) && ~rem(numel(cellpv),2),'Invalid PV cell array');


flds = cellpv(1:2:end);
vals = cellpv(2:2:end);

assert(iscellstr(flds),'Invalid PV cell array');

structpv = struct();
for i=1:length(flds)
    structpv.(flds{i}) = vals{i};
end

end