classdef PlotLastTrial < ws.UserClass

    % This (rather useless) user object plots the the first AI channel at
    % the end of each trial.  It exists mainly to demonstrate how a user
    % object might get the analog input traces out of the Wavesurfer model
    % object.
    
    % Information that you want to stick around between calls to the
    % functions below
    properties
    end  % properties

    properties (Access=protected, Transient=true)
        Figure_
        Axes_
        Line_
    end
    
    methods
        
        function self = PlotLastTrial(wsModel)
            % creates the "user object"
        end
        
        function experimentWillStart(self,wsModel,eventName)
            % Called just before each set of trials (a.k.a. each
            % "experiment")
            
            % Create a figure if needed
            if isempty(self.Figure_) || ~ishghandle(self.Figure_) ,            
                self.Figure_ = figure('Color','w');
                self.Axes_ = [] ;
                self.Line_ = [] ;
            end

            % Create an axes if needed
            if isempty(self.Axes_) || ~ishghandle(self.Axes_) ,            
                self.Axes_  = axes('Parent',self.Figure_);
                self.Line_ = [] ;                
            end

            % If the plot line does not exist (or is invalid), create it.
            if isempty(self.Line_) || ~ishghandle(self.Line_) ,            
                self.Line_ = line('Parent',self.Axes_,'Color','k');
            end                        
        end  % function
        
        function trialWillStart(self,wsModel,eventName)
            % Called just before each trial
        end
        
        function trialDidComplete(self,wsModel,eventName)
            % Called after each trial completes
            
            fs = wsModel.Acquisition.SampleRate ;  % Hz
            data = wsModel.Acquisition.getAnalogDataFromCache() ;  % Data for all the input channels, one channel per column
            y = data(:,1) ;  % Extract the first analog input channel
            n = length(y) ;
            t = (1/fs) * (0:(n-1))' ;  % Make a time line
            if ishghandle(self.Line_) ,  % protects us if the figure gets closed
                set(self.Line_,'XData',t,'YData',y);
            end
        end  % function
        
        function trialDidAbort(self,wsModel,eventName)
            % Called if a trial goes wrong
        end        
        
        function experimentDidComplete(self,wsModel,eventName)
            % Called just after each set of trials (a.k.a. each
            % "experiment")
        end
        
        function experimentDidAbort(self,wsModel,eventName)
            % Called if a trial set goes wrong, after the call to
            % trialDidAbort()
        end
        
        function dataIsAvailable(self,wsModel,eventName)
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % is read from the DAQ board.
        end
        
    end  % methods
    
end  % classdef
