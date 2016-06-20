#include "mex.h"

//Gateway routine
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // This function is called like: [tSubsampledAndDoubled, ySubsampledAndDoubled]=minMaxDownsample(t,y,r)
    //   t a double column vector of length nScans
    //   y a nScans x nChannels matrix of doubles
    //   r a double scalar holding a positive integer value, or empty
    //
    // If r is empty, is means "don't downsample", just return t and y as-is.

    // Load in the arguments, checking them thoroughly

    // prhs[0]: t
    //bool tIsDouble = mxIsDouble(prhs[0] ;
    //bool tIsReal = !mxIsComplex(prhs[0]) ;
    //mwSize arity = mxGetNumberOfDimensions(prhs[0]) ;
    //mwSize nCols = mxGetN(prhs[0]);
    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0]) || mxGetNumberOfDimensions(prhs[0])!=2 || mxGetN(prhs[0])!=1)  {
        mexErrMsgIdAndTxt("ws:minMaxDownSample:tNotRight", 
                          "Argument t must be a non-complex double column vector.");
    }
    mwSize nScans = mxGetM(prhs[0]);
    double *t = mxGetPr(prhs[0]);  // "Convert" to a C++ array
    
    // prhs[1]: y
    if (!mxIsDouble(prhs[1]) || mxIsComplex(prhs[1]) || mxGetNumberOfDimensions(prhs[1])!=2 || mxGetM(prhs[1])!=nScans)  {
        mexErrMsgIdAndTxt("ws:minMaxDownSample:yNotRight", 
                          "Argument y must be a non-complex double matrix with the same number of rows as t.");
    }
    mwSize nChannels = mxGetN(prhs[1]);
    double *y = mxGetPr(prhs[1]);  // "Convert" to a C++ array (sort of: it's still in col-major order)
    
    // prhs[1]: r
    bool rIsEmpty = mxIsEmpty(prhs[2]) ;
    if !rIsEmpty || !mxIsDouble(prhs[2]) || mxIsComplex(prhs[2]) || !mxIsScalar(prhs[2]) )  {
        mexErrMsgIdAndTxt("ws:minMaxDownSample:rNotRight", 
                          "Argument r must be empty or be a non-complex double scalar.");
        }
    double r = -1.0 ;
    mwSize r = 0 ;
    if (!rIsEmpty)  {
        rAsDouble = mxGetScalar(prhs[2]) ;
        if ( round(rAsDouble)!=rAsDouble || r<=0 )  {
            mexErrMsgIdAndTxt("ws:minMaxDownSample:rNotRight", 
                              "Argument r, if a scalar, must be a positive integer.");
        }
        r = (mwSize) rAsDouble ;
    }

    // At this point, all args have been read and validated

    int effectiveNLHS = max(nlhs,1) ;  // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned
    double *tSubsampledAndDoubled ;
    double *ySubsampledAndDoubled ;

    double* target ;
    double* source ;

    if (rIsEmpty)  {
        // just copy the inputs to the outputs
        if ( effectiveNLHS>=1 )  {
            plhs[0] = mxCreateDoubleMatrix(nScans, (mwSize)1, mxREAL) ;
            tSubsampledAndDoubled = mxGetPr(plhs[0]);
            for (i=0 ; i<nScans; ++i)  {
                tSubsampledAndDoubled[i] = t[i] ;
            }
        }
        if ( effectiveNLHS>=2 )  {
            plhs[1] = mxCreateDoubleMatrix(nScans, nChannels, mxREAL) ;
            ySubsampledAndDoubled = mxGetPr(plhs[1]);
            *target = ySubsampledAndDoubled ;
            *source = y ;
            mwSize nElements = nChannels * nScans ;
            for (unsigned long long i=0 ; i<nElements; ++i, ++source, ++target)  {
                *target = *source ;
                }
            }
        }
        return ;
    }

    // If get here, r is a scalar, which is the interesting case

    mwSize nScansSubsampled = (mwSize) ceil((double)nScans/rAsDouble) ;

    // Create the subsampled timeline, decimating t by the factor r
    mxArray* tSubsampledMxArray = mxCreateDoubleMatrix(nScansSubsampled, (mwSize)1, mxREAL) ;
    double* tSubsampled = mxGetPr(tSubsampledMxArray) ;
    source = t ;
    target = tSubsampled ;
    for (mwSize i=0 ; i<nScansSubsampled; ++i, source+=r, ++target) {
        *target = *source ;
    }

    // Now "double-up" time, with two copies of each time point
    mxArray* tSubsampledAndDoubledUpMxArray = mxCreateDoubleMatrix(2*nScansSubsampled, (mwSize)1, mxREAL) ;
    double* tSubsampledAndDoubledUp = mxGetPr(tSubsampledAndDoubledUpMxArray) ;
    target = tSubsampledAndDoubledUp ;
    double tSource ;
    for (source = tSubsampled; source!=(tSubsampled+nScansSubsampled); ++source) {
        tSource = *source ;
        *target = tSource ;
        ++target ;
        *target = tSource ;
        ++target ;
    }

    // Now set up for return (always assign this one)
    plhs[0] = tSubsampledAndDoubledUpMxArray ;

    // If that's all the return values the user wanted, return now
    if ( effectiveNLHS<2 )  {
        return ;
    }

    // Subsample y at each subsampled scan, getting the max and the min of the r samples for that point in the original y
    mxArray* ySubsampledMaxMxArray = mxCreateDoubleMatrix(nScansSubsampled, nScans, mxREAL) ;
    double* ySubsampledMax = mxGetPr(ySubsampledMaxMxArray) ;
    mxArray* ySubsampledMinMxArray = mxCreateDoubleMatrix(nScansSubsampled, nScans, mxREAL) ;
    double* ySubsampledMin = mxGetPr(ySubsampledMaxMxArray) ;
    double maxSoFar ;
    double minSoFar ;
    mwSize iWithinTheR ;
    for (mwSize iChannel=0 ; iChannel<nChannels; ++iChannel)  {
        iScanSubsampled = 0 ;
        iWithinTheR = 0 ;
        for (mwSize iScan=0; iScan<nScans; ++iScan)  {
            if (iWithinTheR==0)  {
                maxSoFar = y[iChannel*nScans+iScan] ;
                minSoFar = y[iChannel*nScans+iScan] ;
            } else {
                double yThis = y[iChannel*nScans+iScan] ;
                if (yThis>maxSoFar)  {
                    maxSoFar = yThis ;
                } else {
                    if (yThis<yMin)  {
                        minSoFar = yThis ;
                    }
                }
            }
            if (iWithinTheR+1 == r)  {
                // Write to the elements of the subsampled arrays
                *(ySubsampledMaxMxArray+iChannel*nScansSubsampled+iScanSubsampled) = maxSoFar ;
                *(ySubsampledMinMxArray+iChannel*nScansSubsampled+iScanSubsampled) = minSoFar ;
                ++iScanSubsampled ;
                iWithinTheR = 0 ;
            } else {
                ++iWithinTheR ;
            }
        }
        if (iWithinTheR!=0)  {
            // This means r does not evenly divide nScans, so need to fill in the last element of the subsampled arrays
            *(ySubsampledMaxMxArray+iChannel*nScansSubsampled+iScanSubsampled) = maxSoFar ;
            *(ySubsampledMinMxArray+iChannel*nScansSubsampled+iScanSubsampled) = minSoFar ;
        }
    }

    // Now for the y's, max, min, max, min, etc.
    mxArray* ySubsampledAndDoubledUpMxArray = mxCreateDoubleMatrix(2*nScansSubsampled, (mwSize)nChannels, mxREAL) ;
    double* ySubsampledAndDoubledUp = mxGetPr(ySubsampledAndDoubledUpMxArray) ;
    target = tSubsampledAndDoubledUp ;
    double* minSource = ySubsampledMin ;
    double* maxSource = ySubsampledMax ;
    for (mwSize iChannel=0 ; iChannel<nChannels; ++iChannel)  {
        for (mwSize iScanSubsampled=0; iScanSubsampled<nScansSubsampled; ++iScanSubsampled)  {
            //*(ySubsampledAndDoubledUp+iChannel*nScansSubsampled+2*iScanSubsampled)   = *(ySubsampledMax+iChannel*nScansSubsampled+iScanSubsampled) ;
            *target = *maxSource ;
            ++minSource ;
            ++target ;
            //*(ySubsampledAndDoubledUp+iChannel*nScansSubsampled+2*iScanSubsampled+1) = *(ySubsampledMin+iChannel*nScansSubsampled+iScanSubsampled) ;
            *target = *minSource ;
            ++maxSource ;
            ++target ;
        }
    }

    // Now set up for return
    plhs[1] = ySubsampledAndDoubledUpMxArray ;
}

