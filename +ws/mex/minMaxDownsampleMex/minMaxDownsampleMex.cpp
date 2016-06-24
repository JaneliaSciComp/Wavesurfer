#include <math.h>
#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // This function is called like: [tSubsampledAndDoubledUp, ySubsampledAndDoubledUp]=minMaxDownsampleMex(t,y,r)
    //   t a double column vector of length nScans
    //   y a nScans x nChannels matrix of doubles
    //   r a double scalar holding a positive integer value, or empty
    //
    // If r is empty, is means "don't downsample", just return t and y as-is.

    // Load in the arguments, checking them thoroughly

    // prhs[0]: t
    if ( mxIsDouble(prhs[0]) && !mxIsComplex(prhs[0]) && mxGetNumberOfDimensions(prhs[0])==2 && mxGetN(prhs[0])==1 )  {
        // all is well
    }
    else  {
        mexErrMsgIdAndTxt("ws:minMaxDownSample:tNotRight", 
                          "Argument t must be a non-complex double column vector.");
    }
    mwSize nScans = mxGetM(prhs[0]) ;
    double *t = mxGetPr(prhs[0]);  // "Convert" to a C++ array
    
    // prhs[1]: y
    //bool isDouble = mxIsDouble(prhs[1]) ;
    //bool isReal = mxIsComplex(prhs[1]) ;
    //mwSize nDims = mxGetNumberOfDimensions(prhs[1]) ;
    //mwSize nRows = mxGetM(prhs[1]) ;
    if ( mxIsDouble(prhs[1]) && !mxIsComplex(prhs[1]) && mxGetNumberOfDimensions(prhs[1])==2 && mxGetM(prhs[1])==nScans )  {
        // all is well
    }
    else  {
        mexErrMsgIdAndTxt("ws:minMaxDownSample:yNotRight", 
                          "Argument y must be a non-complex double matrix with the same number of rows as t.");
    }
    mwSize nChannels = mxGetN(prhs[1]);
    double *y = mxGetPr(prhs[1]);  // "Convert" to a C++ array (sort of: it's still in col-major order)
    
    // prhs[1]: r
    bool rIsEmpty ;
    if ( mxIsEmpty(prhs[2]) )  {
        // this is always OK
        rIsEmpty = true ;
    } else {
        rIsEmpty = false ;
        // non-empty
        if ( mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxIsScalar(prhs[2]) )  {
            // this is ok
        }  
        else  {
            mexErrMsgIdAndTxt("ws:minMaxDownSample:rNotRight", 
                              "Argument r must be empty or be a non-complex double scalar.");
        }
    }

    double rAsDouble = -1.0 ;  // should not be used if rIsEmpty
    mwSize r = 0 ;  // should not be used if rIsEmpty
    if (!rIsEmpty)  {
        rAsDouble = mxGetScalar(prhs[2]) ;
        if ( floor(rAsDouble)!=ceil(rAsDouble) || rAsDouble<=0 )  {
            mexErrMsgIdAndTxt("ws:minMaxDownSample:rNotRight", 
                              "Argument r, if a scalar, must be a positive integer.");
        }
        r = (mwSize) rAsDouble ;
    }

    // At this point, all args have been read and validated

    int effectiveNLHS = (nlhs>1)?nlhs:1 ;  // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned
    double* tSubsampledAndDoubled ;
    double* ySubsampledAndDoubled ;

    double* target ;
    double* targetEnd ;
    double* source ;

    if (rIsEmpty)  {
        // just copy the inputs to the outputs
        if ( effectiveNLHS>=1 )  {
            plhs[0] = mxCreateDoubleMatrix(nScans, (mwSize)1, mxREAL) ;
            tSubsampledAndDoubled = mxGetPr(plhs[0]);
            //for (mwSize i=0 ; i<nScans; ++i)  {
            //    tSubsampledAndDoubled[i] = t[i] ;
            //}
            target = tSubsampledAndDoubled ;
            source = t ;
            targetEnd = tSubsampledAndDoubled + nScans ;
            while (target!=targetEnd)  {
                *target = *source ;
                ++target ;
                ++source ;
            }
        }
        if ( effectiveNLHS>=2 )  {
            plhs[1] = mxCreateDoubleMatrix(nScans, nChannels, mxREAL) ;
            ySubsampledAndDoubled = mxGetPr(plhs[1]);
            target = ySubsampledAndDoubled ;
            source = y ;
            mwSize nElements = nChannels * nScans ;
            targetEnd = ySubsampledAndDoubled + nElements ;
            //for (mwSize i=0 ; i<nElements; ++i, ++source, ++target)  {
            //    *target = *source ;
            //}
            while (target!=targetEnd)  {
                *target = *source ;
                ++target ;
                ++source ;
            }
        }
        return ;
    }

    // If get here, r is a scalar, which is the interesting case

    mwSize nScansSubsampled = (mwSize) (ceil(((double)nScans)/rAsDouble)) ;

    // Create the subsampled timeline, decimating t by the factor r
    mxArray* tSubsampledMxArray = mxCreateDoubleMatrix(nScansSubsampled, (mwSize)1, mxREAL) ;
    double* tSubsampled = mxGetPr(tSubsampledMxArray) ;
    source = t ;
    target = tSubsampled ;
    //for (mwSize i=0 ; i<nScansSubsampled; ++i, source+=r, ++target) {
    //    *target = *source ;
    //}
    targetEnd = tSubsampled + nScansSubsampled ;
    while (target!=targetEnd)  {
        *target = *source ;
        ++target ;
        source+=r ;
    }

    // Now "double-up" time, with two copies of each time point
    mxArray* tSubsampledAndDoubledUpMxArray = mxCreateDoubleMatrix(2*nScansSubsampled, (mwSize)1, mxREAL) ;
    double* tSubsampledAndDoubledUp = mxGetPr(tSubsampledAndDoubledUpMxArray) ;
    target = tSubsampledAndDoubledUp ;
    source = tSubsampled ;
    targetEnd = tSubsampledAndDoubledUp + 2*nScansSubsampled ;
    //for (source = tSubsampled; source!=(tSubsampled+nScansSubsampled); ++source) {
    while (target!=targetEnd)  {
        double tSource = *source ;
        *target = tSource ;
        ++target ;
        *target = tSource ;
        ++target ;
        ++source ;
    }

    // Now set up for return (always assign this one)
    plhs[0] = tSubsampledAndDoubledUpMxArray ;

    // If that's all the return values the user wanted, return now
    if ( effectiveNLHS<2 )  {
        return ;
    }

    // Subsample y at each subsampled scan, getting the max and the min of the r samples for that point in the original y
    mxArray* ySubsampledMaxMxArray = mxCreateDoubleMatrix(nScansSubsampled, nChannels, mxREAL) ;
    double* ySubsampledMax = mxGetPr(ySubsampledMaxMxArray) ;
    mxArray* ySubsampledMinMxArray = mxCreateDoubleMatrix(nScansSubsampled, nChannels, mxREAL) ;
    double* ySubsampledMin = mxGetPr(ySubsampledMinMxArray) ;
    double maxSoFar ;
    double minSoFar ;
    mwSize iWithinTheR ;
    //mwSize iScanSubsampled ;
    double* minTarget ;
    double* maxTarget ;
    double* sourceEnd ;
    source = y ;
    double yThis ;  // for holding the current value of the y array
    for (mwSize iChannel=0 ; iChannel<nChannels; ++iChannel)  {
        maxTarget = ySubsampledMax + iChannel*nScansSubsampled ;
        minTarget = ySubsampledMin + iChannel*nScansSubsampled ;
        source = y + iChannel*nScans ;
        sourceEnd = source + nScans ;
        iWithinTheR = 0 ;
        while (source!=sourceEnd)  { 
            if (iWithinTheR==0)  {
                yThis = *source ;
                maxSoFar = yThis ;
                minSoFar = yThis ;
            } else {
                yThis = *source ;
                if (yThis>maxSoFar)  {
                    maxSoFar = yThis ;
                } else {
                    if (yThis<minSoFar)  {
                        minSoFar = yThis ;
                    }
                }
            }
            if (iWithinTheR+1 == r)  {
                // Write to the elements of the subsampled arrays
                *maxTarget = maxSoFar ;
                *minTarget = minSoFar ;
                ++minTarget ;
                ++maxTarget ;
                iWithinTheR = 0 ;
            } else {
                ++iWithinTheR ;
            }
            ++source ;
        }
        if ( iWithinTheR!=0 && nScansSubsampled>0 )  {  
            // This means r does not evenly divide nScans, so need to write the current minSoFar, maxSoFar to last el of ySubsampledMax, ySampledMin
            *maxTarget = maxSoFar ;
            *minTarget = minSoFar ;
        }
    }

    // Now for the y's, max, min, max, min, etc.
    mwSize nScansSubsampledAndDoubledUp = 2*nScansSubsampled ;
    mxArray* ySubsampledAndDoubledUpMxArray = mxCreateDoubleMatrix(nScansSubsampledAndDoubledUp, (mwSize)nChannels, mxREAL) ;
    double* ySubsampledAndDoubledUp = mxGetPr(ySubsampledAndDoubledUpMxArray) ;
    target = ySubsampledAndDoubledUp ;
    targetEnd = ySubsampledAndDoubledUp + nChannels*nScansSubsampledAndDoubledUp ;
    double* minSource = ySubsampledMin ;
    double* maxSource = ySubsampledMax ;
    //for (mwSize iChannel=0 ; iChannel<nChannels; ++iChannel)  {
    //    for (mwSize iScanSubsampled=0; iScanSubsampled<nScansSubsampled; ++iScanSubsampled)  {
    //        //*(ySubsampledAndDoubledUp+iChannel*nScansSubsampled+2*iScanSubsampled)   = *(ySubsampledMax+iChannel*nScansSubsampled+iScanSubsampled) ;
    //        *target = *maxSource ;
    //        ++maxSource ;
    //        ++target ;
    //        //*(ySubsampledAndDoubledUp+iChannel*nScansSubsampled+2*iScanSubsampled+1) = *(ySubsampledMin+iChannel*nScansSubsampled+iScanSubsampled) ;
    //        *target = *minSource ;
    //        ++minSource ;
    //        ++target ;
    //    }
    //}
    while (target!=targetEnd)  {
        *target = *maxSource ;
        ++maxSource ;
        ++target ;
        *target = *minSource ;
        ++minSource ;
        ++target ;
    }

    // Now set up for return
    plhs[1] = ySubsampledAndDoubledUpMxArray ;
}
