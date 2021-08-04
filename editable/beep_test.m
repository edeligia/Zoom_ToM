%clear prior audio
try
    PsychPortAudio('Close');
catch
end

%sound
p.SOUND.LATENCY = .060;
p.SOUND.VOLUME = 1; %1 = 100%

%prepare start/stop beeps
freq = 48000;
beep_duration = 0.5;
beep_start = MakeBeep(500,beep_duration,freq);
sound_handle_beep_start = PsychPortAudio('Open', [], 1, [], freq, size(beep_start,1), [], p.SOUND.LATENCY);
PsychPortAudio('Volume', sound_handle_beep_start, p.SOUND.VOLUME);
PsychPortAudio('FillBuffer', sound_handle_beep_start, beep_start);
% PsychPortAudio('Start', sound_handle_beep_start);
% PsychPortAudio('Stop', sound_handle_beep_start, 1);
% beep_stop = MakeBeep(300,beep_duration,freq);
% sound_handle_beep_stop = PsychPortAudio('Open', [], 1, [], freq, size(beep_stop,1), [], p.SOUND.LATENCY);
% PsychPortAudio('Volume', sound_handle_beep_stop, p.SOUND.VOLUME);
% PsychPortAudio('FillBuffer', sound_handle_beep_stop, beep_stop);
% PsychPortAudio('Start', sound_handle_beep_stop);
% PsychPortAudio('Stop', sound_handle_beep_stop, 1);

%start beep
PsychPortAudio('Start', sound_handle_beep_start);
% t = GetSecs;
% d.trial_data(trial).timing.audio_go_start = t - t0;
% time_stop_beep = t + beep_duration;
% beep_stopped = false;

WaitSecs(0.5);

PsychPortAudio('Stop', sound_handle_beep_start);
beep_stopped = true;