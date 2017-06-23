function touch(fileName)
    fid = fopen(fileName, 'wt') ;
    if fid<0 ,
        error('Unable to open %s for writing', fileName) ;
    end
    fclose(fid) ;
end
