function recycleFile(filename)
%RECYCLEFILE Recycles, rather than deletes, specified filename

status = recycle;
recycle on;
delete(filename);
recycle(status);

end

