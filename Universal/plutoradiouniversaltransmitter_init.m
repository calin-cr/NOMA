function SimParams = plutoradiouniversaltransmitter_init(Rsym, modulation, freq, gain, r_off, varargin)
%PLUTORADIOUNIVERSALTRANSMITTER_INIT Build parameter struct for transmitter.
%
%   SimParams = plutoradiouniversaltransmitter_init(Rsym, modulation, freq,
%   gain, r_off) creates a configuration structure compatible with the
%   Universal transmitter/receiver pair. The modulation argument can be the
%   modulation order (2, 4, 8, 16, 64) or a string identifying the scheme
%   ('bpsk','qpsk','8psk','16qam','64qam'). Optional name-value pairs allow
%   overriding the default interpolation factor, stop time, and number of
%   payload messages per frame.
%
%   Supported name-value pairs:
%       'Interpolation'        (default 2)
%       'NumberOfMessage'      (default 100)
%       'Message'              (default 'Hello world')
%       'StopTime'             (default 1000)
%
% Copyright 2017-2023 The MathWorks, Inc.

p = inputParser;
p.addParameter('Interpolation', 2, @(x)isscalar(x) && x>0);
p.addParameter('NumberOfMessage', 100, @(x)isscalar(x) && x>0);
p.addParameter('Message', 'Hello world', @(x)ischar(x) || (isstring(x) && isscalar(x)));
p.addParameter('StopTime', 1000, @(x)isscalar(x) && x>0);
p.parse(varargin{:});
params = p.Results;

cfg = helperModulationConfig(modulation);

SimParams.Rsym = Rsym;
SimParams.ModulationOrder = cfg.ModulationOrder;
SimParams.Modulation = cfg.Name;
SimParams.Interpolation = params.Interpolation;
SimParams.Decimation = 1;
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

msgSet = zeros(SimParams.NumberOfMessage * SimParams.MessageLength, 1);
for msgCnt = 0 : SimParams.NumberOfMessage - 1
    msgSet(msgCnt * SimParams.MessageLength + (1 : SimParams.MessageLength)) = ...
        sprintf('%s %03d\n', SimParams.Message, mod(msgCnt, 100));
end
bits = de2bi(msgSet, 7, 'left-msb')';
SimParams.MessageBits = bits(:);

SimParams.PlutoCenterFrequency      = freq;
SimParams.PlutoGain                 = gain;
SimParams.PlutoFrontEndSampleRate   = SimParams.Fs;
SimParams.PlutoFrameLength          = SimParams.Interpolation * SimParams.FrameSize;

SimParams.FrameTime = SimParams.PlutoFrameLength/SimParams.PlutoFrontEndSampleRate;
SimParams.StopTime  = params.StopTime;
end
