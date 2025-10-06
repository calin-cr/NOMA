%% Universal receiver script
% Configure the parameters to match Universal/tx.m, run the transmitter
% first and then execute this script to collect the received frames.

clear;

% Parameters (must match the transmitter)
Rsym        = 0.3e6;             % Symbol rate [Hz]
modulation  = 'QPSK';            % BPSK | QPSK | 8PSK | 16QAM | 64QAM
centerFreq  = 915e6;             % RF centre frequency [Hz]
manualGain  = 10;                % Receiver gain [dB]
rolloff     = 0.5;               % Raised cosine roll-off factor
stopTime    = 10;                % Capture duration [s]
N_samples   = 5;                 % Number of repeated captures

resultsFile = 'experiment_results.mat';

for samplenum = 1:N_samples
    prmRx = plutoradiouniversalreceiver_init(Rsym, modulation, centerFreq, ...
        manualGain, rolloff, 'StopTime', stopTime);
    prmRx.Address = 'usb:0';

    printReceivedData = false;
    BER = runPlutoradioUniversalReceiver(prmRx, printReceivedData, samplenum);

    fprintf('Error rate = %f.\n', BER(1));
    fprintf('Detected errors = %d.\n', BER(2));
    fprintf('Compared samples = %d.\n', BER(3));

    logResults(resultsFile, Rsym, modulation, centerFreq, manualGain, BER);
end
