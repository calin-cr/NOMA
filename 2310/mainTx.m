clear all; clc;

% Parameters
Rsym = 0.3e6;
mod = 4;
freq = 915e6;
gain = 0;
r_off = 0.5;

% Initialize parameters
prmQPSKTransmitter = plutoradioqpsktransmitter_init(Rsym, mod, freq, gain, r_off);

% Assign device address
prmQPSKTransmitter.Address = 'usb:1';  

% Run transmitter
runPlutoradioQPSKTransmitter(prmQPSKTransmitter);
