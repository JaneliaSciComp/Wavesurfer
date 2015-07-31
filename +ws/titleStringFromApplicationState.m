function out = titleStringFromApplicationState(state)
    switch state
        case 'uninitialized'
            out = '(Uninitialized)';
        case 'no_mdf'
            out = 'No MDF';
        case 'idle'
            out = 'Idle';
        case 'running'
            out = 'Running';
        case 'test_pulsing'
            out = 'Test Pulsing';
        otherwise
            out = '';
    end
end
