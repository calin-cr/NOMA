function [demodulator, bitsPerSymbol, carrierMode] = createDemodulator(name)
%createDemodulator Construct a symbol demodulator for the link scripts
%
%   [DEMODULATOR, BITSPERSYMBOL, CARRIERMODE] = createDemodulator(NAME)
%   returns a function handle that maps received constellation points to
%   binary data, along with metadata used by the receiver chain.

    arguments
        name (1,1) string
    end

    switch upper(name)
        case "BPSK"
            M = 2;
            phaseOffset = pi/4;
            demodFcn = @(samples)pskdemod(samples, M, phaseOffset, "gray", OutputType="bit");
            carrierMode = "PSK";
        case "QPSK"
            M = 4;
            phaseOffset = pi/4;
            demodFcn = @(samples)pskdemod(samples, M, phaseOffset, "gray", OutputType="bit");
            carrierMode = "QPSK";
        case "8PSK"
            M = 8;
            phaseOffset = pi/8;
            demodFcn = @(samples)pskdemod(samples, M, phaseOffset, "gray", OutputType="bit");
            carrierMode = "PSK";
        case "16QAM"
            M = 16;
            demodFcn = @(samples)qamdemod(samples, M, 0, "gray", OutputType="bit");
            carrierMode = "QAM";
        case "64QAM"
            M = 64;
            demodFcn = @(samples)qamdemod(samples, M, 0, "gray", OutputType="bit");
            carrierMode = "QAM";
        otherwise
            error("Unsupported modulation %s", name);
    end

    bitsPerSymbol = log2(M);
    demodulator = @(samples)demodFcn(samples(:));
end
