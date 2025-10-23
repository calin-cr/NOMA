clear all; clc; close all;

%% ---- Load system parameters ----
Rsym = 0.3e6; mod = 4; freq = 915e6; gain = 0; r_off = 0.5;
SimParams = plutoradioqpsktransmitter_init(Rsym, mod, freq, gain, r_off);
Fs   = SimParams.Fs;
Lfrm = SimParams.PlutoFrameLength;

%% ---- Load TX/RX ----
load('NOMA_QPSK_txData.mat','data');   tx = data(:);
S = load('NOMA_QPSK_rxData.mat');
if isfield(S,'rxDataFiltered')
    rx = S.rxDataFiltered(:);
else
    rx = S.rxData(:);
end

%% ---- Basic conditioning ----
rx = rx - mean(rx);                     % DC removal
tx = tx - mean(tx);

% Normalize both to unit RMS
tx = tx / rms(tx);
rx = rx / rms(rx);

%% ---- Coarse CFO correction ----
pd = angle(conj(rx(1:end-1)).*rx(2:end));
f0 = mean(pd)/(2*pi)*Fs;
fprintf('Estimated CFO ≈ %.1f Hz\n', f0);
n = (0:length(rx)-1).';
rx = rx .* exp(-1j*2*pi*f0*n/Fs);

%% ---- Find Barker preamble ----
barker = SimParams.BarkerCode(:);
preamUp = kron(barker, ones(SimParams.Interpolation,1));
[c,l] = xcorr(rx, preamUp);
[~,iMax] = max(abs(c));
off = l(iMax);
fprintf('Estimated frame start offset: %d samples\n', off);

% Align safely
if off >= 0 && off < length(rx)
    rxa = rx(off+1:end);
elseif off < 0
    rxa = rx(1:end+off);
else
    rxa = rx;
end

% Take one frame worth of samples
Ntake = min(Lfrm, numel(rxa));
rxf = rxa(1:Ntake);
txf = tx(1:Ntake);

%% ---- Phase and amplitude equalization ----
% Linear phase slope (fine CFO)
phi = unwrap(angle(rxf .* conj(txf)));
k = (0:Ntake-1).';
p = polyfit(double(k), double(phi), 1);
rxf = rxf .* exp(-1j*p(1)*k);

% Best-fit complex gain (remove 45× mismatch)
a = (txf' * rxf) / (txf' * txf);
rxeq = rxf / a;

% Re-normalize powers
txf = txf / rms(txf);
rxeq = rxeq / rms(rxeq);

%% ---- Compute EVM ----
err = rxeq - txf;
EVM = sqrt(mean(abs(err).^2)) / mean(abs(txf));
fprintf('EVM (RMS): %.3f\n', EVM);
fprintf('TX Power: %.3f | RX Power: %.3f\n', ...
    mean(abs(txf).^2), mean(abs(rxeq).^2));

%% ---- Plots ----
figure;
subplot(1,2,1);
plot(real(txf),imag(txf),'o'); axis equal; grid on;
title('TX constellation'); xlabel('I'); ylabel('Q');

subplot(1,2,2);
plot(real(rxeq),imag(rxeq),'o'); axis equal; grid on;
title('RX equalized constellation'); xlabel('I'); ylabel('Q');

figure;
plot(real(err),imag(err),'.'); axis equal; grid on;
title('Error vector'); xlabel('I error'); ylabel('Q error');
