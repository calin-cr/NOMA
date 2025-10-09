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
            modObj = comm.PSKModulator(M, PhaseOffset=pi/4, BitInput=false);
        case "QPSK"
            M = 4;
            modObj = comm.PSKModulator(M, PhaseOffset=pi/4, BitInput=false);
        case "8PSK"
            M = 8;
            modObj = comm.PSKModulator(M, PhaseOffset=pi/8, BitInput=false);
        case "16QAM"
            M = 16;
            modObj = comm.RectangularQAMModulator(M, BitInput=false, ...
                NormalizationMethod="Average power");
        case "64QAM"
            M = 64;
            modObj = comm.RectangularQAMModulator(M, BitInput=false, ...
                NormalizationMethod="Average power");
        otherwise
            error("Unsupported modulation %s", name);
    end

    bitsPerSymbol = log2(M);
    constellation = modObj((0:M-1).');
    modulator = @(symbols)modObj(symbols);
end
