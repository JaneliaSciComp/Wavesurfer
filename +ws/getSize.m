function [w,h]=getSize(gh)
    position=get(gh,'Position');
    w=position(3);
    h=position(4);
end
