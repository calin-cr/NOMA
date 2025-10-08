function runPlutoradioUniversalTransmitter(prmUniversalTransmitter)
%#codegen
%RUNPLUTORADIOUNIVERSALTRANSMITTER Stream frames to the ADALM-PLUTO radio.
%
%   This function mirrors runPlutoradioQPSKTransmitter but relies on the
%   modulation-aware UniversalTransmitter System object.
%
% Copyright 2017-2023 The MathWorks, Inc.

persistent hTx radio
if coder.target('MATLAB')
    cleanupObj = onCleanup(@()cleanupTransmitter()); %#ok<NASGU>
else
    cleanupObj = []; %#ok<NASGU>
end

if isempty(hTx) || ~isvalid(hTx)
    cfg = helperModulationConfig(prmUniversalTransmitter.ModulationOrder);
    hTx = UniversalTransmitter(...
        'ModulationOrder',              cfg.ModulationOrder, ...
        'HeaderLength',                prmUniversalTransmitter.HeaderLength, ...
        'PayloadLength',               prmUniversalTransmitter.PayloadLength, ...
        'FrameBits',                   prmUniversalTransmitter.FrameBits, ...
        'UpsamplingFactor',             prmUniversalTransmitter.Interpolation, ...
        'RolloffFactor',                prmUniversalTransmitter.RolloffFactor, ...
        'RaisedCosineFilterSpan',       prmUniversalTransmitter.RaisedCosineFilterSpan, ...
        'MessageBits',                  prmUniversalTransmitter.MessageBits, ...
        'MessageLength',                prmUniversalTransmitter.MessageLength, ...
        'NumberOfMessage',              prmUniversalTransmitter.NumberOfMessage, ...
        'ScramblerBase',                prmUniversalTransmitter.ScramblerBase, ...
        'ScramblerPolynomial',          prmUniversalTransmitter.ScramblerPolynomial, ...
        'ScramblerInitialConditions',   prmUniversalTransmitter.ScramblerInitialConditions);

    radio = sdrtx('Pluto');
    radio.RadioID               = prmUniversalTransmitter.Address;
    radio.CenterFrequency       = prmUniversalTransmitter.PlutoCenterFrequency;
    radio.BasebandSampleRate    = prmUniversalTransmitter.PlutoFrontEndSampleRate;
    radio.SamplesPerFrame       = prmUniversalTransmitter.PlutoFrameLength;
    radio.Gain                  = prmUniversalTransmitter.PlutoGain;
end

currentTime = 0;
disp('Transmission has started')

while currentTime < prmUniversalTransmitter.StopTime
    data = step(hTx);
    step(radio, data);
    currentTime = currentTime + prmUniversalTransmitter.FrameTime;
end

if currentTime ~= 0
    disp('Transmission has ended')
end

if ~coder.target('MATLAB')
    cleanupTransmitter();
end

    function cleanupTransmitter()
        if ~isempty(hTx) && isvalid(hTx)
            release(hTx);
        end
        hTx = [];

        if ~isempty(radio) && isvalid(radio)
            release(radio);
        end
        radio = [];
    end

end
