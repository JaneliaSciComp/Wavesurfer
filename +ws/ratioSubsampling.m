function r=ratioSubsampling(dt,T_view,n_pels_view)
    % Computes r, a good ratio to use for subsampling data on time base t
    % for plotting in Spoke_main_plot plot, given that the x axis of
    % Spoke_main_plot spans T_view seconds.  Returns the empty matrix if no
    % subsampling is called for.
    n_t_view=T_view/dt;
    samples_per_pel=n_t_view/n_pels_view;
    %if samples_per_pel>10  % original value
    if samples_per_pel>2
        %if samples_per_pel>1.2
        % figure out how much we're going to subsample
        samples_per_pel_want=2;  % original value
        %samples_per_pel_want=1;
        n_t_view_want=n_pels_view*samples_per_pel_want;
        r=floor(n_t_view/n_t_view_want);
    else
        r=[];  % no need for resampling
    end
end  % function

