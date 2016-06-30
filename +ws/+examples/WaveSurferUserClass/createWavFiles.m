load testData.mat

for channel=1:8
    audiowrite(sprintf('testChannel%d_scaleFactor%0.4f.wav',channel-1,1/max(abs(data{1}(:,channel)))),data{1}(:,channel)/max(abs(data{1}(:,channel))),20000);
end