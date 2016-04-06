#include "mex.h"
#include "windows.h"
#include "uxtheme.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    bool isAppThemed = IsAppThemed() ;  // Call the winapi function

	// Return the number of samples available
	plhs[0] = mxCreateDoubleScalar((double)isAppThemed);	// even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned
}
