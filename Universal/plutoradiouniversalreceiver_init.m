function SimParams = plutoradiouniversalreceiver_init(Rsym, modulation, freq, gain, r_off, varargin)
%PLUTORADIOUNIVERSALRECEIVER_INIT Build parameter struct for receiver.
%
%   SimParams = plutoradiouniversalreceiver_init(...) mirrors the
%   transmitter initialisation and provides the configuration structure
%   required by runPlutoradioUniversalReceiver.
%
% Copyright 2017-2023 The MathWorks, Inc.

p = inputParser;
p.addParameter('Interpolation', 2, @(x)isscalar(x) && x>0);
p.addParameter('Decimation', 1, @(x)isscalar(x) && x>0);
p.addParameter('NumberOfMessage', 100, @(x)isscalar(x) && x>0);
p.addParameter('Message', 'Hello world', @(x)ischar(x) || (isstring(x) && isscalar(x)));
p.addParameter('StopTime', 10, @(x)isscalar(x) && x>0);
p.addParameter('Preview', false, @(x)islogical(x) && isscalar(x));
p.parse(varargin{:});
params = p.Results;

cfg = helperModulationConfig(modulation);

SimParams.Rsym = Rsym;
SimParams.ModulationOrder = cfg.ModulationOrder;
SimParams.Modulation = cfg.Name;
SimParams.Interpolation = params.Interpolation;
SimParams.Decimation = params.Decimation;
SimParams.Tsym = 1/SimParams.Rsym;
SimParams.Fs   = SimParams.Rsym * SimParams.Interpolation;

SimParams.BarkerCode      = [+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1];
SimParams.BarkerLength    = length(SimParams.BarkerCode);
rawHeaderLength           = SimParams.BarkerLength * 2;
headerSymbols             = ceil(rawHeaderLength / cfg.BitsPerSymbol);
SimParams.HeaderLength    = headerSymbols * cfg.BitsPerSymbol;
SimParams.HeaderPadBits   = SimParams.HeaderLength - rawHeaderLength;
SimParams.Message         = char(params.Message);
SimParams.MessageLength   = length(SimParams.Message) + 5;
SimParams.NumberOfMessage = params.NumberOfMessage;
SimParams.PayloadLength   = SimParams.NumberOfMessage * SimParams.MessageLength * 7;
SimParams.FrameBits       = SimParams.HeaderLength + SimParams.PayloadLength;
SimParams.FrameSize       = ceil(SimParams.FrameBits / cfg.BitsPerSymbol);
SimParams.FrameBits       = SimParams.FrameSize * cfg.BitsPerSymbol;
SimParams.FramePadding    = SimParams.FrameBits - (SimParams.HeaderLength + SimParams.PayloadLength);
SimParams.FrameTime       = SimParams.Tsym*SimParams.FrameSize;
SimParams.BitsPerSymbol      = cfg.BitsPerSymbol;

SimParams.RolloffFactor     = r_off;
SimParams.ScramblerBase     = 2;
SimParams.ScramblerPolynomial           = [1 1 1 0 1];
SimParams.ScramblerInitialConditions    = [0 0 0 0];
SimParams.RaisedCosineFilterSpan = 10;
SimParams.DesiredPower                  = 2;
SimParams.AveragingLength               = 50;
SimParams.MaxPowerGain                  = 60;
SimParams.MaximumFrequencyOffset        = 6e3;
SimParams.PhaseRecoveryLoopBandwidth    = 0.01;
SimParams.PhaseRecoveryDampingFactor    = 1;
SimParams.TimingRecoveryLoopBandwidth   = 0.01;
SimParams.TimingRecoveryDampingFactor   = 1;
SimParams.TimingErrorDetectorGain       = 5.4;
SimParams.PreambleDetectionThreshold    = 0.8;

msgSet = zeros(SimParams.NumberOfMessage * SimParams.MessageLength, 1);
for msgCnt = 0 : SimParams.NumberOfMessage - 1
    msgSet(msgCnt * SimParams.MessageLength + (1 : SimParams.MessageLength)) = ...
        sprintf('%s %03d\n', SimParams.Message, mod(msgCnt, 100));
end
bits = de2bi(msgSet, 7, 'left-msb')';
SimParams.MessageBits = bits(:);

SimParams.BerMask = zeros(SimParams.NumberOfMessage * length(SimParams.Message) * 7, 1);
for i = 1 : SimParams.NumberOfMessage
    SimParams.BerMask( (i-1) * length(SimParams.Message) * 7 + ( 1: length(SimParams.Message) * 7) ) = ...
        (i-1) * SimParams.MessageLength * 7 + (1: length(SimParams.Message) * 7);
end
SimParams.PlutoCenterFrequency      = freq;
SimParams.PlutoGain                 = gain;
SimParams.PlutoFrontEndSampleRate   = SimParams.Fs;
SimParams.PlutoFrameLength          = SimParams.Interpolation * SimParams.FrameSize;

SimParams.PlutoFrameTime = SimParams.PlutoFrameLength / SimParams.PlutoFrontEndSampleRate;
SimParams.StopTime = params.StopTime;
SimParams.Preview = params.Preview;
end
