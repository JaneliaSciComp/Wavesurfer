function untimedDO(self,evt)

self.Stimulation.setUntimedDigitalOutputState(1, ...
    mod(self.ExperimentCompletedTrialCount,2));