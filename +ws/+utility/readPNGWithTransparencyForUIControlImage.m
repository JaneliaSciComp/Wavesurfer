function cdata = readPNGWithTransparencyForUIControlImage(fileName)
    % Reads a PNG image in, and does some hocus-pocus so that the transparency works
    % right.  Returns an image suitable for setting as the value of a
    % uicontrol CData property.
    [cdata, map] = imread(fileName);
    map(map(:,1)+map(:,2)+map(:,3)==0) = NaN;
    cdata = ind2rgb(cdata, map);                          
end
