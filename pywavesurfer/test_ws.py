from __future__ import division
import os
import math
import numpy as np
import pytest
from . import ws


def test_loading_file():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, 'test2.h5')
    dataAsDict = ws.loadDataFile(file_name)
    scan = dataAsDict['sweep_0001']['analogScans']
    assert scan.dtype == 'float64'
    assert np.allclose(scan.mean(axis=1), np.array([1.78443789, 1.78402293]))
    acq_sampling_rate = float(dataAsDict['header']['AcquisitionSampleRate'])
    assert acq_sampling_rate == 20e3
    n_a_i_channels = int(dataAsDict['header']['NAIChannels'])
    assert n_a_i_channels == 3
    n_active_a_i_channels = int(dataAsDict['header']['IsAIChannelActive'].sum())
    assert n_active_a_i_channels == 2
    stim_sampling_rate = dataAsDict['header']['StimulationSampleRate']
    assert stim_sampling_rate == 20e3
    x = dataAsDict['sweep_0001']['analogScans']
    assert np.absolute(np.max(x[0]) - 5) < 0.01
    assert np.absolute(np.min(x[0]) - 0) < 0.01


def test_load_file_fail():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, 'no_file.h5')
    with pytest.raises(IOError) as ex:
        _ = ws.loadDataFile(file_name)
    assert 'The file' in str(ex.value)

    file_name = os.path.join(this_dir_name, 'no_h5.h6')
    with pytest.raises(RuntimeError) as ex:
        _ = ws.loadDataFile(file_name)
    assert 'File must be a WaveSurfer-generated HDF5 (.h5) file.' in str(ex.value)


def test_type_single():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, 'test2.h5')
    dataAsDict = ws.loadDataFile(file_name, format_string='single')
    scan = dataAsDict['sweep_0001']['analogScans']
    assert scan.dtype == 'float32'
    assert np.allclose(scan.mean(axis=1), np.array([1.78443789, 1.78402293]))


def test_type_raw():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, 'test2.h5')
    dataAsDict = ws.loadDataFile(file_name, format_string='raw')  # conversion to scaled data would fail for this file
    scan = dataAsDict['sweep_0001']['analogScans']
    assert scan.dtype == 'int16'
    assert np.allclose(scan.mean(axis=1), np.array([5565.12903571, 5563.84042857]))


def test_loading_older_file_with_funny_sampling_rate():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, '30_kHz_sampling_rate_0p912_0001.h5')
    data_file_as_struct = ws.loadDataFile(file_name, 'raw')  # conversion to scaled data would fail for this file
    # The nominal sampling rate was 30000, but the returned
    # sampling rate should be ~30003 Hz, to make (100 Mhz)/fs an
    # integer.
    returned_acq_sampling_rate = data_file_as_struct['header']['Acquisition']['SampleRate']
    n_timebase_ticks_per_acq_sample = 100e6 / returned_acq_sampling_rate  # should be exactly 3333
    assert n_timebase_ticks_per_acq_sample == 3333
    returned_stim_sampling_rate = data_file_as_struct['header']['Stimulation']['SampleRate']
    n_timebase_ticks_per_stim_sample = 100e6 / returned_stim_sampling_rate  # should be exactly 3333
    assert n_timebase_ticks_per_stim_sample == 3333


def test_loading_newer_file_with_funny_sampling_rate():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, '30_kHz_sampling_rate_0p913_0001.h5')
    data_file_as_struct = ws.loadDataFile(file_name, 'raw')
    # The requested sampling rate was 30000, but this version of WS
    # coerces that in the UI to an acheivable rate, which should be
    # ~30003 Hz, to make (100 Mhz)/fs an integer.
    returned_acq_sampling_rate = data_file_as_struct['header']['Acquisition']['SampleRate']
    n_timebase_ticks_per_acq_sample = 100e6 / returned_acq_sampling_rate  # should be exactly 3333
    assert n_timebase_ticks_per_acq_sample == 3333
    returned_stim_sampling_rate = data_file_as_struct['header']['Stimulation']['SampleRate']
    n_timebase_ticks_per_stim_sample = 100e6 / returned_stim_sampling_rate  # should be exactly 3333
    assert n_timebase_ticks_per_stim_sample == 3333


def test_loading_older_file_with_funnier_sampling_rate():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, '29997_Hz_sampling_rate_0p912_0001.h5')
    data_file_as_struct = ws.loadDataFile(file_name, 'raw')
    # The nominal sampling rate was 29997, but the returned
    # sampling rate should be 100e6/3333 for acq, and 100e6/3334
    # for stim.
    returned_acq_sampling_rate = data_file_as_struct['header']['Acquisition']['SampleRate']
    n_timebase_ticks_per_acq_sample = 100e6 / returned_acq_sampling_rate  # should be exactly 3333
    assert n_timebase_ticks_per_acq_sample == 3333
    returned_stim_sampling_rate = data_file_as_struct['header']['Stimulation']['SampleRate']
    n_timebase_ticks_per_stim_sample = 100e6 / returned_stim_sampling_rate  # should be exactly 3333
    assert n_timebase_ticks_per_stim_sample == 3334


def test_loading_newer_file_with_funnier_sampling_rate():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, '29997_Hz_sampling_rate_0p913_0001.h5')
    data_file_as_struct = ws.loadDataFile(file_name, 'raw')
    # The nominal sampling rate was 29997, but the returned
    # sampling rate should be 100e6/3333 for both acq and stim.
    returned_acq_sampling_rate = data_file_as_struct['header']['Acquisition']['SampleRate']
    n_timebase_ticks_per_acq_sample = 100e6 / returned_acq_sampling_rate  # should be exactly 3333
    assert n_timebase_ticks_per_acq_sample == 3333
    returned_stim_sampling_rate = data_file_as_struct['header']['Stimulation']['SampleRate']
    n_timebase_ticks_per_stim_sample = 100e6 / returned_stim_sampling_rate  # should be exactly 3333
    assert n_timebase_ticks_per_stim_sample == 3333


def test_loading_0p74_file():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, 'ws_0p74_data_0001.h5')
    dataAsDict = ws.loadDataFile(file_name, 'raw')  # conversion to scaled data would fail for this file
    acq_sampling_rate = float(dataAsDict['header']['Acquisition']['SampleRate'])
    assert acq_sampling_rate == 20e3
    n_a_i_channels = dataAsDict['header']['Acquisition']['ChannelScales'].size
    assert n_a_i_channels == 4
    n_active_a_i_channels = int(dataAsDict['header']['Acquisition']['IsChannelActive'].sum())
    assert n_active_a_i_channels == 4
    stim_sampling_rate = dataAsDict['header']['Stimulation']['SampleRate']
    assert stim_sampling_rate == 20e3
    x_as_int16 = dataAsDict['trial_0001']
    assert x_as_int16.dtype == 'int16'
    assert np.max(x_as_int16[0]) == 15204
    assert np.min(x_as_int16[0]) == 2
    x = x_as_int16.astype('float64')
    assert np.allclose(x.mean(axis=1), np.array([7603.29115, 7594.2194, 7598.7204, 7594.06135]))


def test_loading_0p933_file():
    this_file_path = os.path.realpath(__file__)
    this_dir_name = os.path.dirname(this_file_path)
    file_name = os.path.join(this_dir_name, 'ws_0p933_data_0001.h5')
    dataAsDict = ws.loadDataFile(file_name)
    acq_sampling_rate = float(dataAsDict['header']['Acquisition']['SampleRate'])
    assert acq_sampling_rate == 20e3
    n_a_i_channels = dataAsDict['header']['Acquisition']['AnalogChannelScales'].size
    assert n_a_i_channels == 1
    n_active_a_i_channels = int(dataAsDict['header']['Acquisition']['IsChannelActive'].sum())
    assert n_active_a_i_channels == 1
    stim_sampling_rate = dataAsDict['header']['Stimulation']['SampleRate']
    assert stim_sampling_rate == 20e3
    x = dataAsDict['sweep_0001']['analogScans']
    assert x.dtype == 'float64'
    assert np.absolute(np.max(x[0]) - 5) < 0.01
    assert np.absolute(np.min(x[0]) - 0) < 0.01
    assert np.allclose(x.mean(axis=1), np.array([2.49962616]))


def test_identity_function_on_vector():
    fs = 20000.0  # Hz
    dt = 1 / fs  # s
    time = 0.2  # s
    n_scans = int(round(time / dt))
    t = dt * np.arange(n_scans)
    x = (0.9 * pow(2, 14) * np.sin(2 * math.pi * 10 * t)).astype('int16').reshape(1, n_scans)
    channel_scale = (np.array(1, ndmin=1)).astype(
        'float64')  # V/whatevers, scale for converting from V to whatever or vice-versa
    adc_coefficients = (np.array([0, 1, 0, 0])).astype('float64').reshape(1, 4)  # identity function
    y_theoretical = x.astype('float64')
    y = ws.scaled_double_analog_data_from_raw(x, channel_scale, adc_coefficients)
    # yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channel_scale, adc_coefficients)
    assert (y_theoretical == y).all()
    # assert y, yMex)


def test_arbitrary_on_vector():
    fs = 20000.0  # Hz
    dt = 1 / fs  # s
    time = 0.2  # s
    n_scans = int(round(time / dt))
    t = dt * np.arange(n_scans)
    x = (0.9 * pow(2, 14) * np.sin(2 * math.pi * 10 * t)).astype('int16').reshape(1, n_scans)
    channel_scale = (np.array(1, ndmin=1)).astype(
        'float64')  # V/whatevers, scale for converting from V to whatever or vice-versa
    adc_coefficients = (np.array([1, 2, 3, 4])).astype('float64').reshape(1, 4)  # identity function
    xf = x.astype('float64')
    y_theoretical = (1.0 + 2.0 * xf + 3.0 * xf * xf + 4.0 * xf * xf * xf)
    y = ws.scaled_double_analog_data_from_raw(x, channel_scale, adc_coefficients)
    # yMex = ws.scaledDoubleAnalogDataFromRawMex(x, channel_scale, adc_coefficients)
    assert (y_theoretical == y).all()
    # assert y, yMex)


def test_arbitrary_on_empty():
    fs = 20000.0  # Hz
    dt = 1 / fs  # s
    time = 0.0  # s
    n_scans = int(round(time / dt))
    t = dt * np.arange(n_scans)
    x = (0.9 * pow(2, 14) * np.sin(2 * math.pi * 10 * t)).astype('int16').reshape(1, n_scans)
    # V/whatevers, scale for converting from V to whatever or vice-versa
    channel_scale = (np.array(1, ndmin=1)).astype('float64')
    adc_coefficients = (np.array([1, 2, 3, 4])).astype('float64').reshape(1, 4)  # identity function
    xf = x.astype('float64')
    y_theoretical = 1.0 + 2.0 * xf + 3.0 * xf * xf + 4.0 * xf * xf * xf
    y = ws.scaled_double_analog_data_from_raw(x, channel_scale, adc_coefficients)
    assert (y_theoretical == y).all()


def test_arbitrary_on_matrix():
    fs = 20000.0  # Hz
    dt = 1 / fs  # s
    time = 0.2  # s
    n_scans = int(round(time / dt))
    n_channels = 6
    i_channel = np.arange(n_channels).reshape(n_channels, 1)
    t = (dt * np.arange(n_scans)).reshape(1, n_scans)
    x = (0.9 * pow(2, 14) * np.sin(2 * math.pi * 10 * t + 2 * math.pi * (i_channel / n_channels))).astype('int16')
    channel_scale = 1 / (i_channel + 1)
    adc_coefficients = np.tile((np.array([1, 2, 3, 4])).astype('float64').reshape(1, 4),
                               (n_channels, 1))  # identity function
    xf = x.astype('float64')
    y_theoretical = (1.0 + 2.0 * xf + 3.0 * xf * xf + 4.0 * xf * xf * xf) / channel_scale
    y = ws.scaled_double_analog_data_from_raw(x, channel_scale, adc_coefficients)
    assert (y_theoretical == y).all()
    # absoluteError = np.absolute(y-y_theoretical)
    # relativeError = np.absolute(y-y_theoretical)/np.absolute(y_theoretical)
    # assert  (np.logical_or(relativeError<1e-6 , absoluteError<1e-6 ) ).all() )


def test_arbitrary_on_zero_channels():
    fs = 20000.0  # Hz
    dt = 1 / fs  # s
    time = 0.2  # s
    n_scans = int(round(time / dt))
    n_channels = 0
    i_channel = np.arange(n_channels).reshape(n_channels, 1)
    t = (dt * np.arange(n_scans)).reshape(1, n_scans)
    x = (0.9 * pow(2, 14) * np.sin(2 * math.pi * 10 * t + 2 * math.pi * (i_channel / n_channels))).astype('int16')
    channel_scale = 1 / (i_channel + 1)
    adc_coefficients = np.tile((np.array([1, 2, 3, 4])).astype('float64').reshape(1, 4),
                               (n_channels, 1))
    xf = x.astype('float64')
    y_theoretical = (1.0 + 2.0 * xf + 3.0 * xf * xf + 4.0 * xf * xf * xf) / channel_scale
    y = ws.scaled_double_analog_data_from_raw(x, channel_scale, adc_coefficients)
    assert (y_theoretical == y).all()


def test_arbitrary_on_matrix_zero_coeffs():
    fs = 20000.0  # Hz
    dt = 1 / fs  # s
    time = 0.2  # s
    n_scans = int(round(time / dt))
    n_channels = 0
    i_channel = np.arange(n_channels).reshape(n_channels, 1)
    t = (dt * np.arange(n_scans)).reshape(1, n_scans)
    x = (0.9 * pow(2, 14) * np.sin(2 * math.pi * 10 * t + 2 * math.pi * (i_channel / n_channels))).astype('int16')
    channel_scale = 1 / (i_channel + 1)
    adc_coefficients = np.zeros((n_channels, 0))
    y_theoretical = np.zeros(x.shape)
    y = ws.scaled_double_analog_data_from_raw(x, channel_scale, adc_coefficients)
    assert (y_theoretical == y).all()


def test_arbitrary_on_matrix_one_coeff():
    fs = 20000.0  # Hz
    dt = 1 / fs  # s
    time = 0.2  # s
    n_scans = int(round(time / dt))
    n_channels = 6
    i_channel = np.arange(n_channels).reshape(n_channels, 1)
    t = (dt * np.arange(n_scans)).reshape(1, n_scans)
    x = (0.9 * pow(2, 14) * np.sin(2 * math.pi * 10 * t + 2 * math.pi * (i_channel / n_channels))).astype('int16')
    channel_scale = 1 / (i_channel + 1)
    # adc_coefficients = np.tile((np.array([1, 2, 3, 4])).astype('float64').reshape(1, 4), (n_channels,1))
    adc_coefficients = np.tile(0.001, (n_channels, 1))
    # xf = x.astype('float64')
    y_theoretical = np.tile(0.001, (n_channels, n_scans)) / channel_scale
    y = ws.scaled_double_analog_data_from_raw(x, channel_scale, adc_coefficients)
    assert (y_theoretical == y).all()


def test_arbitrary_on_matrix_two_coeffs():
    fs = 20000.0  # Hz
    dt = 1 / fs  # s
    time = 0.2  # s
    n_scans = int(round(time / dt))
    n_channels = 3
    i_channel = np.arange(n_channels).reshape(n_channels, 1)
    t = (dt * np.arange(n_scans)).reshape(1, n_scans)
    x = (0.9 * pow(2, 14) * np.sin(2 * math.pi * 10 * t + 2 * math.pi * (i_channel / n_channels))).astype('int16')
    channel_scale = 1 / (i_channel + 1)
    # adc_coefficients = np.tile((np.array([1, 2, 3, 4])).astype('float64').reshape(1, 4), (n_channels,1))
    # adc_coefficients = np.tile(0.001, (n_channels, 1))
    adc_coefficients = np.array([[0.0, 1.0],
                                 [0.0, 1.0],
                                 [0.0, 1.0]])
    y_theoretical = x / channel_scale
    y = ws.scaled_double_analog_data_from_raw(x, channel_scale, adc_coefficients)
    assert y.dtype == 'float64'
    assert (y_theoretical == y).all()


def test_arbitrary_on_matrix_two_coeffs_single():
    fs = 20000.0  # Hz
    dt = 1 / fs  # s
    time = 0.2  # s
    n_scans = int(round(time / dt))
    n_channels = 3
    i_channel = np.arange(n_channels).reshape(n_channels, 1)
    t = (dt * np.arange(n_scans)).reshape(1, n_scans)
    x = (0.9 * pow(2, 14) * np.sin(2 * math.pi * 10 * t + 2 * math.pi * (i_channel / n_channels))).astype('int16')
    channel_scale = 1 / (i_channel + 1)
    # adc_coefficients = np.tile((np.array([1, 2, 3, 4])).astype('float64').reshape(1, 4), (n_channels,1))
    # adc_coefficients = np.tile(0.001, (n_channels, 1))
    adc_coefficients = np.array([[0.0, 1.0],
                                 [0.0, 1.0],
                                 [0.0, 1.0]])
    y_theoretical = x / channel_scale
    y = ws.scaled_single_analog_data_from_raw(x, channel_scale, adc_coefficients)
    assert y.dtype == 'float32'
    assert (y_theoretical == y).all()
