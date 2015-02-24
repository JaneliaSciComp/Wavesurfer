function safeDeleteObj(obj)
    %SAFEDELETEOBJ Checks if the object handle is valid and deletes it if so.
    % Returns true if object was valid.
    
    %VI20141219: Don't see a reason to report any error if object isn't extant/valid    
    if ws.most.idioms.isValidObj(obj)
        delete(obj);
    end
    
    %     try
    %         tf = false;
    %         if ws.most.idioms.isValidObj(obj)
    %             delete(obj);
    %             tf = true;
    %         end
    %     catch ME
    %         ws.most.idioms.reportError(ME);
    %         tf = [];
    %     end
end