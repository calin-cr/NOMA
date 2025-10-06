clear all

%% QPSK Transmitter and Receiver Combined Example
% This script centralizes the setup of both the transmitter and receiver
% so that a single run configures the end-to-end link. Update the
% parameters below to suit your experiment before executing the script.

%% Shared Parameters
centerFrequency = 915e6; % Hz
constellationOrder = 4;  % QPSK

%% Transmitter Parameters
symbolRateTx = 0.3e6;    % Hz
txGain = 0;              % dB
rfOff = 0.5;             % MHz frequency offset for calibration
transmitterRadioID = 'usb:1';

%% Receiver Parameters
symbolRateRx = 0.25e6;   % Hz
rxGain = 10;             % dB
numberOfCaptures = 10;   % Number of bursts to capture
receiverRadioID = 'usb:0';
printReceivedData = false; % true to print decoded bits per capture

%% Launch Transmitter
prmQPSKTransmitter = plutoradioqpsktransmitter_init(symbolRateTx, ...
    constellationOrder, centerFrequency, txGain, rfOff);
prmQPSKTransmitter.Address = transmitterRadioID;

runPlutoradioQPSKTransmitter(prmQPSKTransmitter);

%% Launch Receiver
for sampleNum = 1:numberOfCaptures
    prmQPSKReceiver = plutoradioqpskreceiver_init(symbolRateRx, ...
        constellationOrder, centerFrequency, rxGain);
    prmQPSKReceiver.Address = receiverRadioID;

    BER = runPlutoradioQPSKReceiver(prmQPSKReceiver, printReceivedData, sampleNum);

    fprintf('Capture %d/%d:\n', sampleNum, numberOfCaptures);
    fprintf('  Error rate              = %f\n', BER(1));
    fprintf('  Number of detected errors = %d\n', BER(2));
    fprintf('  Total compared samples  = %d\n\n', BER(3));
end
