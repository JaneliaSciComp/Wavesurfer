function Vm=quantifyCellularResponse_ (data)

sf=20000;

co=50; %cutoff frequency for lowpass filter

binsize=0.05*sf; %binsize in wavedata indices (time*acquisition frequency; s*Hz)
NrOfBins=floor(length(data)/binsize); 
n=NrOfBins*binsize;
 
Vm=mean(reshape(lowpassmy_(data(1:n,1),sf,co),binsize,NrOfBins)); %Vm