clear; clc; close all;

% Load composite + params + reference bits (from your TX save)
S = load('NOMA_QPSK_txData.mat');  % contains: data, prmQPSKTransmitter, bitsUser1, bitsUser2
x   = S.data(:);
prm = S.prmQPSKTransmitter;

% ---- Parameters mirrored from TX ----
ups     = prm.Interpolation;                    % 2
rolloff = prm.RolloffFactor;                    % 0.5
span    = prm.RaisedCosineFilterSpan;           % 10
ML      = prm.MessageLength;                    % chars per line
P1 = 0.8; P2 = 0.2; P1n = P1/(P1+P2); P2n = P2/(P1+P2);

% ---- Perfect channel (no noise/fading) ----
r = x;

% ---- Matched SRRC, decimate to symbol-rate, trim delay ----
rcr = comm.RaisedCosineReceiveFilter( ...
    'RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', span, ...
    'InputSamplesPerSymbol', ups, ...
    'DecimationFactor', ups);
y = rcr(r);                 % now 1 sample/symbol
gd_sym = span/2;            % symbols of group delay after decimation
y = y(gd_sym+1:end-gd_sym); % trim
y = y / rms(y);             % normalize for stable demod

% ---- QPSK modem (must match TX) ----
demod = comm.QPSKDemodulator('BitOutput',true, ...
    'PhaseOffset',pi/4,'SymbolMapping','Gray');
modul = comm.QPSKModulator('BitInput',true, ...
    'PhaseOffset',pi/4,'SymbolMapping','Gray');

% ===== SIC =====
% Far user first
b2_hat = demod(y);
s2_hat = modul(b2_hat);

% Complex least-squares projection for User-2 component
a2 = (s2_hat' * y) / (s2_hat' * s2_hat);   % captures scale+phase (~sqrt(P2n)e^{jθ})
y_after = y - a2 * s2_hat;

% Near user after cancellation
b1_hat = demod(y_after);

% ---- Descramblers (mirror TX scrambler) ----
descr1 = comm.Descrambler(2, prm.ScramblerPolynomial, prm.ScramblerInitialConditions);
descr2 = comm.Descrambler(2, prm.ScramblerPolynomial, prm.ScramblerInitialConditions);

u1_bits = descr1(b1_hat);
u2_bits = descr2(b2_hat);

% ---- BER vs ground truth (saved by TX) ----
if isfield(S,'bitsUser1') && isfield(S,'bitsUser2')
    L1 = min(numel(u1_bits), numel(S.bitsUser1));
    L2 = min(numel(u2_bits), numel(S.bitsUser2));
    ber1 = biterr(u1_bits(1:L1), S.bitsUser1(1:L1)) / L1;
    ber2 = biterr(u2_bits(1:L2), S.bitsUser2(1:L2)) / L2;
else
    ber1 = NaN; ber2 = NaN;
end

fprintf('BER User1 (near): %.3e\n', ber1);
fprintf('BER User2 (far) : %.3e\n', ber2);

% ---- Recover first message line for each user ----
% Convert first 7*ML bits to ASCII (guard against short vectors)
take1 = min(7*ML, numel(u1_bits));
take2 = min(7*ML, numel(u2_bits));
m1 = char(bi2de(reshape(u1_bits(1:take1),7,[]).','left-msb'))';
m2 = char(bi2de(reshape(u2_bits(1:take2),7,[]).','left-msb'))';

disp('--- User1 decoded start ---'); disp(m1);
disp('--- User2 decoded start ---'); disp(m2);

% ---- Plots ----
figure;
subplot(1,3,1); plot(real(y),imag(y),'.'); axis equal; grid on;
title('Composite @ symbol rate'); xlabel I; ylabel Q;

subplot(1,3,2); plot(real(y_after),imag(y_after),'.'); axis equal; grid on;
title('After cancelling User-2'); xlabel I; ylabel Q;

subplot(1,3,3);
plot(real(modul(b1_hat(1:min(400,end)))),imag(modul(b1_hat(1:min(400,end)))),'.');
axis equal; grid on; title('User-1 constellation'); xlabel I; ylabel Q;
