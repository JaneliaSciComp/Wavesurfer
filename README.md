Wavesurfer
==========

Wavesurfer is an application for acquiring electrophysiology
data.  It runs within Matlab R2013b and later (64-bit only).  At
present, you must have a Matlab license to use it.

PLEASE NOTE THAT WAVESURFER IS CURRENTLY PRE-RELEASE SOFTWARE.  THERE
WILL ALMOST CERTAINLY BE BREAKING CHANGES TO FILE FORMATS, ETC. BEFORE
VERSION 1.0 IS RELEASED, AND WE CAN MAKE NO PROMISES ABOUT BACKWARD
COMPATIBILITY.  UNLESS YOU WORK AT HHMI JANELIA (WHERE WE CAN EASILY
HELP YOU), WE DO NOT ADVISE YOU TO USE WAVESURFER FOR DOING ACTUAL
SCIENCE.


System Requirements
-------------------

64-bit Windows 7 computer

National Instruments X Series card (i.e. 63xx)

National Instruments DAQmx driver 9.8 or later

Matlab R2013b or later (64-bit)


Installation
------------

1.  Download the .zip file from GitHub.

2.  Extract the .zip file contents to a convenient location.

3.  In Matlab, cd to this just-created directory.

4.  At the Matlab command line, execute "installWavesurfer".  This
    will permanently modify your Matlab path so that all components
    needed by Wavesurfer are on it.  (If you don't want to permanently
    modify the path, execute "installWavesruferForNow" instead of the
    above.  This modifies the path only for the current Matlab
    session.)

5.  To use Wavesurfer, you must create a "machine data file".  This
    file specifies which National Instruments board you want to use
    with Wavesurfer, and which channels, and a few other things.  An
    example machine data file is located at:

        +ws/+test/+hw/Machine_Data_File_WS_Test.m

    within the Wavesurfer directory.  You should copy this file to a
    convenient location, and customize it as needed.

6.  At the Matlab command line, execute "wavesurfer".  You should now
    be presented with the Wavesurfer UI, but almost all the controls
    will be grayed.

7.  Go to File > Load Machine Data File... and select the file you
    created in step 5 above.

8.  Most of the Wavesurfer controls will ungray, and at this point
    everything should be more-or-less self-explanatory.

9.  If you have questions, please contact the Wavesurfer developer(s).


Copyright
---------

Except where noted, all code, documentation, images, and anything else
in Wavesurfer is copyright 2015 by the Howard Hughes Medical Institute.


License
-------

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

* Neither the name of HHMI nor the names of its contributors may be
  used to endorse or promote products derived from this software
  without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


Authors
-------

Wavesurfer started out as version 3 of Ephus, another
electrophysiology package largely authored by Vijay Iyer, with
contributions by Tim O'Connor and others.  Vijay is also the primary
author of the DABS library, from which the code in +ws/+dabs/+ni was
taken, and of the MOST library, in +ws/+most.

The original developer of Wavesurfer was Patrick Edson.  

Wavesurfer is currently developed by Adam L. Taylor.


Maintainers
-----------

[Adam L. Taylor](http://www.janelia.org/people/research-resources-staff/adam-taylor), taylora@hhmi.org  
[Scientific Computing](http://www.janelia.org/research-resources/computing-resources)  
[Janelia Research Campus](http://www.janelia.org)  
[Howard Hughes Medical Institute](http://www.hhmi.org)

[![Picture](/hhmi_janelia_160px.png)](http://www.janelia.org)


Version History
---------------

0.74: (February 26, 2015) Added Axon Multiclamp support.  Now store
      stimulus metadata in the data file header.  Now save data as
      int16 instead of double-precision floating point.  Improved
      ScanImage integration.

0.75: (March 9, 2015) Fixed bug with scope x-span.

0.76: (March 11, 2015) Fixed bug with README(!).
