function SimParams = plutoradioqpsktransmitter_init(Rsym, mod, freq, gain, r_off)
% Initialization of transmitter parameters for Pluto NOMA QPSK
% Copyright 2017-2025 The MathWorks, Inc.

%% General parameters
SimParams.Rsym = Rsym;                     % Symbol rate in Hertz
SimParams.ModulationOrder = mod;           % QPSK alphabet size
SimParams.Interpolation = 2;               % Upsampling
SimParams.Decimation = 1;
SimParams.Tsym = 1/SimParams.Rsym;
SimParams.Fs   = SimParams.Rsym * SimParams.Interpolation;

%% Frame Specifications
SimParams.BarkerCode      = [+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1];
SimParams.BarkerLength    = length(SimParams.BarkerCode);
SimParams.HeaderLength    = SimParams.BarkerLength * 2;

% Common parameters
SimParams.NumberOfMessage = 100;
SimParams.RolloffFactor   = r_off;
SimParams.RaisedCosineFilterSpan = 10;

%% ---- User-specific messages ----
SimParams.MessageUser1 = 'HELLO WORLD';  % Near user (strong)
SimParams.MessageUser2 = 'hello world';  % Far user (weak)

SimParams.MessageLength = length(SimParams.MessageUser1) + 5;  % 'HELLO WORLD 000\n'

% ---- User 1 bits ----
msgSet1 = zeros(SimParams.NumberOfMessage * SimParams.MessageLength, 1);
for msgCnt = 0 : SimParams.NumberOfMessage-1
    msgSet1(msgCnt * SimParams.MessageLength + (1:SimParams.MessageLength)) = ...
        sprintf('%s %03d\n', SimParams.MessageUser1, msgCnt);
end
bits1 = de2bi(msgSet1, 7, 'left-msb')';
SimParams.MessageBitsUser1 = bits1(:);

% ---- User 2 bits ----
msgSet2 = zeros(SimParams.NumberOfMessage * SimParams.MessageLength, 1);
for msgCnt = 0 : SimParams.NumberOfMessage-1
    msgSet2(msgCnt * SimParams.MessageLength + (1:SimParams.MessageLength)) = ...
        sprintf('%s %03d\n', SimParams.MessageUser2, msgCnt);
end
bits2 = de2bi(msgSet2, 7, 'left-msb')';
SimParams.MessageBitsUser2 = bits2(:);

%% Scrambler and radio parameters
SimParams.ScramblerBase              = 2;
SimParams.ScramblerPolynomial        = [1 1 1 0 1];
SimParams.ScramblerInitialConditions = [0 0 0 0];

SimParams.PlutoCenterFrequency      = freq;
SimParams.PlutoGain                 = gain;
SimParams.PlutoFrontEndSampleRate   = SimParams.Fs;
SimParams.PlutoFrameLength          = SimParams.Interpolation * ...
                                       ((SimParams.HeaderLength + ...
                                       SimParams.NumberOfMessage * ...
                                       SimParams.MessageLength * 7) / log2(SimParams.ModulationOrder));

SimParams.FrameTime = SimParams.PlutoFrameLength / SimParams.PlutoFrontEndSampleRate;
SimParams.StopTime  = 1000;
end
