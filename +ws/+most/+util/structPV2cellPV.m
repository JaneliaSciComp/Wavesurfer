function cellpv = structPV2cellPV(structpv)

flds = fieldnames(structpv);
vals = struct2cell(structpv);

cellpv = [flds(:)'; vals(:)'];
cellpv = cellpv(:);

end