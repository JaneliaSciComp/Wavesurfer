function [w,h]=getExtent(gh)
    rawExtent=get(gh,'Extent');
    w=rawExtent(3);
    h=rawExtent(4);
end
