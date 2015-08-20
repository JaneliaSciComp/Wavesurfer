Wavesurfer
==========

Wavesurfer is an application for acquiring electrophysiology
data.  It runs within Matlab R2013b and later (64-bit only).  At
present, you must have a Matlab license to use it.

PLEASE NOTE THAT WAVESURFER IS CURRENTLY PRE-RELEASE SOFTWARE.  THERE
WILL ALMOST CERTAINLY BE BREAKING CHANGES TO FILE FORMATS, ETC. BEFORE
VERSION 1.0 IS RELEASED, AND WE CAN MAKE NO PROMISES ABOUT BACKWARD
COMPATIBILITY.


System Requirements
-------------------

64-bit Windows 7 computer

National Instruments X Series card (i.e. 63xx)

National Instruments DAQmx driver, version 9.8.x or 14.5.x

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
in Wavesurfer is copyright 2013-2015 by the Howard Hughes Medical 
Institute.


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

Wavesurfer is currently developed by Adam L. Taylor and Ben J. Arthur.


Maintainers
-----------

[Adam L. Taylor](http://www.janelia.org/people/research-resources-staff/adam-taylor), taylora@hhmi.org  
[Scientific Computing](http://www.janelia.org/research-resources/computing-resources)  
[Janelia Research Campus](http://www.janelia.org)  
[Howard Hughes Medical Institute](http://www.hhmi.org)

[![Picture](/hhmi_janelia_160px.png)](http://www.janelia.org)


Version History
---------------

0.74:  (February 26, 2015) Added Axon Multiclamp support.  Now store
       stimulus metadata in the data file header.  Now save data as
       int16 instead of double-precision floating point.  Improved
       ScanImage integration.

0.75:  (March 9, 2015) Fixed bug with scope x-span.

0.76:  (March 11, 2015) Fixed bug with README(!).

0.77:  (March 17, 2015) Now supports timed digital outputs.

0.771: (March 18, 2015) Updated README to reflect true NI DAQmx driver
       requirements.

0.772: (March 18, 2015) Can now change scope y limits during ongoing 
       acquisition.

0.773: (March 23, 2015) Fixed bug with trial duration setting not 
       getting propagated to DAQ board on .cfg file load.

0.774: (March 25, 2015) Fixed a few more bugs.

0.775: (March 25, 2015) Fixed bug that prevented acquisition
       if some AI channels specified in MDF were marked as 
       inactive.

0.776: (April 2, 2015) Added ability to playback arbitrary stimuli
       from .wav file.  Fixed bugs with multiple DO lines and
       long-duration stimuli, and with stimuli not being generated
       properly after 1st stimulus episode when externally triggered.

0.777: (April 3, 2015) Fixed issue that prevented acquisition if
       Matlab was installed on a drive other than the C drive.

0.778: (April 14, 2015) Now have toggle-able autoscaling of y-axis
       limits for both scope windows and the test pulse window.  Added
       per-trialset and per-trial (approximate) timestamps to data
       file.  No longer rely upon DABS callbacks during data
       acquisition, but poll instead.  All internally-generated
       triggers are now themselves triggered off a common "master"
       trigger on PFI8.

0.779: (April 14, 2015) Fixed bug where couldn't test pulse after
       acquiring data.

0.78:  (April 15, 2015) Data files for continuous recordings now use
       the same file naming scheme as trial-based recordings.  Fixed
       bug with fast protocols not getting cleared when you click that
       button.  Added a very simple example user function .m file.

0.781: (April 20, 2015) Added more options for data file naming.  
       Fixed several small bugs.

0.782: (April 22, 2015) Added a two-pulse stimulus.

0.783: (April 22, 2015) Added a generic Matlab expression stimulus.

0.784: (April 29, 2015) Test pulser now uses sampling rate of
       acquisition system.

0.785: (May 11, 2015) Inactived AI channels are now really and 
       truly inactivated.

0.786: (May 12, 2015) Fixed bug with TestPulser model not getting 
       persisted to disk properly.

0.787: (May 12, 2015) Commented out debugging fprintf.  Doh!

0.8:   (May 19, 2015) Added support for digital inputs, untimed digital
       outputs.  Changed user hook function infrastructure to more
       powerful object-based scheme.  Added example user hook classes
       that implement treadmill- and VR-triggered spike rasters.  Many
       other small tweaks and improvements.  Note that version 0.8
       will not generally read protocol files from earlier versions.

0.801: (June 4, 2015) Made electrodes window narrower, so that it fits
       on a 1280x1024 screen.  Added zoom in/out, scroll up/down
       buttons to scope windows, got rid of green-on-black color
       scheme.  Test pulser now shows resistance in units tailored to
       the scale of the resistance value.  Protocol and user settings
       file formats were not changed from release 0.8.

0.802: (June 12, 2015) Fixed error on MDF load under R2013b.  Added
       ability to turn on/off scope grids.  Protocol and user settings
       files from release 0.8+ will still work with this release.

0.803: (June 29, 2015) Fixed bug in ws.loadDataFile() that made it
       error if any channels were not active.  Protocol and user
       settings files from release 0.8+ will still work with this
       release.

0.804: (July 3, 2015) Fixed bug that caused warnings on .cfg load if
       the acquisition sample rate had been changed.  Restored
       green-on-black theme for scope windows as an option.  Scope
       window buttons are now hidden if the window is not tall enough.
       Added option to always hide scope window buttons.  Protocol and
       user settings files from release 0.8+ will still work with this
       release.

0.805: (July 23, 2015) Fixed bug that made it impossible to record if 
       a user class was in use.

