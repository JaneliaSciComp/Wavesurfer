function [rotation, cumulative_rotation, d_forward, barpos, arena_on] = analyzeFlyLocomotion_ (data)

% This function quantifies the locomotor activity of the fly and exports
% the key parameters used by the subsequent functions.
% It also creates a figure that allows the on-line control of the
% closed-loop feedback. This figure can be overwritten for every new sweep.


%% a few constants for the conversion of the ball tracker readout to locomotor metrics 

%calibration data from 151112

mmperpix_r=0.0314; %mm per pixel of rear camera
dball=8; %ball diameter in mm
c_factors=[1.1 0.96]; %this many pixel of rear camera correspond to 1 pixel of Cam1/2 (=pix_c/pix_rear)
mmperpix_c=mmperpix_r.*c_factors; %this many mm ball displacement correspond to 1 pixel of treadmill cameras 
degrpermmball=360/(pi*dball); %pi*dball=Cball==360°

panorama=240; %panorama width in degrees, important for comparing cumulative rotation to arena signal

arena_range=[0.1754  8.7546 8.93]; %this is the output range of the LED arena that reports the bar position
%values are true for the new(correct) wavesurfer AD conversion

%% calculate fly locomotion parameters from camera output

% downsample the camera data to 4 kHz, conversion: 20kHz/4kHz=5
n=floor(length(data)/5); % length of 4 kHz data to be generated from 20 kHz wavesurfer acquisition
inp=data(1:n*5,5:8); % cut data to appropriate length


% digitize the camera data by removing offset and dividing by step amplitude

inp_dig=round((inp-2.33)/0.14); %this is with the OLD wavesurfer AD conversion
% inp_dig=round((inp-2.51)/0.14); %this is with the NEW wavesurfer AD conversion

inp_4kHz=zeros(n,4);

for i=1:4
    inp_4kHz(:,i)=sum(reshape(inp_dig(:,i),5,[]))/80; %divide by 80 to correct for pulse frequency and duration
end

%displacement of the fly as computed from ball tracker readout in mm
d_forward = (inp_4kHz(:,2)*mmperpix_c(1) + inp_4kHz(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1+y2
d_side = (inp_4kHz(:,2)*mmperpix_c(1) - inp_4kHz(:,4)*mmperpix_c(2))*sqrt(2)/2; %y1-y2
d_rot =(inp_4kHz(:,1)*mmperpix_c(1) + inp_4kHz(:,3)*mmperpix_c(2))/2; %x1+x2

%translate rotation to degrees
rotation=d_rot*degrpermmball;

%calculate cumulative rotation
cumulative_rotation=cumsum(rotation)/panorama*2*pi; % cumulative rotation in panorama normalized radians

barpos=circ_mean(reshape(data(1:n*5,3),5,[])/arena_range(2)*2*pi)'; %downsampled to match with LocomotionData at 4kHz, converted to a signal ranging from -pi to pi


%% plot arena vs ball rotation, calculate gain
% This figure can be overwritten for every new sweep.

arena_cond={'arena is on', 'arena is off'};

arena_on=data(1,4)>7.5; %arena on will report output of ~9V, arena off ~4V

gain=mean(unwrap(barpos(1:12000)-mean(barpos(1:12000)))./(cumulative_rotation(1:12000)-mean(cumulative_rotation(1:12000))));

t=1/4000:1/4000:1/4000*length(cumulative_rotation);

figure 
plot(t,cumulative_rotation-mean(cumulative_rotation(1:12000))) %in rad, 240° stretched to 360°
hold on
plot(t,unwrap(barpos)-mean(barpos(1:12000)),'-g') %in rad, spanning 2pi
legend({'fly','bar'})
title(arena_cond(arena_on+1))
ylabel(['gain: ' num2str(gain)])

barpos(barpos<0)=barpos(barpos<0)+2*pi;
end