function rgbImage = readPNGWithTransparencyForUIControlImage(fileName)
    % Reads a PNG image in, and does some hocus-pocus so that the transparency works
    % right.  Returns an image suitable for setting as the value of a
    % uicontrol CData property.
    [indexedImage, lut] = imread(fileName);
    isLutEntryAllZeros = all(lut==0,2) ;
    lut(isLutEntryAllZeros,:) = NaN;  % This is interpreted as transparent, apparently
    rgbImage = ind2rgb(indexedImage, lut);                          
end
