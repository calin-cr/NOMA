function symbols = bitsToSymbols(bits, bitsPerSymbol)
%bitsToSymbols Group binary data into M-ary symbol indices
%
%   SYMBOLS = bitsToSymbols(BITS, BITSPERSYMBOL) reshapes the column vector
%   BITS into groups of BITSPERSYMBOL and converts each group into its
%   corresponding integer symbol using a left-most-significant-bit ordering.

    arguments
        bits (:,1) {mustBeNumericOrLogical}
        bitsPerSymbol (1,1) double {mustBePositive}
    end

    if mod(numel(bits), bitsPerSymbol) ~= 0
        error("The number of bits must be divisible by the bits per symbol.");
    end

    bitGroups = reshape(bits, bitsPerSymbol, []).';
    symbols = bi2de(bitGroups, "left-msb");
end
