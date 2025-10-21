%% rxNear.m
% Capture a "near user" dataset for the two-user NOMA experiment.
% Run this script from MATLAB after starting the NOMA transmitter.

%% User-configurable parameters
Rsym   = 1e6;        % Symbol rate (Hz)
modOrd = 4;          % QPSK
fc     = 2.45e9;     % Center frequency (Hz)
rxGain = 30;         % Pluto RX gain (dB)
rolloff = 0.35;      % RRC roll-off
verboseDiagnostics = false; % Set true to print per-frame metrics
captureDuration = 5; % Seconds of data to log
plutoAddress = 'usb:0';

captureFilename = fullfile(pwd, 'nearuser.mat');
transmitLogFile = fullfile(pwd, 'noma_tx_log.mat');

%% Build receiver configuration
prmQPSKReceiver = plutoradioqpskreceiver_init(Rsym, modOrd, fc, rxGain, ...
    rolloff, verboseDiagnostics);
prmQPSKReceiver.Address = plutoAddress;
prmQPSKReceiver.StopTime = captureDuration;
prmQPSKReceiver.LogCaptures = true;
prmQPSKReceiver.CaptureFilename = captureFilename;
prmQPSKReceiver.CaptureScenario = 'near';
prmQPSKReceiver.EnablePreview = true;

%% Propagate the power allocation from the transmit log when available
if exist(transmitLogFile, 'file')
    txLog = load(transmitLogFile, 'nomaLog');
    if isfield(txLog, 'nomaLog') && isfield(txLog.nomaLog, 'PowerAllocation')
        prmQPSKReceiver.PowerAllocation = txLog.nomaLog.PowerAllocation(:).';
    end
end

%% Run capture
fprintf('Starting near-user capture (logging to %s)\n', captureFilename);
printReceivedData = false;
samplenum = 1;
BER = runPlutoradioQPSKReceiver(prmQPSKReceiver, printReceivedData, samplenum);

fprintf('Near-user capture complete. BER: %g (errors: %d over %d bits)\n', ...
    BER(1), BER(2), BER(3));
