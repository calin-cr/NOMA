function logResults(filename, Rsym, mod, freq, gain, BER)
    % Create a table row
    entry = table(Rsym, mod, freq, gain, BER(1), BER(2), BER(3), datetime('now'), ...
        'VariableNames', {'Rsym','ModOrder','Freq','Gain','BER','NumErrors','NumCompared','Timestamp'});
    
    % If file exists, append; otherwise create new
    if isfile(filename)
        load(filename, 'resultsTable');
        resultsTable = [resultsTable; entry];
    else
        resultsTable = entry;
    end
    
    % Save back
    save(filename, 'resultsTable');
end
