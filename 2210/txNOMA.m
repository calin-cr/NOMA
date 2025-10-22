%% txNOMA.m
% Two-user QPSK NOMA transmitter for the ADALM-Pluto example testbed.
%
% Run this script to stream a composite waveform that superimposes two
% Barker-framed QPSK users with configurable power allocation. The script
% reuses the existing helper configuration (`plutoradioqpsktransmitter_init`)
% and the `QPSKTransmitter_NOMA` System object so that it is fully compatible
% with the original single-user pipeline.
%
% Execute the complementary `rxNOMA.m` script on the receiver side to log
% captures for the "strong" and "weak" user experiments before processing
% them with `NOMA_OfflineDecode.m`.

clear; clc;

%% User-selectable experiment parameters
messageUser1   = "Hello world";   % Higher-power (weak) user payload
messageUser2   = "Chao world";    % Lower-power (strong) user payload
powerUser1     = 0.8;             % Must be greater than powerUser2
powerUser2     = 0.2;             % powerUser1 + powerUser2 must equal 1
captureDuration = 5;              % Seconds to transmit

% Validate NOMA power split before proceeding
if abs((powerUser1 + powerUser2) - 1) > 1e-6
    error('txNOMA:InvalidPowerSplit', 'Power coefficients must sum to one.');
end
if powerUser1 <= powerUser2
    error('txNOMA:InvalidOrdering', 'powerUser1 must be greater than powerUser2.');
end

%% RF and waveform configuration (reuse legacy helper)
Rsym  = 0.2e6;         % Symbol rate (Hz)
M     = 4;             % QPSK
fc    = 915e6;         % Center frequency (Hz)
txGain = 0;            % Pluto transmit gain (dB)
rolloff = 0.5;         % Raised cosine roll-off
radioID = 'usb:1';     % Update to match your transmitter Pluto enumerated ID

prmTx = plutoradioqpsktransmitter_init(Rsym, M, fc, txGain, rolloff);
prmTx.Address  = radioID;
prmTx.StopTime = captureDuration;

%% Instantiate the composite NOMA transmitter
nomaTx = QPSKTransmitter_NOMA( ...
    'UpsamplingFactor',           prmTx.Interpolation, ...
    'RolloffFactor',              prmTx.RolloffFactor, ...
    'RaisedCosineFilterSpan',     prmTx.RaisedCosineFilterSpan, ...
    'ScramblerBase',              prmTx.ScramblerBase, ...
    'ScramblerPolynomial',        prmTx.ScramblerPolynomial, ...
    'ScramblerInitialConditions', prmTx.ScramblerInitialConditions, ...
    'NumberOfMessages',           prmTx.NumberOfMessage, ...
    'Message1',                   messageUser1, ...
    'Message2',                   messageUser2, ...
    'PowerUser1',                 powerUser1, ...
    'PowerUser2',                 powerUser2);

%% Configure the Pluto SDR front-end
radio = sdrtx('Pluto');
radio.RadioID            = prmTx.Address;
radio.CenterFrequency    = prmTx.PlutoCenterFrequency;
radio.BasebandSampleRate = prmTx.PlutoFrontEndSampleRate;
radio.SamplesPerFrame    = prmTx.PlutoFrameLength;
radio.Gain               = prmTx.PlutoGain;

numFrames = ceil(prmTx.StopTime / prmTx.FrameTime);

fprintf('Starting NOMA transmission (%d frames, %.2f seconds)\n', ...
    numFrames, numFrames * prmTx.FrameTime);

%% Continuous streaming loop
for frameIdx = 1:numFrames
    txFrame = step(nomaTx);
    step(radio, txFrame);
end

fprintf('Transmission complete.\n');

%% Clean up hardware resources
release(nomaTx);
release(radio);
