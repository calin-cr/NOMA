function p = getParameters()
p.CenterFrequency = 2.45e9;      % Hz
p.SampleRate      = 1e6;         % samples/sec
p.SymbolRate      = 250e3;       % symbols/sec
p.FrameSize = 4096;   % samples per read from Pluto

p.Modulation      = 'QPSK';      % 'QPSK' or 'QAM'
p.ModulationOrder = 4;           % 4 for QPSK, 16/64/... for QAM
p.TxGain          = -10;         % dB
p.RxGain          = 10;          % dB
p.FrameSymbols    = 2000;        % per frame
p.BERFile         = 'ber_results.mat';
p.RefBitsFile     = 'tx_ref.mat';

p.SamplesPerSymbol = 4;      % integer oversampling factor
p.FilterSpan       = 10;     % in symbols
p.Rolloff          = 0.35;

p.EnableSync = true;   % enable for real hardware
end
