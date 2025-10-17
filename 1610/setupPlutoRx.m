function rx = setupPlutoRx(p)
rx = sdrrx('Pluto');
rx.CenterFrequency = p.CenterFrequency;
rx.BasebandSampleRate = p.SampleRate;
rx.GainSource = 'Manual';
rx.Gain = p.RxGain;
rx.SamplesPerFrame = p.FrameSize;
rx.OutputDataType = 'double';
end
