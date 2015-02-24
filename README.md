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

Except where noted, all code in Wavesurfer is copyrighted by the
Howard Hughes Medical Institute, 2015.


Authors
-------

Wavesurfer started out as version 3 of Ephus, another
electrophysiology package, largely authored by Vijay Iyer, with
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
