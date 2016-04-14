% As of this writing (4/6/2016), am using VS2008 to compile.
original_dir = pwd() ;
cd(fileparts(mfilename('fullpath'))) ;
mex IsAppThemed.cpp -luxtheme
cd(original_dir) ;
