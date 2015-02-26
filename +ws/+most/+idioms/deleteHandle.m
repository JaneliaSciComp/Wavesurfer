function deleteHandle(h)
  %deleteSmart Delete function for handle objects, which checks if handle is valid before deleting
  %   
  % h: Handle object, or array of such
  %
  % NOTES
  %  This idiom used to avoid delete() method error: 'Invalid or deleted object'
  %
  
  delete(h(ishandle(h)));
  
end

