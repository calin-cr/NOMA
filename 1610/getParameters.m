function p = getParameters()
%GETPARAMETERS Standard configuration shared by TX and RX.
%   Edit this file to adjust the centre frequency, rates or modulation
%   order.  All of the helper functions in this folder expect the fields
%   defined here to be present.

p.CenterFrequency = 2.45e9;      % Hz
p.SymbolRate      = 250e3;       % symbols/sec
p.SamplesPerSymbol = 4;          % integer oversampling factor
p.SampleRate      = p.SymbolRate * p.SamplesPerSymbol; % samples/sec

p.Modulation      = 'QPSK';      % 'QPSK' or 'QAM'
p.ModulationOrder = 4;           % 4 for QPSK, 16/64/... for QAM
p.Rolloff         = 0.35;
p.FilterSpan      = 10;          % in symbols

% Gain settings (adjust for your lab environment)
p.TxGain          = -10;         % dB
p.RxGain          =  10;         % dB
p.TxDuration      = 60;          % seconds for transmitRepeat

% Frame configuration
p.PayloadSymbols   = 2000;        % random data symbols per frame
p.PreambleSymbols  = 64;         % deterministic symbols for synchronisation
p.NumRxFrames      = 20;         % number of frames to capture per run
p.NumDiscardFrames = 3;          % warm-up reads before logging

% Derived sizes
p.FrameSymbols = p.PreambleSymbols + p.PayloadSymbols;
p.FrameSamples = p.FrameSymbols * p.SamplesPerSymbol;
p.FilterDelaySamples = p.FilterSpan * p.SamplesPerSymbol / 2; % per filter
p.SamplesPerFrame = p.FrameSamples;

% File logging
p.BERFile         = 'ber_results.mat';
p.RefBitsFile     = 'tx_ref.mat';

% Synchronisation helpers
p.EnableSync      = true;        % enable for over-the-air hardware

% Plotting
p.EnablePlots     = true;
end
