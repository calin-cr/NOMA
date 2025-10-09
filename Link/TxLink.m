%% TxLink.m -- Minimal launcher for the ADALM-PLUTO transmitter
% Configure the transmitter parameters and call |runLinkTransmitter| to
% generate and stream frames.  All heavy processing is implemented inside
% helper functions so that this script mirrors the concise style of the
% original QPSK examples.

prm = defaultLinkParameters();

% Customize the transmitter session ------------------------------------------------
% Adjust the following fields to match your setup.  The values below mirror
% the defaults returned by |defaultLinkParameters| and are exposed here so
% you can quickly tweak them before running the script.
prm.common.modulation       = "QPSK";
prm.common.symbolRate       = 500e3;
prm.common.samplesPerSymbol = 8;
prm.common.frameLength      = 2048;
prm.common.rolloff          = 0.35;
prm.common.filterSpan       = 10;
prm.common.randomSeed       = 2024;

prm.tx.radioID         = "usb:0";
prm.tx.centerFrequency = 2.45e9;
prm.tx.gain            = -10;
prm.tx.framesToSend    = 200; % Set to Inf for continuous transmission

% Launch the transmitter ----------------------------------------------------------------
stats = runLinkTransmitter(prm.tx, prm.common);

fprintf("\nTransmission summary\n");
fprintf("  Frames transmitted : %d\n", stats.framesTransmitted);
fprintf("  Symbols per frame  : %d\n", stats.frameLength);
fprintf("  Samples per frame  : %d\n", stats.samplesPerFrame);
fprintf("  Bits per frame     : %d\n", stats.bitsPerFrame);
fprintf("  Elapsed time (s)   : %.2f\n", stats.elapsedSeconds);
