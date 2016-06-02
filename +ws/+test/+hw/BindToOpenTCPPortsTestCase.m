classdef BindToOpenTCPPortsTestCase < matlab.unittest.TestCase
    % To run these tests, need to have an NI daq attached, pointed to by
    % the MDF.  (Can be a simulated daq board.)
    
    methods (TestMethodSetup)
        function setup(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end
    
    methods (TestMethodTeardown)
        function teardown(self) %#ok<MANU>
            daqSystem = ws.dabs.ni.daqmx.System();
            ws.deleteIfValidHandle(daqSystem.tasks);
        end
    end
    
    methods (Test)
        function testBindingToOpenPorts(self)
            
            % Bind to what used to be default ports, making it impossible
            % for older versions to bind frontend/looper/refiller
            defaultPorts = struct('context',{},'socket',{},'portAddress',{},'didJustBind',{});
            defaultPorts(1).portAddress = 'tcp://127.0.0.1:8081';
            defaultPorts(2).portAddress = 'tcp://127.0.0.1:8082';
            defaultPorts(3).portAddress = 'tcp://127.0.0.1:8083';
            
            for i=1:3
                defaultPorts(i).context = zmq.core.ctx_new();
                defaultPorts(i).socket  = zmq.core.socket(defaultPorts(i).context, 'ZMQ_PUSH');
                try
                    % Bind if possible. If not, then it is already bound
                    % by, eg., Informacast.
                    zmq.core.bind(defaultPorts(i).socket, defaultPorts(i).portAddress);
                    defaultPorts(i).didJustBind=true;
                catch
                    defaultPorts(i).didJustBind=false;
                end
            end
            
            isCommandLineOnly=true;
            thisDirName=fileparts(mfilename('fullpath'));
        
            % Try to start WaveSurfer. It will fail if it uses the default
            % ports and does not check for open ports.
            try
                [wsModel,wsController]=wavesurfer(fullfile(thisDirName,'Machine_Data_File_WS_Test_with_DO.m'), ...
                    isCommandLineOnly);
                ableToBindWavesurfer=true;
            catch
                ableToBindWavesurfer=false;
            end
            
            self.verifyTrue(ableToBindWavesurfer);
            
            % Unbind the ports that we just bound.
            for i=1:3
                if defaultPorts(i).didJustBind == true
                    zmq.core.disconnect(defaultPorts(i).socket, defaultPorts(i).portAddress);
                end
                zmq.core.close(defaultPorts(i).socket);
                zmq.core.ctx_shutdown(defaultPorts(i).context);
                zmq.core.ctx_term(defaultPorts(i).context);
            end
            ws.clear();
        end  % function
        
    end  % test methods
    
end  % classdef
