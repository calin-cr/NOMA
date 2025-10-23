clear all; clc;

%% ---- Receiver and system parameters ----
Rsym = 0.3e6;                 % Symbol rate (Hz)
mod = 4;                      % QPSK
freq = 915e6;                 % Center frequency (Hz)
gain = 10;                    % Pluto RX gain (adjust as needed)
r_off = 0.5;                  % Raised cosine roll-off

% Load transmitter system parameters for consistency
SimParams = plutoradioqpsktransmitter_init(Rsym, mod, freq, 0, r_off);

rxSampleRate = SimParams.Fs;             % 0.6e6
samplesPerFrame = 4096;                  % SDR buffer length
captureTime = SimParams.FrameTime * 4;   % capture about 4 frames
frames = round(captureTime * rxSampleRate / samplesPerFrame);

fprintf('Sample rate: %.1f Hz\n', rxSampleRate);
fprintf('Capturing %.2f seconds (≈ %d frames)\n', captureTime, frames);

%% ---- Configure Pluto SDR ----
rx = sdrrx('Pluto');
rx.RadioID = 'usb:0';                % Adjust if multiple devices
rx.CenterFrequency = freq;
rx.BasebandSampleRate = rxSampleRate;
rx.SamplesPerFrame = samplesPerFrame;
rx.OutputDataType = 'double';
rx.GainSource = 'Manual';
rx.Gain = gain;
rx.ChannelMapping = 1;

%% ---- Preallocate receive buffer ----
totalSamples = samplesPerFrame * frames;
rxData = complex(zeros(totalSamples,1));

disp('Receiving and saving baseband samples...');

%% ---- Data capture ----
idx = 1;
for k = 1:frames
    y = rx();
    rxData(idx:idx+samplesPerFrame-1) = y;
    idx = idx + samplesPerFrame;
end

disp('Capture complete.');

%% ---- Optional receive filter (recommended) ----
rxFilter = comm.RaisedCosineReceiveFilter( ...
    'RolloffFactor', r_off, ...
    'FilterSpanInSymbols', SimParams.RaisedCosineFilterSpan, ...
    'InputSamplesPerSymbol', SimParams.Interpolation, ...
    'DecimationFactor', 1);

rxDataFiltered = rxFilter(rxData);
rxDataFiltered = rxDataFiltered / rms(rxDataFiltered);  % normalize

%% ---- Save to file for offline analysis ----
save('NOMA_QPSK_rxData.mat','rxData','rxDataFiltered','SimParams','-v7.3');

release(rx);

disp('Data saved to NOMA_QPSK_rxData.mat');
