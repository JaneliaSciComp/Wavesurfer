classdef Mimic < handle
    % Abstract class representing a "mimic", i.e. an object that can take
    % on the settings from another object, in place.  This is used
    % exclusively for the purposes of saving object state in the .cfg file,
    % and restoring from same.  (OK, it's also used for the .usr file in
    % one case, but that's a case where again we want to save the state and
    % restore it later.)  So the mimicry is really only in a limited
    % context: Whatever is appropriate when saving/loading the .cfg file.
    
    methods (Abstract=true)
        mimic(self, other)  % Make self have same settings as other, in place
    end
    
    methods
        % We call this clone so it's clear to a reader we're not
        % inhieriting from ws.mixin.Copyable
        function other=clone(self)  % We base this on mimic(), which we need anyway.  Note that we don't inherit from ws.mixin.Copyable
            className=class(self);
            other=feval(className);
            other.mimic(self);
        end  % function
        
        function s=encodeSettings(self)
            % Return a something representing the current object settings,
            % suitable for saving to disk 
            s=self.clone();  % easiest thing is just to save a clone of the object to disk
        end  % function

        %function cloneOfOriginal=restoreSettingsAndReturnCopyOfOriginal(self, other)
        function restoreSettings(self, other)
            %cloneOfOriginal=self.clone();
            self.mimic(other);
        end  % function
    end

    methods (Access=protected)
       function mimicHelper(self,other,propertyNamesToCopy)
           % A utility function to make mimic() easier to implement
           nPropertyNamesToCopy=length(propertyNamesToCopy);
           for i=1:nPropertyNamesToCopy ,
               propertyName=propertyNamesToCopy{i};
               if ismethod(self.(propertyName),'mimic')
                   self.(propertyName).mimic(other.(propertyName));
               else
                   self.(propertyName) = other.(propertyName) ;
               end
           end
       end  % function
    end
    
end
