General Notes
* NI DAQmx DLL is expected to be installed on system as part of DAQmx installation -- the DLLs are not supplied by Dabs

* For loadlibrary() calls, prototype files are /always/ needed for x64, so they are provided for all DAQmx versions we support with x64. For these DAQmx versions, we also supply and use prototype files for Win32 (it's not clear if this is actually needed -- it may be easier in future to defer to supplying loadlibrary() with the modified header file for the Win32 case).

* Since we are providing prototype file for versions 9 & higher, we no longer supply header file as part of Dabs release. For version 8.8, the header file /is/ supplied (copied from installation)..this is only so that header file can be found at same relative path as prototype file is stored at for versions 9 & higher. 

* To make prototype files for DAQmx versions 9 & higher, a modified header file was used to deal with (void *) issue. These modified files are stored as part of the DevTools, not as part of Dabs release, which only contains the resulting prototype files. 

* For API data code extraction, the DAQmxClass defers to the installation header files (which are available for all API versions, and need not be stored as part of the Dabs release). 


Version Detection
* 3 DAQmx API functions (common to all DAQmx versions) have been extracted out of library to use for version detection before loading the full library
* 2 prototype files, one for 32-bit and one for 64-bit, have been created for interfacing to whatever DLL version is installed to determine the version number. The latter prototype file needs/uses a thunk file, also included.


Version 8.8
* Only 32-bit supported
* Header file provided by API is stored with release (this allows header file to be found with same relative folder path as API versions 9 & higher)


Version 9.3 (and above)
* 32-bit and 64-bit supported
* Platform-specific prototype files included, with 64-bit including thunk file.



