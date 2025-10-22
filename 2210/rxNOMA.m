%% rxNOMA.m
% Two-user QPSK NOMA capture script for the ADALM-Pluto receiver.
%
% Run this script twice to log "strong" (high SNR) and "weak" (low SNR)
% captures that can be processed later by `NOMA_OfflineDecode.m`. Position
% or attenuate the radios appropriately between runs and change the
% `captureLabel` variable to switch between `rxStrong.mat` and `rxWeak.mat`
% outputs.

clear; clc;

%% User-selectable experiment parameters
captureLabel    = 'Strong';  % Use 'Weak' for the low-SNR experiment
captureDuration = 5;         % Seconds of samples to log per run
rxGain          = 10;        % Pluto manual gain setting (dB)
radioID         = 'usb:0';   % Update to the receiver Pluto's ID

%% Waveform/RF configuration (must match transmitter)
Rsym    = 0.2e6;   % Symbol rate (Hz)
M       = 4;       % QPSK
fc      = 915e6;   % Center frequency (Hz)
rolloff = 0.5;     % Raised cosine roll-off

%% Build the receiver parameter structure and override runtime options
prmRx = plutoradioqpskreceiver_init(Rsym, M, fc, rxGain, rolloff, false);
prmRx.Address  = radioID;
prmRx.StopTime = captureDuration;

%% Configure the Pluto SDR source
radio = sdrrx('Pluto');
radio.RadioID            = prmRx.Address;
radio.CenterFrequency    = prmRx.PlutoCenterFrequency;
radio.BasebandSampleRate = prmRx.PlutoFrontEndSampleRate;
radio.SamplesPerFrame    = prmRx.PlutoFrameLength;
radio.GainSource         = 'Manual';
radio.Gain               = prmRx.PlutoGain;
radio.OutputDataType     = 'double';

samplesPerFrame = radio.SamplesPerFrame;
numFrames = ceil(prmRx.StopTime / prmRx.PlutoFrameTime);

fprintf('Starting NOMA capture (%s user): %d frames, %.2f seconds\n', ...
    captureLabel, numFrames, numFrames * prmRx.PlutoFrameTime);

captureBuffer = complex(zeros(samplesPerFrame * numFrames, 1));

for frameIdx = 1:numFrames
    frame = radio();
    idx = (frameIdx-1) * samplesPerFrame + (1:samplesPerFrame);
    captureBuffer(idx) = frame;
end

fprintf('Capture complete.\n');

%% Persist the raw complex baseband samples for offline SIC
variableName = ['y' captureLabel];
fileName = ['rx' captureLabel '.mat'];

captureStruct.(variableName) = captureBuffer;
save(fileName, '-struct', 'captureStruct', '-v7.3');

fprintf('Saved %d samples to %s (%s variable).\n', numel(captureBuffer), fileName, variableName);

%% Release hardware resources
release(radio);
