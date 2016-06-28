function HeatMap_ (Vm,rotation,d_forward,BarPosition,arena_on)
%make firing rate heat maps

% This function assumes a default responselag of 150 ms
% It would be nice to be able to change the following two parameters through a window or the
% command line

binsize=0.050; %(s)
turnlag = 3; % (nr of bins), temporal shift of rotational velocity with respect to cellular response

sf2=4000; %(Hz) motiondata acquisition frequency

binsize_m=binsize*sf2; %binsize in motiondata indices

%calculate mean of locomotor parameters over bins
TrialLength_m=length(rotation);
NrOfBins=floor(TrialLength_m/binsize_m); 
Length_m=NrOfBins*binsize_m;
rotation=mean(reshape(rotation(1:Length_m),binsize_m,NrOfBins))*sf2; %rad/s
d_forward=mean(reshape(d_forward(1:Length_m),binsize_m,NrOfBins))*sf2; %mm/s


%% make heat map for rotational vs forward velocity

Vm=Vm(turnlag+1:end);
rotation=rotation(1:end-turnlag);
d_forward=d_forward(turnlag+1:end);

rot_axis=[-600:20:600];
fw_axis=[-20:40];
[~,rot_idx]=histc(rotation,rot_axis);
[~,fw_idx]=histc(d_forward,fw_axis); fw_idx=length(fw_axis)-1-fw_idx;

HeatMatrix_fw=nan(length(fw_axis)-1,length(rot_axis)-1);

ii_x=unique(rot_idx);
k_x=unique(fw_idx);

for ii=1:length(ii_x)
    for k=1:length(k_x)
       HeatMatrix_fw(k_x(k),ii_x(ii))=mean(Vm(fw_idx==k_x(k)&rot_idx==ii_x(ii))); 
    end
end

% plot HeatMap, make NaN values white

figure; 
colormap(jet)
colordata =colormap;
maxvalVm = max(HeatMatrix_fw(:)); colordata(end,:) = [1 1 1]; 
HeatMatrix_fw(isnan(HeatMatrix_fw)) = maxvalVm + abs(maxvalVm)/10; %trick: customize your colormap such that the largest value of your data is painted white

imagesc(HeatMatrix_fw,[min(HeatMatrix_fw(:)) max(HeatMatrix_fw(:))])
colormap(colordata);
c=colorbar;
set(gca,'xTick',[0.5:5:length(rot_axis)],'xTickLabel',[rot_axis(1):5*diff(rot_axis([1,2])):rot_axis(end)],'yTick',[0.5:5:length(fw_axis)],'yTickLabel',[fw_axis(end):-5*diff(fw_axis([1,2])):fw_axis(1)])
xlim([min(ii_x) max(ii_x)])
ylim([min(k_x) max(k_x)])
xlabel('v_r_o_t [°/s]')
ylabel('v_f_w [mm/s]')
ylabel(c,'Vm [mV]')


%% make heat map for rotational velocity vs heading if arena is on

if arena_on==1
    BarPosition=circ_mean_(reshape(BarPosition(1:Length_m),binsize_m,NrOfBins)); %rad azimuth
    BarPosition=BarPosition(turnlag+1:end); %no time shift, just like for fw vel
    BarPosition(BarPosition<0)=BarPosition(BarPosition<0)+2*pi;
    
    rot_axis=[-600:25:600];
    heading_axis=linspace(-0.001, max([BarPosition,2*pi+0.001])+0.001,9); %rad
    [~,rot_idx]=histc(rotation,rot_axis);
    [~,heading_idx]=histc(BarPosition,heading_axis);
    
    HeatMatrix_pos=nan(length(heading_axis)-1,length(rot_axis)-1);
    
    ii_x=unique(rot_idx);
    k_x=unique(heading_idx);
    
    for ii=1:length(ii_x)
        for k=1:length(k_x)
              HeatMatrix_pos(k_x(k),ii_x(ii))=mean(Vm(heading_idx==k_x(k)&rot_idx==ii_x(ii))); 
        end
    end
     % for making NaN values white

    colordata_heading = colormap;
    maxvalVm = max(HeatMatrix_pos(:)); colordata_heading(end,:) = [1 1 1]; 
    HeatMatrix_pos(isnan(HeatMatrix_pos)) = maxvalVm + abs(maxvalVm)/10; %trick: customize your colormap such that the largest value of your data is painted white
    
    figure; imagesc(HeatMatrix_pos,[min(HeatMatrix_pos(:)) max(HeatMatrix_pos(:))])
    colormap(colordata_heading);
    c=colorbar;  
    axis tight
    set(gca,'xTick',[11.5:6:length(rot_axis)-12],'xTickLabel',[rot_axis(13):6*diff(rot_axis([1,2])):rot_axis(end-12)],'yTick',[0.5 length(heading_axis)/2 length(heading_axis)-0.5],'yTickLabel',{'0' 'pi' '2pi'})
    xlim([min(ii_x) max(ii_x)])
%         ylim([0 2*pi])
    xlabel('v_r_o_t [°/s]')
    ylabel('azimuth [rad]')
    ylabel(c,'Vm [mV]')

end
end