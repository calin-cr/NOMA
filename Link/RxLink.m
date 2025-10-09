%% RxLink.m -- Minimal launcher for the ADALM-PLUTO receiver
% Configure the receiver parameters and call |runLinkReceiver|.  The helper
% function performs synchronization, demodulation, and BER evaluation while
% this script only displays the key configuration and measurement results.

prm = defaultLinkParameters();

% Customize the receiver session ------------------------------------------------
prm.common.modulation       = "QPSK";
prm.common.symbolRate       = 500e3;
prm.common.samplesPerSymbol = 8;
prm.common.frameLength      = 2048;
prm.common.rolloff          = 0.35;
prm.common.filterSpan       = 10;
prm.common.randomSeed       = 2024;

prm.rx.radioID             = "usb:0";
prm.rx.centerFrequency     = 2.45e9;
prm.rx.gain                = 30;
prm.rx.stopAfterFrames     = 200; % Set to Inf to keep receiving
prm.rx.constellationFrames = 4;
prm.rx.enablePlots         = true;

% Launch the receiver -----------------------------------------------------------------
stats = runLinkReceiver(prm.rx, prm.common);

fprintf("\nReception summary\n");
fprintf("  Frames processed : %d\n", stats.framesProcessed);
fprintf("  Bits compared    : %d\n", stats.bitsCompared);
fprintf("  Bit errors       : %d\n", stats.bitErrors);
fprintf("  BER              : %.3g\n", stats.ber);
