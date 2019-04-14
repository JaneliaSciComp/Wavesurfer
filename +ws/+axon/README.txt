To compile MultiClampTelegraph.cpp to a mex file in R2013b, I do:

    mex -I"C:\Program Files (x86)\Molecular Devices\MultiClamp 700B Commander\3rd Party Support\Telegraph_SDK" MulticlampTelegraph.cpp

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

-----

It's best to compile this .mex file (and all others in WS) using
VS2008, because 64-bit Matlab R2013b onward (as of this writing) all
depend on the MSVC 2005 and MSVC 2008 redistributables.  So if you compile
with VS 2008, you don't end up with an added dependency on an
additional MSVC redistributable.

I just compiled the mex file using VS2008, and checked using "dumpbin
/dependents" that it now relies on msvcr90.dll, which is the MSVC 2008
one (there's a table on the wiki page about MS Visual C++).

Adam L. Taylor
April 19, 2015

-----

Copied the MultiClampBroadcastMsg.hpp file distributed with Multiclamp 700B Commander 2.1 from
C:\Program Files (x86)\Molecular Devices\MultiClamp 700B Commander\3rd Party Support\Telegraph_SDK
to this folder.  So now we compile with:

    mex MulticlampTelegraph.cpp
    
in Matlab 2013b, using the VS2008 compiler.

Adam L. Taylor
March 20, 2016

-----

Now use

    mex MulticlampTelegraph.cpp
    
in Matlab 2015b, using the VS2015 compiler.

Adam L. Taylor
April 24, 2019
