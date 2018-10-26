classdef (Abstract=true) EventSubscriber < handle
    % This is equivalent to an Observer in the classic Smalltalk Observer pattern.    
    properties (Access=private, Transient=true)
        IncomingSubscriptions_ = struct('broadcaster',cell(1,0), ...
                                        'eventName',cell(1,0), ...
                                        'propertyName',cell(1,0), ...
                                        'methodName',cell(1,0)) ;
    end  % properties
    
    methods        
        function delete(self)
            % Unsubscribe from all subscriptions before being destructed
            self.unsubscribeFromAll();
        end
        
        function registerSubscription(self,broadcaster,eventName,propertyName,methodName)
            % This method is designed to be called by an EventBroadcaster
            % as part of the subscribeMe() method.  It allows the subscriber
            % to also make a record of the subscription, so that all
            % subscriptions can be unsubscribed when the subscriber is
            % destructed.
            newSubscription=struct('broadcaster',broadcaster, ...
                                   'eventName',eventName, ...
                                   'propertyName',propertyName, ...
                                   'methodName',methodName);
            self.IncomingSubscriptions_(end+1)=newSubscription;
        end
        
        function unregisterSubscription(self,broadcaster,oldBroadcasterSubscription)
            % This method is designed to be called by an EventBroadcaster
            % as part of the unsubscribeMe() method.  It allows the subscriber
            % to keep their current subscriptions up-to-date, so that all
            % subscriptions can be unsubscribed when the subscriber is
            % destructed.
            
            % Convert the broadcaster's subsciption record to the
            % equivalent subscriber subscription record.
            coreOldSubscription=rmfield(oldBroadcasterSubscription,'subscriber');
            oldSubscription=coreOldSubscription;
            oldSubscription.broadcaster=broadcaster;
            
            % Define a local function to compare two (scalar) subscriptions
            function result = areTheseScalarSubscriptionsTheSame(sub1,sub2)
                % Note that the broadcasters are checked for *identity*
                result = (sub1.broadcaster==sub2.broadcaster) && ...
                         isequal(sub1.eventName,sub2.eventName) && ...
                         isequal(sub1.propertyName,sub2.propertyName) && ...
                         isequal(sub1.methodName,sub2.methodName) ;                         
            end
            
            % Delete the relevant subscriptions
            %isMatch=arrayfun(@(s)isequal(s,oldSubscription),self.IncomingSubscriptions_);
            isMatch=arrayfun(@(s)(areTheseScalarSubscriptionsTheSame(s,oldSubscription)),self.IncomingSubscriptions_);
            self.IncomingSubscriptions_(isMatch)=[];
        end
        
        function unsubscribe(self,iSubscription)
            % Unsubscribe self from the indicated subscription, by sending
            % an unsubscribe message to the broadcaster.
            subscription = self.IncomingSubscriptions_(iSubscription) ;
            broadcaster=subscription.broadcaster;
            if isvalid(broadcaster) ,
                broadcaster.unsubscribeMe(self,subscription.eventName,subscription.propertyName,subscription.methodName);
            else
                self.IncomingSubscriptions_(iSubscription) = [] ;
            end
        end
        
        function unsubscribeFromAll(self)
            % Unsubscribes self (the subscriber) from all current
            % subscriptions.  This might be done, for instance, as the
            % subscriber is being destructed.
            
            % We used to do this in a while loop, but this at least
            % prevents an infinite loop if something goes wrong...
            %self
            %if isequal(class(self), 'ws.WavesurferMainController') ,
            %    keyboard() ;
            %end
            n = length(self.IncomingSubscriptions_) ;
            for i = n:-1:1 ,
                self.unsubscribe(i);  % each time we call this, the subscription list gets shorter by 1
            end
            %nAfter = length(self.IncomingSubscriptions_)
        end
    end
end  % classdef
