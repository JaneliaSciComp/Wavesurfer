%% analyze Fly Locomotion
% This function quantifies the locomotor activity of the fly and exports
% the key parameters used by the subsequent functions.
% It also creates a figure that allows the on-line control of the
% closed-loop feedback. This figure can be overwritten for every new sweep.
k=1;
[rotation, cumulative_rotation, d_forward, BarPosition, arena_on] = analyzeFlyLocomotion_ (data); 
%rotation is in [°], cumulative_rotation in [rad] (with 240° being 2pi)

%% visualize coverage of azimuthal headings by the fly
%this figure should contain the accumulated data of ALL previous sweeps from a given setpoint up until now
 
figure;
[count,barpos_x] = hist(BarPosition,16);
plot(barpos_x,count/4000); %plots residency in s vs barpos
xlabel('bar position [rad]')
ylabel('time [s]')
xlim([0 2*pi])

%% give Vm and spike rate in 50 ms bins

Vm=quantifyCellularResponse_(data); %so far only exports Vm, might want to export spike rate too

%% make Heat Map of fly's rotational velocity tuning
%this figure should contain the accumulated data of ALL previous sweeps from a given setpoint up until now

HeatMap_(Vm,rotation,d_forward,BarPosition,arena_on)


%% trigger open loop bar movement whenever fly is in a certain virtual position

% this would have to be running throughout a continuous acquisition trial

% 1: have user input Bar positions (quadrant 1 to 16) that are currently
% undersampled
% 2: whenever the fly is within 60° of those user-defined positions (<5 quadrants away),
% trigger stimulus protocol "arena control"
% 3: allow protocol being triggered at most once every 60s


%% trigger LED stimulation for 20s when the fly starts walking

% this would have to be running throughout a continuous acquisition trial

% 1: calculate d_forward on the fly
% 2: if d_fw > 0, trigger stimulus protocol "blue LED" in 50% of those trials (randomized or interleaved, not sure yet what's best)
