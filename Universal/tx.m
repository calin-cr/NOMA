%% Universal transmitter script
% Configure the transmitter parameters here. The receiver must use the same
% settings (symbol rate, modulation, frequency, roll-off factor and gain)
% for a successful experiment. Run this script before Universal/rx.m.

clear;

% Parameters (edit to match your setup)
Rsym        = 0.3e6;             % Symbol rate [Hz]
modulation  = 'QPSK';            % BPSK | QPSK | 8PSK | 16QAM | 64QAM
centerFreq  = 915e6;             % RF centre frequency [Hz]
outputGain  = -10;               % Transmit gain [dB]
rolloff     = 0.5;               % Raised cosine roll-off factor
stopTime    = 10;                % Transmission duration [s]

% Build transmitter parameters
prmTx = plutoradiouniversaltransmitter_init(Rsym, modulation, centerFreq, ...
    outputGain, rolloff, 'StopTime', stopTime);
prmTx.Address = 'usb:0';

% Start the transmission
runPlutoradioUniversalTransmitter(prmTx);
