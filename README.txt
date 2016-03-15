WaveSurfer
==========

WaveSurfer is an application for acquiring electrophysiology
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

National Instruments DAQmx driver, version 9.8.x, 14.5.x, or 15.1.x.

Matlab R2013b or later (64-bit)


Installation
------------

1.  Download the .zip file for the latest release from GitHub here:

        https://github.com/JaneliaSciComp/Wavesurfer/releases

2.  Extract the .zip file contents to a convenient location.

3.  In Matlab, cd to this just-created directory.

4.  At the Matlab command line, execute "installWavesurfer".  This
    will permanently modify your Matlab path so that all components
    needed by WaveSurfer are on it.  (If you don't want to permanently
    modify the path, execute "installWavesurferForNow" instead of the
    above.  This modifies the path only for the current Matlab
    session.)

5.  At the Matlab command line, execute "wavesurfer".  You should now
    be presented with the WaveSurfer user interface.

6.  Go to Tools > Device & Channels... to specify what DAQ board you
    want to use, what channels you want to use, and to set channel
    units and scales, if desired.

7.  In the main window, click the Stimulation > Enabled checkbox to
    turn on stmulation.  Click the Display > Enabled checkbox to show
    the "oscilloscope" windows where acquired data will be displayed.

8.  In the main window, click the play button (the one with the black
    righward-pointing arrow) to acquire data without saving to disk.
    Click the record button (the one with the red circle) to acquire
    data and save it to disk.

9.  To save your device settings, channel settings, and window
    positions, go to File > Save Protocol.  These can then be loaded
    in a new WaveSurfer sessions by going to File > Open Protocol...

10.  If you have questions, please contact the WaveSurfer developers.


Copyright
---------

Except where noted, all code, documentation, images, and anything else
in WaveSurfer is copyright 2013-2016 by the Howard Hughes Medical 
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

WaveSurfer was developed at the HHMI Janelia Research Campus.  It
started out as version 3 of Ephus, another electrophysiology package
largely authored by Vijay Iyer, with contributions by Tim O'Connor and
others.  Vijay is also the primary author of the DABS library, from
which the code in +ws/+dabs/+ni was taken, and of the MOST library, in
+ws/+most.

The original developer of WaveSurfer was Patrick Edson.  

WaveSurfer is currently developed by Adam L. Taylor and Ben J. Arthur.


Support
-------

WaveSurfer is developed at the HHMI Janelia Research Campus. It is
supported by the Svoboda Lab, who initiated the project, and by the
Magee, Spruston, Jayaraman, Lee, Hantman, and Koyama Labs. The project
is coordinated by Janelia's Scientific Computing Software group.


Maintainers
-----------

Adam L. Taylor 
Scientific Computing
HHMI Janelia Research Campus


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

0.9-beta-1: (October 12, 2015) Major redesign of WaveSurfer to support
            low-latency (< 5 ms) real-time feedback loops.  WaveSurfer
            now spawns two additional Matlab processes when you lauch
            it: one to aquire data and run real-time feedback loop
            code, and another to ensure that the sweep-based output
            buffer is refilled properly.  Also some streamlining of
            the triggering settings, and changes in terminology
            (e.g. "trials" are now sweeps, an "experiment" is now a
            run).  Note that this is a beta release, so is likely
            somewhat buggier than a regular release.

0.9-beta-2: (October 15, 2015) Fixed several bugs.

0.9-beta-3: (October 15, 2015) Fixed capitalization issues in the
            README.

0.9-beta-4: (October 17, 2015) Fixed another silly cosmetic bug.

0.9-beta-5: (October 29, 2015) Added missing DLL.

0.9-beta-6: (October 30, 2015) Fixed bug where satellite processes 
            didn't have proper search path.

0.9-beta-7: (November 3, 2015) Fixed bug where zero digital inputs 
            caused eventual error during acquisition. 

0.9-beta-8: (November 9, 2015) Fixed several bugs.

0.9-beta-9: (November 9, 2015) Cosmetic fix.

0.9-beta-10: (November 11, 2015) Test Pulser now reports resistance 
             in VC mode, instead of conductance.  Minor improvements 
             to ws.example.RasterTreadMill.

0.9-beta-11: (November 13, 2015) Fixes to WS-SI coordination code.

0.9-beta-12: (November 18, 2015) Fixed bug with triggering schemes, 
             fixed bug with loading older WS data files.

0.9-beta-13: (November 18, 2015) Fixed bug with mimic()'ing cell 
             arrays.

0.9-beta-14: (November 20, 2015) Fixed bug where didn't work if no 
             input channels were defined.

0.9      Dec 01, 2015    Rechristened 0.9-beta-14 as 0.9.

0.901    Jan 07, 2016    Added support for DAQmx 15.1.x.  Fixed bug in
                         error dialog message if the installed version
                         of DAQmx is not supported by WaveSurfer.

0.902    Jan 29, 2016    Fixed triggering issues that could cause acq
                         tasks but not stim tasks to trigger for a 
                         finite-duration sweep, despite nominally 
                         using the same trigger. 

0.91     Feb 12, 2016    All things that used to be set in the MDF
                         file are now settable in the GUI, and stored
                         in the protocol file. 

0.912    Mar 01, 2016    Fixed bug in README.

0.913    Mar 02, 2016    Fixed bug which resulted in actual sampling
                         rate being slightly different from nominal
                         sampling rate for sampling rates (in Hz) that
                         do not evenly divide 100 MHz.

0.914    Mar 11, 2016    Fixed bug where data was saved without
                         scaling coefficients.  Added code to
                         ws.loadDataFile() convert nominal sampling rate
                         for pre-0.913 data files to correct sampling
                         rate.  Added code to ws.loadDataFile() to
                         error if asked to return floating-point
                         (scaled) data when the data file lacks
                         scaling coefficients, as a safeguard.
