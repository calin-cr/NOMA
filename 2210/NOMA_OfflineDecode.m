%NOMA_OfflineDecode Perform offline SIC decoding for two-user QPSK NOMA.
%
%   This script assumes that two ADALM-Pluto receiver captures have been
%   logged using rxLog.m and saved as:
%       rxStrong.mat -> high-SNR "strong" user capture
%       rxWeak.mat   -> low-SNR  "weak" user capture
%
%   The decoder applies successive interference cancellation on the strong
%   capture, demodulates both users, and computes BER relative to the known
%   transmitted payload bits. Constellation diagrams are plotted to aid
%   inspection.
%
%   Ensure that the transmitter uses QPSKTransmitter_NOMA with matching
%   parameters before running this script.

%% Configuration (must match transmitter)
messageUser1 = "Hello world";   % Weak user (higher power)
messageUser2 = "Chao world";    % Strong user (lower power)
numMessages   = 100;             % Messages per frame
P1 = 0.8;                        % Power allocation for user 1
P2 = 0.2;                        % Power allocation for user 2
upsampleFactor = 2;
rolloff        = 0.5;
filterSpan     = 10;
phaseOffset    = pi/4;

% Scrambler parameters (same as legacy example)
scramblerBase = 2;
scramblerPolynomial = [1 1 1 0 1];
scramblerInitialConditions = [0 0 0 0];

%% Derived helper structures
assert(abs((P1 + P2) - 1) < 1e-6, 'Power coefficients must sum to one.');

targetLength = max(strlength(messageUser1), strlength(messageUser2));
user1Cfg = createNOMAUserConfig(messageUser1, numMessages, targetLength);
user2Cfg = createNOMAUserConfig(messageUser2, numMessages, targetLength);
frameSymbolCount = user1Cfg.FrameBitCount / 2; % QPSK: 2 bits/symbol
headerBitCount   = user1Cfg.HeaderBitCount;
payloadBitCount  = user1Cfg.PayloadBitCount;
rxFilterDelay    = filterSpan/2;              % In output symbols (Decimation = sps)

%% Common signal processing objects
qpskMod = comm.QPSKModulator('BitInput', true, 'PhaseOffset', phaseOffset, ...
    'OutputDataType', 'double');
qpskDemod = comm.QPSKDemodulator('BitOutput', true, 'PhaseOffset', phaseOffset);

rxFilterStrong = comm.RaisedCosineReceiveFilter('RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', filterSpan, 'InputSamplesPerSymbol', upsampleFactor, ...
    'DecimationFactor', upsampleFactor);
rxFilterWeak   = clone(rxFilterStrong);

descramblerWeak = comm.Descrambler(scramblerBase, scramblerPolynomial, scramblerInitialConditions);
descramblerStrong = comm.Descrambler(scramblerBase, scramblerPolynomial, scramblerInitialConditions);

txFilterWeak   = comm.RaisedCosineTransmitFilter('RolloffFactor', rolloff, ...
    'FilterSpanInSymbols', filterSpan, 'OutputSamplesPerSymbol', upsampleFactor);

%% Load captures
yStrong = loadCapture('rxStrong.mat');
yWeak   = loadCapture('rxWeak.mat');

%% Helper lambdas
extractSymbols = @(rxFilterObj, samples) ...
    rxFilterObj(samples);

functionBits = @(bits) bits(headerBitCount+1:headerBitCount+payloadBitCount);

%% Strong capture: decode weak user then strong user (SIC)
reset(rxFilterStrong);
matchedStrong = extractSymbols(rxFilterStrong, yStrong);
matchedStrong = matchedStrong(rxFilterDelay+1:rxFilterDelay+frameSymbolCount);

weakBitsScrambledStrong = qpskDemod(matchedStrong);
weakPayloadStrong = descramblerWeak(functionBits(weakBitsScrambledStrong));

% Reconstruct weak user waveform for interference cancellation
reset(txFilterWeak);
weakSymbolsHat = qpskMod(weakBitsScrambledStrong);
weakWaveformHat = txFilterWeak(weakSymbolsHat);

% Subtract weak user contribution from the raw strong capture
yStrongClean = yStrong(1:length(weakWaveformHat)) - sqrt(P1) * weakWaveformHat;

% Decode strong user after SIC
reset(rxFilterStrong);
matchedStrongClean = extractSymbols(rxFilterStrong, yStrongClean);
matchedStrongClean = matchedStrongClean(rxFilterDelay+1:rxFilterDelay+frameSymbolCount);

strongBitsScrambled = qpskDemod(matchedStrongClean);
strongPayloadBits = descramblerStrong(functionBits(strongBitsScrambled));

%% Weak capture: decode weak user directly (treat interference as noise)
reset(rxFilterWeak);
matchedWeak = extractSymbols(rxFilterWeak, yWeak);
matchedWeak = matchedWeak(rxFilterDelay+1:rxFilterDelay+frameSymbolCount);

weakBitsScrambledWeak = qpskDemod(matchedWeak);
weakPayloadWeak = descramblerWeak(functionBits(weakBitsScrambledWeak));

%% Compute BER values
[errWeakStrong, berWeakStrong] = biterr(user1Cfg.PayloadBits, weakPayloadStrong);
[errWeakWeak, berWeakWeak]     = biterr(user1Cfg.PayloadBits, weakPayloadWeak);
[errStrongStrong, berStrongStrong] = biterr(user2Cfg.PayloadBits, strongPayloadBits);

fprintf('\n--- NOMA Offline Results ---\n');
fprintf('Weak user via strong capture (after SIC): %d errors, BER = %.3e\n', errWeakStrong, berWeakStrong);
fprintf('Weak user via weak capture (no SIC)     : %d errors, BER = %.3e\n', errWeakWeak, berWeakWeak);
fprintf('Strong user via strong capture (SIC)    : %d errors, BER = %.3e\n', errStrongStrong, berStrongStrong);

%% Constellation plots
figure; scatterplot(matchedStrong); title('Strong capture before SIC');
figure; scatterplot(matchedStrongClean); title('Strong capture after SIC');
figure; scatterplot(matchedWeak); title('Weak capture (treat interference as noise)');

%% Recover and display text payloads
weakMessageStrong = bitsToString(weakPayloadStrong, user1Cfg.MessageLength);
weakMessageWeak   = bitsToString(weakPayloadWeak, user1Cfg.MessageLength);
strongMessage     = bitsToString(strongPayloadBits, user2Cfg.MessageLength);

fprintf('\nSample decoded messages (first 3 payloads):\n');
fprintf('Weak user from strong capture: %s\n', weakMessageStrong{1});
fprintf('Weak user from weak capture  : %s\n', weakMessageWeak{1});
fprintf('Strong user (post-SIC)       : %s\n', strongMessage{1});

%% Local helper functions -------------------------------------------------
function data = loadCapture(matFile)
    capture = load(matFile);
    fields = fieldnames(capture);
    if isempty(fields)
        error('NOMA_OfflineDecode:EmptyCapture', ...
            'File %s does not contain any variables.', matFile);
    end
    data = capture.(fields{1});
end

function messages = bitsToString(bitVector, msgLength)
    bitsPerChar = 7;
    charsPerMsg = msgLength;
    totalChars = numel(bitVector)/bitsPerChar;
    if rem(totalChars, charsPerMsg) ~= 0
        error('NOMA_OfflineDecode:InvalidLength', ...
            'Bit vector length does not align with message blocks.');
    end
    charMatrix = reshape(bitVector, bitsPerChar, []).';
    asciiValues = bi2de(charMatrix, 'left-msb');
    charArray = char(asciiValues);
    messages = cell(totalChars/charsPerMsg, 1);
    for k = 1:numel(messages)
        idx = (k-1)*charsPerMsg + (1:charsPerMsg);
        messages{k} = charArray(idx).';
    end
end
