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
            carrierMode = "PSK";
            demodSymbolFcn = @(samples) pskdemod(samples, M, phaseOffset);
        case "QPSK"
            M = 4;
            phaseOffset = pi/4;
            carrierMode = "QPSK";
            demodSymbolFcn = @(samples) pskdemod(samples, M, phaseOffset);
        case "8PSK"
            M = 8;
            phaseOffset = pi/8;
            carrierMode = "PSK";
            demodSymbolFcn = @(samples) pskdemod(samples, M, phaseOffset);
        case "16QAM"
            M = 16;
            carrierMode = "QAM";
            demodSymbolFcn = @(samples) qamdemod(samples, M, UnitAveragePower=true);
        case "64QAM"
            M = 64;
            carrierMode = "QAM";
            demodSymbolFcn = @(samples) qamdemod(samples, M, UnitAveragePower=true);
        otherwise
            error("Unsupported modulation %s", name);
    end

    bitsPerSymbol = log2(M);
    symbolsToBits = @(symbols) reshape(de2bi(symbols, bitsPerSymbol, "left-msb").', [], 1);
    demodulator = @(samples) symbolsToBits(demodSymbolFcn(samples));
end
