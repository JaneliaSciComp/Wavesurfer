#include <math.h>
#include "mex.h"

typedef __int16  int16_t ;   // Map MS type to now-standard-C++ type

/*
inline 
double getElement(double* a, mwIndex i, mwIndex j, mwSize m)  {
    // Returns element at row i, col j from m x n array a, where a is stored in *column-major* order.
    // i, j are assumed to be zero-based indices.  Note that we don't need to know n, the number of columns in a.
    return *(a + j*m + i) ;
}
*/

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // This function is called like: scaledData = scaledDoubleAnalogDataFromRaw(dataAsADCCounts, channelScales, scalingCoefficients)
    // Function to convert raw ADC data as int16s to doubles, taking to the
    // per-channel scaling factors into account.
    //
    //   scalingCoefficients: nScans x nChannels int16 array
    //   channelScales:  1 x nChannels double array, each element having
    //                   (implicit) units of V/(native unit), where each
    //                   channel has its own native unit.
    //   scalingCoefficients: nCoefficients x nChannels double array,
    //                        contains scaling coefficients for converting
    //                        ADC counts to volts at the ADC input.  Row 1 
    //                        is the constant terms, row 2 the linear, 
    //                        row 3 quadratic, etc.
    //
    //   scaledData: nScans x nChannels double array containing the scaled
    //               data, each channel with it's own native unit.

    // Load in the arguments, checking them thoroughly

    // prhs[0]: dataAsADCCounts
    if ( mxIsClass(prhs[0], "int16") && mxGetNumberOfDimensions(prhs[0])==2 )  {
        // all is well
    } else {
        mexErrMsgIdAndTxt("ws:scaledDoubleAnalogDataFromRawMex:scalingCoefficientsNotRight", 
                          "Argument scalingCoefficients must be an int16 matrix");
    }
    mwSize nScans = mxGetM(prhs[0]) ;
    mwSize nChannels = mxGetN(prhs[0]) ;
    int16_t* dataAsADCCounts = (int16_t *) mxGetData(prhs[0]) ;   // "Convert" to a C++ array, although still in col-major order
    
    // prhs[1]: channelScales
    if (mxIsDouble(prhs[1]) && !mxIsComplex(prhs[1]) && mxGetNumberOfDimensions(prhs[1])==2 && mxGetN(prhs[1])==nChannels)  {
        // all is well
    } else {
        mexErrMsgIdAndTxt("ws:scaledDoubleAnalogDataFromRawMex:channelScalesNotRight", 
                          "Argument channelScales must be a non-complex double row vector with the same number of columns as dataAsADCCounts.");
    }
    double *channelScales = mxGetPr(prhs[1]);  // "Convert" to a C++ array
    
    // prhs[2]: scalingCoefficients
    if (mxIsDouble(prhs[2]) && !mxIsComplex(prhs[2]) && mxGetNumberOfDimensions(prhs[2])==2 && mxGetN(prhs[2])==nChannels)  {
        // all is well
    } else {
        mexErrMsgIdAndTxt("ws:scaledDoubleAnalogDataFromRawMex:scalingCoefficientsNotRight", 
                          "Argument scalingCoefficients must be a non-complex double matrix with the same number of columns as dataAsADCCounts.");
    }
    mwSize nCoefficients = mxGetM(prhs[2]) ;
    double *scalingCoefficients = mxGetPr(prhs[2]) ;   // "Convert" to a C++ array, although still in col-major order

    // At this point, all args have been read and validated

    // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned
    plhs[0] = mxCreateDoubleMatrix(nScans, nChannels, mxREAL) ;
    double* scaledData =  mxGetPr(plhs[0]) ;

    // For each element of dataAsADCCounts, pass it through the polynominal function defined by the scaling coefficients for that channel, 
    // and set the corresponding element of scaledData
    int16_t* source = dataAsADCCounts ;  // source points to the current element of the "source" array, dataAsADCCounts
    if (nCoefficients==0)  {
        // If no coeffs, the "polynominal" always evals to zero
        for (mwIndex j=0; j<nChannels; ++j)  {
            double thisChannelScale = channelScales[j] ;  
            const double datumAsADCVoltage = 0 ;
            double scaledDatum = datumAsADCVoltage/thisChannelScale ;
            double *targetStart = scaledData + j*nScans ;  // pointer for first target element for this channel
            double *targetEnd = targetStart + nScans ;  // pointer just pasty for last target element for this channel
            for (double *target = targetStart; target<targetEnd; target++)  {
                *target = scaledDatum ;
            }
        }
    } 
    else if (nCoefficients==1) {
        // If one coeff, the polynominal always evals to a constant
        for (mwIndex j=0; j<nChannels; ++j)  {
            const double thisChannelScale = channelScales[j] ;  
              // Get the scaling factor for this channel, which is actually completely separate from the scaling coefficients
              // This is the scaling factor to convert from volts at the BNC to whatever the units of the actual measurment are.
              // The "scaling coefficients" define how to convert from "counts" at the ADC to volts at the BNC.
            const double* scalingCoefficientsForThisChannel = scalingCoefficients + j*nCoefficients ;
            const double c0 = scalingCoefficientsForThisChannel[0] ;
            const double y = c0 ;
            const double scaledDatum = y/thisChannelScale ;
            double *targetStart = scaledData + j*nScans ;  // pointer for first target element for this channel
            const double *targetEnd = targetStart + nScans ;  // pointer just pasty for last target element for this channel
            for (double *target = targetStart; target<targetEnd; target++)  {
                const double x = double(*source) ; 
                // Do the whole business to efficiently evaluate a polynomial
                *target = scaledDatum ;
            }
        }
    }
    else if (nCoefficients==2) {
        for (mwIndex j=0; j<nChannels; ++j)  {
            const double thisChannelScale = channelScales[j] ;  
              // Get the scaling factor for this channel, which is actually completely separate from the scaling coefficients
              // This is the scaling factor to convert from volts at the BNC to whatever the units of the actual measurment are.
              // The "scaling coefficients" define how to convert from "counts" at the ADC to volts at the BNC.
            const double* scalingCoefficientsForThisChannel = scalingCoefficients + j*nCoefficients ;
            const double c0 = scalingCoefficientsForThisChannel[0] ;
            const double c1 = scalingCoefficientsForThisChannel[1] ;
            double *targetStart = scaledData + j*nScans ;  // pointer for first target element for this channel
            const double *targetEnd = targetStart + nScans ;  // pointer just pasty for last target element for this channel
            for (double *target = targetStart; target<targetEnd; target++)  {
                const double x = double(*source) ; 
                // Do the whole business to efficiently evaluate a polynomial
                const double y = c0 + x*c1 ;
                const double scaledDatum = y/thisChannelScale ;
                *target = scaledDatum ;
                // Advance the source pointer once, since the source and target elements are one-to-one
                ++source ;
            }
        }
    }
    else if (nCoefficients==3) {
        for (mwIndex j=0; j<nChannels; ++j)  {
            const double thisChannelScale = channelScales[j] ;  
              // Get the scaling factor for this channel, which is actually completely separate from the scaling coefficients
              // This is the scaling factor to convert from volts at the BNC to whatever the units of the actual measurment are.
              // The "scaling coefficients" define how to convert from "counts" at the ADC to volts at the BNC.
            const double* scalingCoefficientsForThisChannel = scalingCoefficients + j*nCoefficients ;
            const double c0 = scalingCoefficientsForThisChannel[0] ;
            const double c1 = scalingCoefficientsForThisChannel[1] ;
            const double c2 = scalingCoefficientsForThisChannel[2] ;
            double *targetStart = scaledData + j*nScans ;  // pointer for first target element for this channel
            const double *targetEnd = targetStart + nScans ;  // pointer just pasty for last target element for this channel
            for (double *target = targetStart; target<targetEnd; target++)  {
                const double x = double(*source) ; 
                // Do the whole business to efficiently evaluate a polynomial
                const double y = c0 + x*(c1 + x*c2) ;
                const double scaledDatum = y/thisChannelScale ;
                *target = scaledDatum ;
                // Advance the source pointer once, since the source and target elements are one-to-one
                ++source ;
            }
        }
    }
    else if (nCoefficients==4) {
        for (mwIndex j=0; j<nChannels; ++j)  {
            const double thisChannelScale = channelScales[j] ;  
              // Get the scaling factor for this channel, which is actually completely separate from the scaling coefficients
              // This is the scaling factor to convert from volts at the BNC to whatever the units of the actual measurment are.
              // The "scaling coefficients" define how to convert from "counts" at the ADC to volts at the BNC.
            const double* scalingCoefficientsForThisChannel = scalingCoefficients + j*nCoefficients ;
            const double c0 = scalingCoefficientsForThisChannel[0] ;
            const double c1 = scalingCoefficientsForThisChannel[1] ;
            const double c2 = scalingCoefficientsForThisChannel[2] ;
            const double c3 = scalingCoefficientsForThisChannel[3] ;
            double *targetStart = scaledData + j*nScans ;  // pointer for first target element for this channel
            const double *targetEnd = targetStart + nScans ;  // pointer just pasty for last target element for this channel
            for (double *target = targetStart; target<targetEnd; target++)  {
                const double x = double(*source) ; 
                // Do the whole business to efficiently evaluate a polynomial
                const double y = c0 + x*(c1 + x*(c2 + x*c3) ) ;
                const double scaledDatum = y/thisChannelScale ;
                *target = scaledDatum ;
                // Advance the source pointer once, since the source and target elements are one-to-one
                ++source ;
            }
        }
    }
    else {
        // if get here nCoefficients>=5
        for (mwIndex j=0; j<nChannels; ++j)  {
            double thisChannelScale = channelScales[j] ;  
              // Get the scaling factor for this channel, which is actually completely separate from the scaling coefficients
              // This is the scaling factor to convert from volts at the BNC to whatever the units of the actual measurment are.
              // The "scaling coefficients" define how to convert from "counts" at the ADC to volts at the BNC.
            double* scalingCoefficientsForThisChannel = scalingCoefficients + j*nCoefficients ;
            double* pointerToHighestOrderCoefficient = scalingCoefficientsForThisChannel + (nCoefficients-1) ;
            double highestOrderCoefficient = *(pointerToHighestOrderCoefficient) ;
            double *targetStart = scaledData + j*nScans ;  // pointer for first target element for this channel
            double *targetEnd = targetStart + nScans ;  // pointer just pasty for last target element for this channel
            for (double *target = targetStart; target<targetEnd; target++)  {
                double datumAsADCCounts = double(*source) ;
                // Do the whole business to efficiently evaluate a polynomial
                double temp = highestOrderCoefficient ;
                for ( double* pointerToCurrentCoefficient = pointerToHighestOrderCoefficient-1 ; 
                      pointerToCurrentCoefficient>=scalingCoefficientsForThisChannel ;
                      --pointerToCurrentCoefficient )  {
                    double thisCoefficient = *pointerToCurrentCoefficient ;
                    temp = thisCoefficient + datumAsADCCounts * temp ;
                }
                double datumAsADCVoltage = temp ;   // compiler should eliminate this...
                double scaledDatum = datumAsADCVoltage/thisChannelScale ;
                *target = scaledDatum ;
                // Advance the source pointer once, since the source and target elements are one-to-one
                ++source ;
            }
        }
    }

    // plhs[0] should have all its elements filled with rich, savory, properly-scaled data at this point, so exit
}
