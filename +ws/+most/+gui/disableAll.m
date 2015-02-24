function disableAll(hFigOrPanel)
%DISABLEALL Disables all controls, as possible, on a figure or panel


arrayfun(@(h)disableIfPossible(h),findall(hFigOrPanel));

    function disableIfPossible(handle)
        if isprop(handle,'Enable')
            set(handle,'Enable','off')
        end
    end

end

