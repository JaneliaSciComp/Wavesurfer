function out = titleStringFromApplicationState(state)
    switch state
        case 'uninitialized'
            out = '(Uninitialized)';
        case 'no_device'
            out = 'No Device';
        case 'idle'
            out = 'Idle';
        case 'running'
            out = 'Running';
        case 'test_pulsing'
            out = 'Test Pulsing';
        otherwise
            out = 'Messed Up';
    end
end
