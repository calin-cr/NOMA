function frames = collectPlutoFrames(rx, p)
%COLLECTPLUTOFRAMES Capture multiple Pluto frames with warm-up discards.
%   frames is a SamplesPerFrame-by-NumRxFrames matrix containing the raw
%   complex samples produced by sdrrx('Pluto').  The helper discards the
%   first p.NumDiscardFrames reads to allow the AGC and filters inside the
%   radio to settle.

frames = complex(zeros(p.SamplesPerFrame, p.NumRxFrames));

discard = p.NumDiscardFrames;
idx = 1;

while idx <= p.NumRxFrames
    [data, len, overrun] = rx();

    if overrun
        warning('Overrun reported by Pluto on frame %d. Data may be corrupted.', idx);
    end

    if len == 0
        warning('Empty frame received from Pluto. Retrying...');
        pause(0.01);
        continue;
    end

    data = double(data(:));

    if numel(data) ~= p.SamplesPerFrame
        warning('Unexpected frame length %d (expected %d). Truncating/padding.', numel(data), p.SamplesPerFrame);
        data = adjustLength(data, p.SamplesPerFrame);
    end

    if discard > 0
        discard = discard - 1;
        continue;
    end

    frames(:, idx) = data;
    idx = idx + 1;
end

end

function out = adjustLength(data, targetLen)
%ADJUSTLENGTH Trim or zero-pad the vector to match targetLen.
if numel(data) > targetLen
    out = data(1:targetLen);
elseif numel(data) < targetLen
    out = [data; zeros(targetLen - numel(data), 1, 'like', data)];
else
    out = data;
end
end
