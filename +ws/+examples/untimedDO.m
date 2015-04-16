function untimedDO(wsModel,event)  %#ok<INUSD>
    % This is an example user function, intended to be a "Trial Start" user
    % function.  It flips the first DO channel back and forth between high and low
    % from trial to trial.
    wsModel.Stimulation.setDigitalOutputStateIfUntimed(1, ...
        mod(wsModel.ExperimentCompletedTrialCount,2));
end
