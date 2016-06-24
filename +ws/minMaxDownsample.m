function [t_sub_dub,data_sub_dub]=minMaxDownsample(t,data,r)
    % Static method to downsample data, but in a way that is well-suited
    % to on-screen display.  For every r data points, we calculate the min
    % and the max of them, and these are returned in data_sub_min and
    % data_sub_max.

    % if r is empty, means no downsampling called for
    if isempty(r)
        % don't subsample
        t_sub_dub=t;
        data_sub_dub=data;
    else
        % get data dims
        [n_t,n_signals,n_sweeps]=size(data);

        % downsample the timeline
        t_sub=t(1:r:end);
        n_t_sub=length(t_sub);

        % turns out that it's best to write this as a loop that can be
        % JIT-compiled my Matlab.  This is faster than blkproc(), it turns
        % out.
        data_sub_max=zeros(n_t_sub,n_signals,n_sweeps);
        data_sub_min=zeros(n_t_sub,n_signals,n_sweeps);
        for k=1:n_sweeps
            for j=1:n_signals
                i=1;
                for i_sub=1:(n_t_sub-1)
                    mx=-inf;
                    mn=+inf;
                    for i_offset=1:r
                        d=data(i,j,k);
                        if d>mx
                            mx=d;
                        end
                        if d<mn
                            mn=d;
                        end
                        i=i+1;
                    end
                    data_sub_max(i_sub,j,k)=mx;
                    data_sub_min(i_sub,j,k)=mn;
                end
                % the last block may have less than r elements
                if n_t_sub>0 ,
                    mx=-inf;
                    mn=+inf;
                    n_t_left=n_t-r*(n_t_sub-1);
                    for i_offset=1:n_t_left
                        d=data(i,j,k);
                        if d>mx
                            mx=d;
                        end
                        if d<mn
                            mn=d;
                        end
                        i=i+1;
                    end
                    data_sub_max(n_t_sub,j,k)=mx;
                    data_sub_min(n_t_sub,j,k)=mn;
                end
            end  % for j=1:n_signals
        end  % for k=1:n_sweeps

        % now "double-up" time, and put max's in the odd times, and min's in
        % the even times
        t_sub_dub=nan(2*n_t_sub,1);
        t_sub_dub(1:2:end)=t_sub;
        t_sub_dub(2:2:end)=t_sub;
        data_sub_dub=nan(2*n_t_sub,n_signals,n_sweeps);
        data_sub_dub(1:2:end,:,:)=data_sub_max;
        data_sub_dub(2:2:end,:,:)=data_sub_min;
    end
end  % function
