To compile MultiClampTelegraph.cpp to a mex file in R2013b, I do:

   mex -I"C:\Program Files (x86)\Molecular Devices\MultiClamp 700B Commander\3rd Party Support\Telegraph_SDK" MultiClampTelegraph.cpp

This works with version 13 of that SDK, which apparently dates from
Nov 2004.

Adam L. Taylor
January 14, 2015

-----

The .sln and .vcxproj files in this dir are for VS2012.  At some
point, would be nice to back-convert them to VS2008, since that's what
most of the dabs.ni stuff is compiled with at present.

Adam L. Taylor
March 27, 2015
