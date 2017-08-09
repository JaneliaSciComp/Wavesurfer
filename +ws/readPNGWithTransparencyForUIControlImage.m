function rgbImage = readPNGWithTransparencyForUIControlImage(fileName)
    % Reads a PNG image in, and does some hocus-pocus so that the transparency works
    % right.  Returns an image suitable for setting as the value of a
    % uicontrol CData property.
    [rawImage, lut] = imread(fileName);
    if ndims(rawImage)==3 ,
        % Means a true-color image.  We use the convention that white==background
        image = double(rawImage)/255 ;  % convert form uint8 to default matlab RGB image
        isBackground = all(image==1,3) ;  % all-white pels are taken as background, make pel slightly off-white if you want white
        isBackgroundFull = repmat(isBackground, [1 1 3]) ;
        rgbImage = ws.replace(image, isBackgroundFull, nan) ;
        %rgbImage = image ;
        %rgbImage(isBackgroundFull) = NaN ;
    else
        % Indexed RGB.  For these, use older convention where all-black is taken as background.
        % (Can use very very dark gray if need black pels.)
        isLutEntryAllZeros = all(lut==0,2) ;
        lut(isLutEntryAllZeros,:) = NaN;  % This is interpreted as transparent, apparently
        rgbImage = ind2rgb(rawImage, lut);                          
    end
end
