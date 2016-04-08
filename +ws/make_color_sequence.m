function color_sequence = make_color_sequence()

% this creates a sequence of colors to be used for traces
% the sequence is specified in the HSV colorspace
% all traces have the same satuaration and brightness
% the hue sequence is determined by taking 256 evenly spaced samples
%   from 0 to 1, and then shuffling them in such a way that each
%   hue gets mapped to the 'bit-reversed' hue.
% This means that subsequent colors tend to be far apart in hue, 
%   which is the desired effect.
n_colors=256;
saturation=1;
brightness=0.7;
indices=uint8((0:(n_colors-1))');
for j=1:n_colors
  indices(j)=ws.bit_reverse(indices(j));
end
color_sequence_hsv=...
  [ double(indices)/n_colors ...
    repmat(saturation,[n_colors 1]) ...
    repmat(brightness,[n_colors 1]) ];  %#ok<RPMT1>
color_sequence=hsv2rgb(color_sequence_hsv);

% let's see the colors
%figure;
%colormap(color_sequence);
%colorbar;
