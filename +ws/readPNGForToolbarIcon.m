function cdata=readPNGForToolbarIcon(fileName)
    [cdata,map,alpha]=imread(fileName);
    if isempty(map) ,
        % image is truecolor
        if isa(cdata,'uint8')
            cdata=double(cdata)/255;
        end
    else
        % image is indexed
        cdata=ind2rgb(cdata,map);
    end
    % cdata is now RGB, nxmx3, with values on [0,1]
    if isempty(alpha) ,
        % do nothing
    else
        % zero out the transparent parts
        isForeground=(alpha>0);
        mask=nan(size(isForeground));
        mask(isForeground)=1;
        cdata=bsxfun(@times,mask,cdata);
    end
end
