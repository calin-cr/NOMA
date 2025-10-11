function [demodulator, bitsPerSymbol, carrier] = createDemodulator(name)
%createDemodulator Construct a symbol demodulator for the link scripts
%
%   [DEMODULATOR, BITSPERSYMBOL, CARRIER] = createDemodulator(NAME) returns
%   a function handle that maps received constellation points to binary
%   data, along with carrier recovery configuration metadata.

    arguments
        name (1,1) string
    end

    switch upper(name)
        case "BPSK"
            M = 2;
            phaseOffset = pi/4;
            demodFcn = @(samples)pskdemod(samples, M, phaseOffset, "gray", OutputType="bit");
            carrier = struct("mode", "BPSK", "phaseOffset", phaseOffset);
        case "QPSK"
            M = 4;
            phaseOffset = pi/4;
            demodFcn = @(samples)pskdemod(samples, M, phaseOffset, "gray", OutputType="bit");
            carrier = struct("mode", "QPSK", "phaseOffset", phaseOffset);
        case "8PSK"
            M = 8;
            phaseOffset = pi/8;
            demodFcn = @(samples)pskdemod(samples, M, phaseOffset, "gray", OutputType="bit");
            carrier = struct("mode", "8PSK", "phaseOffset", phaseOffset);
        case "16QAM"
            M = 16;
            demodFcn = @(samples)qamdemod(samples, M, 0, "gray", OutputType="bit");
            carrier = struct("mode", "16QAM", "phaseOffset", 0);
        case "64QAM"
            M = 64;
            demodFcn = @(samples)qamdemod(samples, M, 0, "gray", OutputType="bit");
            carrier = struct("mode", "64QAM", "phaseOffset", 0);
        otherwise
            error("Unsupported modulation %s", name);
    end

    bitsPerSymbol = log2(M);
    demodulator = @(samples)demodFcn(samples(:));
end
