function tx = setupPlutoTx(p)
tx = sdrtx('Pluto');
tx.CenterFrequency = p.CenterFrequency;
tx.BasebandSampleRate = p.SampleRate;
tx.Gain = p.TxGain;
end
