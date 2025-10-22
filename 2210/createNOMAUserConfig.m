function userCfg = createNOMAUserConfig(message, numMessages, targetCharLength)
%createNOMAUserConfig Generate frame configuration for a NOMA QPSK user.
%
%   userCfg = createNOMAUserConfig(message, numMessages) returns a
%   structure containing the header bits, payload bits, and metadata needed
%   to build QPSK frames that follow the example QPSK transmitter format.
%
%   The function duplicates the Barker sequence header used by the legacy
%   example and creates ``sprintf('%s %03d\n', message, idx)`` payloads for
%   idx = 0:(numMessages-1). Each ASCII character is mapped to 7-bit binary
%   words following the original example implementation.
%
%   See also QPSKTransmitter_NOMA.

%   Copyright 2024

arguments
    message (1,:) char
    numMessages (1,1) {mustBePositive, mustBeInteger}
    targetCharLength (1,1) {mustBePositive, mustBeInteger} = strlength(message)
end

% Duplicate Barker code header (same as legacy example)
barker = [+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1]';
unipolarBarker = (barker + 1)./2;
userCfg.HeaderBits = repmat(unipolarBarker, 2, 1);
userCfg.HeaderBitCount = numel(userCfg.HeaderBits);

% Prepare formatted payload strings
if targetCharLength < strlength(message)
    error('createNOMAUserConfig:TargetLength', ...
        'targetCharLength must be greater than or equal to message length.');
end

baseMessage = char(pad(string(message), targetCharLength));
msgLength = targetCharLength + 5; % space + 3 digits + newline
userCfg.MessageLength = msgLength;
userCfg.NumberOfMessages = numMessages;

msgSet = zeros(numMessages * msgLength, 1, 'uint8');
for idx = 0:numMessages-1
    msgSet(idx * msgLength + (1:msgLength)) = sprintf('%s %03d\n', baseMessage, idx);
end

% Convert characters to 7-bit binary words (left-msb to match example)
payloadBitsMatrix = de2bi(msgSet, 7, 'left-msb')';
userCfg.PayloadBits = payloadBitsMatrix(:);
userCfg.PayloadBitCount = numel(userCfg.PayloadBits);

% Frame size metadata
userCfg.FrameBitCount = userCfg.HeaderBitCount + userCfg.PayloadBitCount;
userCfg.Message = message;
userCfg.PaddedMessage = baseMessage;
userCfg.TargetCharLength = targetCharLength;
end
