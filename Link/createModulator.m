function [modulator, bitsPerSymbol, constellation] = createModulator(name)
%createModulator Construct a complex baseband modulator for the link scripts
%
%   [MODULATOR, BITSPERSYMBOL, CONSTELLATION] = createModulator(NAME) returns
%   a function handle that maps M-ary integer symbols to constellation points,
%   the number of bits represented by each symbol, and the reference
%   constellation points for power normalization.

    arguments
        name (1,1) string
    end

    switch upper(name)
        case "BPSK"
            M = 2;
            phaseOffset = pi/4;
            modFcn = @(symbols)pskmod(symbols, M, phaseOffset, "gray");
        case "QPSK"
            M = 4;
            phaseOffset = pi/4;
            modFcn = @(symbols)pskmod(symbols, M, phaseOffset, "gray");
        case "8PSK"
            M = 8;
            phaseOffset = pi/8;
            modFcn = @(symbols)pskmod(symbols, M, phaseOffset, "gray");
        case "16QAM"
            M = 16;
            modFcn = @(symbols)qammod(symbols, M, 0, "gray", UnitAveragePower=true);
        case "64QAM"
            M = 64;
            modFcn = @(symbols)qammod(symbols, M, 0, "gray", UnitAveragePower=true);
        otherwise
            error("Unsupported modulation %s", name);
    end

    bitsPerSymbol = log2(M);
    constellation = modFcn((0:M-1).');
    modulator = @(symbols)modFcn(symbols(:));
end
