function logResults(p, ber)
%LOGRESULTS Append a BER entry to the MAT-file defined in p.BERFile.

entry = table( ...
    datetime('now'),          ... % Timestamp
    p.CenterFrequency,        ...
    p.SampleRate,             ...
    p.SymbolRate,             ...
    string(upper(p.Modulation)), ...
    p.ModulationOrder,        ...
    p.SamplesPerSymbol,       ...
    p.TxGain,                 ...
    p.RxGain,                 ...
    p.NumRxFrames,            ...
    ber,                      ...
    'VariableNames', {'Timestamp','CenterFrequency','SampleRate','SymbolRate', ...
    'Modulation','ModulationOrder','SamplesPerSymbol','TxGain','RxGain','NumFrames','BER'});

if isfile(p.BERFile)
    S = load(p.BERFile, 'results');
    if isfield(S, 'results') && istable(S.results)
        existing = S.results;
    elseif isfield(S, 'results')
        existing = struct2table(S.results);
    else
        existing = table();
    end

    allVars = entry.Properties.VariableNames;
    for name = allVars
        varName = name{1};
        if ~ismember(varName, existing.Properties.VariableNames)
            switch varName
                case 'Timestamp'
                    existing.(varName) = repmat(NaT, height(existing), 1);
                case 'Modulation'
                    existing.(varName) = repmat(string(missing), height(existing), 1);
                otherwise
                    existing.(varName) = nan(height(existing), 1);
            end
        end
    end

    results = [existing(:, allVars); entry];
else
    results = entry;
end

save(p.BERFile, 'results');
end
