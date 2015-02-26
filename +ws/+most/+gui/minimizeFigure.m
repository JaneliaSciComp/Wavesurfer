function minimizeFigure(hFig)
%MINIMIZEFIGURE Minimize figure window
%
%   hFig: A handle-graphics figure object handle
%
% NOTES
%  Use trick given on Yair Altman's Undocumented Matlab site to minimize
%  figure. Amazingly, this functionality is not provided by TMW.


hFrame = get(hFig,'JavaFrame');
hFrame.setMinimized(true);