classdef (Abstract=true) EventBroadcaster < handle
    % This is equivalent to a Subject in the classic Smalltalk Observer pattern.
    % The key thing it adds over Matlab's built-in event infrastructure is
    % the ability for a broadcaster to keep track of its subscribers, and
    % to have all of them unsubscribe when they need to, without the subscribers
    % having to keep track of all the Matlab event.listener objects.
    %
    % When a subscribed-to event happens at the EventBroadcaster, it looks
    % at the list of subscriptions.  For subscriptions to that event, a
    % message is sent to the subscriber.  The message is specified in the
    % subscription.  (If no message is specified in the call to .subscribeMe(),
    % the default message eventHappened() is sent.)  The signature of this
    % subscriber method should be:
    %
    %     receiverMethod(self,broadcaster,eventName,propertyName,source,event)
    % 
    % When called, the various arguments supplied are what you'd expect
    % from the name.
    properties (Access=protected, Transient=true)
        OutgoingSubscriptions_ = struct('subscriber',cell(1,0), ...
                                        'eventName',cell(1,0), ...
                                        'propertyName',cell(1,0), ...
                                        'methodName',cell(1,0))
        Listeners_ = event.listener.empty()
        BroadcastEnablement_
    end  % properties
    
    methods
        function self = EventBroadcaster()
            self.BroadcastEnablement_ = ws.Enablement();  
                % Have to initialize in the constructor, not in the property declaration, b/c
                % if do in the property declaration, all instances of the class are using a single 
                % ws.Enablement object!!!
        end
        
        function delete(self)
            delete(self.Listeners_);
            for i=1:length(self.OutgoingSubscriptions_) ,
                subscription=self.OutgoingSubscriptions_(i);
                subscriber=subscription.subscriber;
                if isvalid(subscriber) ,
                    subscriber.unregisterSubscription(self,subscription);
                end
            end
        end
        
        function subscribeMe(self,subscriber,eventName,propertyName,methodName)
            if ~exist('propertyName','var') ,
                propertyName='';
            end
            if ~exist('methodName','var') || isempty(methodName) ,
                % this is the default method to call if the subscriber
                % doesn't specify one
                methodName='eventHappened';
            end
            newSubscription=struct('subscriber',subscriber, ...
                                   'eventName',eventName, ...
                                   'propertyName',propertyName, ...
                                   'methodName',methodName);
            %fprintf('About to subscribe a figure of class %s to a model of class %s, for events of type %s\n', class(subscriber), class(self), eventName) ;
            %dbstack
            if isempty(propertyName)                   
                newListener=self.addlistener(eventName,@(source,event)(subscriber.(methodName)(self,eventName,propertyName,source,event)));
            else
                newListener=self.addlistener(propertyName,eventName,@(source,event)(subscriber.(methodName)(self,eventName,propertyName,source,event)));
            end
            self.OutgoingSubscriptions_(end+1)=newSubscription;
            self.Listeners_(end+1)=newListener;
            % The subscriber needs to keep a record of her subscriptions,
            % too, so that she can unsubscribe in her destructor.
            % Therefore, we notify her back so she can record the new
            % subscription, too.
            subscriber.registerSubscription(self,eventName,propertyName,methodName);
        end
        
        function unsubscribeMe(self,subscriber,eventName,propertyName,methodName)
            if ~exist('propertyName','var') ,
                propertyName='';
            end
            if ~exist('methodName','var') || isempty(methodName),
                % this is the default method to call if the subscriber
                % doesn't specify one
                methodName='eventHappened';
            end
            oldSubscription=struct('subscriber',subscriber, ...
                                   'eventName',eventName, ...
                                   'propertyName',propertyName, ...
                                   'methodName',methodName);
            isMatch=arrayfun(@(s)isequal(s,oldSubscription),self.OutgoingSubscriptions_);
            self.OutgoingSubscriptions_(isMatch)=[];
            delete(self.Listeners_(isMatch));
            self.Listeners_(isMatch)=[];
            subscriber.unregisterSubscription(self,oldSubscription);
        end
        
        function unsubscribeMeFromAll(self,subscriber)
            isMatch=(subscriber=={self.OutgoingSubscriptions_.subscriber});
            
            % Unregister them with the subscribers first
            for i=1:length(self.OutgoingSubscriptions_) ,
                if isMatch(i) ,
                    subscriber.unregisterSubscription(self,self.OutgoingSubscriptions_(i));
                end
            end
            
            % Now delete them from self
            self.OutgoingSubscriptions_(isMatch)=[];
            delete(self.Listeners_(isMatch));
            self.Listeners_(isMatch)=[];
        end
        
        function disableBroadcasts(self)
            self.BroadcastEnablement_.disable();
        end
        
        function enableBroadcastsMaybe(self)
            self.BroadcastEnablement_.enableMaybe();
        end
        
        function broadcast(self,eventName,varargin)
            % Not much to do here
            % Don't need to have a propertyName arg, b/c property
            % modifications automatically generate the relevant events.
            if self.BroadcastEnablement_.IsEnabled ,
                eventData = ws.EventDataWithArgs(varargin{:}) ;
                self.notify(eventName, eventData) ;
            end
        end
        
        function result = peekAtBroadcastEnablement(self)
            % This is meant to be used only for debugging, not for routine access
            result = self.BroadcastEnablement_ ;
        end
    end  % methods
end  % classdef
