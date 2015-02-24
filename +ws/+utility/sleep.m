function sleep(duration)
    % Put the current thread to sleep for duration seconds, without
    % flushing the event queue like pause() does.  This uses Java.

    java.lang.Thread.sleep(1000*duration);
end

