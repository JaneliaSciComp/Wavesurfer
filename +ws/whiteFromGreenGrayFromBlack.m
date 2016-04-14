function out = whiteFromGreenGrayFromBlack(im)
    % Leaves nans alone, to preserve
    % transparency in some settings.
    
    [nRows,nCols,~] = size(im) ;
    greenChannel = im(:,:,2) ;
    isGreen = (greenChannel>0.5) ;    
    isBlack = all(im<0.01,3) ;  % turns out black is not really black in the icons I use this function on
    out = zeros(nRows,nCols,3) ;    
    for j = 1:nCols ,
        for i = 1:nRows ,
            if isBlack(i,j) ,
                out(i,j,1) = 0.5 ;
                out(i,j,2) = 0.5 ;
                out(i,j,3) = 0.5 ;
            elseif isGreen(i,j) ,
                out(i,j,1) = 1 ;
                out(i,j,2) = 1 ;
                out(i,j,3) = 1 ;
            else
                out(i,j,1) = im(i,j,1) ;
                out(i,j,2) = im(i,j,2) ;
                out(i,j,3) = im(i,j,3) ;
            end
        end
    end
end
