function prm = defaultLinkParameters()
%defaultLinkParameters Return baseline configuration for the link example
%
%   The returned structure contains independent fields for the transmitter
%   and receiver MATLAB sessions.  Edit the fields in TxLink.m or RxLink.m
%   after calling this helper to match your experiment requirements.

prm = struct();

% Shared modem characteristics -------------------------------------------------
prm.common.modulation       = "QPSK";   % Modulation order
prm.common.symbolRate       = 500e3;     % Symbols per second
prm.common.samplesPerSymbol = 8;         % Oversampling factor
prm.common.frameLength      = 2048;      % Symbols per frame
prm.common.rolloff          = 0.35;      % Raised cosine roll-off
prm.common.filterSpan       = 10;        % Filter span in symbols
prm.common.randomSeed       = 2024;      % Seed for deterministic frame bits

% Transmitter-specific parameters ---------------------------------------------
prm.tx.radioID         = "usb:0";
prm.tx.centerFrequency = 2.45e9;         % Hz
prm.tx.gain            = -10;            % dB
prm.tx.framesToSend    = 200;            % Number of frames per run (Inf for continuous)

% Receiver-specific parameters -------------------------------------------------
prm.rx.radioID             = "usb:0";
prm.rx.centerFrequency     = 2.45e9;     % Hz
prm.rx.gain                = 30;         % dB
prm.rx.stopAfterFrames     = 200;        % Frames to capture (Inf for continuous)
prm.rx.constellationFrames = 4;          % Averaging for the constellation diagram
prm.rx.enablePlots         = true;

end
