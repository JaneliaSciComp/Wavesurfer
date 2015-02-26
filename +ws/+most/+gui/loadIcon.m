function icon = loadIcon(filename,outputSize,rotation,color)
% LOADICON Reads a BMP and returns an icon with the appropriate
% system-dependent background color, formatted for use as 'CData'.
%
% NOTE: the BMP is assumed to be a binary image--white pixels will be set to the system-depenedent background color.
%
% filename: the filename of the BMP to read.
% size: an integer value indicating the size of the output icon (NOTE: icon is assumed to be square.)
% rotation: an optional integer argument specifying the number of degrees to rotate the icon. (NOTE: rotation is assumed to have a value that is a multiple of 90.)
% color: optionally specifies the foreground color to use for the icon.

    if nargin < 4 || isempty(color) || length(color) ~= 3
        color = [0 0 0]; 
    end

    if nargin < 3 || isempty(rotation)
        rotation = 0;
    end

    bg = get(0,'defaultUIControlBackgroundColor');
    
    iconData = double(imread(filename,'bmp'))./255;
    
    if nargin < 2 || isempty(outputSize)
        outputSize = size(iconData,1);
    end

    if outputSize ~= size(iconData,1)
        doResize = true;
        icon = zeros(outputSize,outputSize,size(iconData,3));
    else
        doResize = false;
        icon = zeros(size(iconData));
    end
    
    for i = 1:size(iconData,3)
        channelData = rot90(iconData(:,:,i).*bg(i),-rotation/90);
        
        if doResize
            channelData = ws.most.util.matResize(channelData,[16 16]);
            
            % thresholds to ensure that we have a binary image, and valid CData, after scaling...
            channelData(channelData < 0.7) = color(i);            
            channelData(channelData > 1.0) = 1.0;
        end

        icon(:,:,i) = channelData;
    end
end
