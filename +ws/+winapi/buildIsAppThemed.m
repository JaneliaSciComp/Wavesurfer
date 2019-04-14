% As of this writing (4/14/2019), am using VS2015 to compile.
original_dir = pwd() ;
cd(fileparts(mfilename('fullpath'))) ;
mex IsAppThemed.cpp -luxtheme
cd(original_dir) ;
