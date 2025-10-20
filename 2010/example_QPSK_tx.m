clear all

%Params
Rsym=0.2e6;
mod=4;
freq=915e6;
gain=0;
r_off=0.5;

% Transmitter parameter structure
prmQPSKTransmitter = plutoradioqpsktransmitter_init(Rsym, mod, freq, gain, r_off);
% Specify Radio ID
prmQPSKTransmitter.Address = 'usb:1'



runPlutoradioQPSKTransmitter(prmQPSKTransmitter);



