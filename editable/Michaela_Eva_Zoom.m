 
%%  Requires PTB
try
    AssertOpenGL();
catch err
    warning('PsychToolbox might not be installed or setup correctly!')
    rethrow(err)
end

%%Prep 

%parameters 
DURATION_BASELINE_INITIAL = 30;

%buttons
p.KEYS.START.NAME = 'S';
p.KEYS.RUN.NAME = 'RETURN';
p.KEYS.QUESTION.NAME = 'Q';
p.KEYS.ANSWER.NAME = 'A';
p.KEYS.REACTION.NAME = 'R'; 
p.KEYS.END.NAME = 'E';
p.KEYS.YES.NAME = 'Y';
p.KEYS.NO.NAME = 'N';
p.KEYS.EXIT.NAME = 'H'; 
p.KEYS.STOP.NAME = 'SPACE'; 
p.KEYS.BUTTON_DEBUG.NAME = 'B';

%set key values
KbName('UnifyKeyNames');
for key = fields(p.KEYS)'
    key = key{1};
    eval(sprintf('p.KEYS.%s.VALUE = KbName(p.KEYS.%s.NAME);', key, key))
end

%% Test
%create window for calibration

Screen('Preference','SkipSyncTests', 1);

try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end

%try in case of error
try

%init
DrawFormattedText(window, 'Eyelink Connect', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Connect
    
%set window used
DrawFormattedText(window, 'Eyelink Set Window', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.SetupScreen(window)

%set file to write to
DrawFormattedText(window, 'Eyelink Set EDF', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.SetEDF(filename_edf)

%calibrate
DrawFormattedText(window, 'Eyelink Calibration', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Calibration

%close screen 
Screen('Close', window);
ShowCursor;

%% open serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
    sport=serial(p.TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
    fopen(sport);
else
    sport = nan;
end

%% Initial Baseline (30 seconds) 
fprintf('\n----------------------------------------------\nWaiting for run key (%s) or stop key (%s)...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.EXIT.NAME);
while 1 
    [~,keys] = KbWait(-1);
    if any(keys(p.KEYS.RUN.VALUE))
      break;   
    else any(keys(p.KEYS.EXIT.VALUE))
        error ('Exit Key Pressed');
    end
end
fprintf('Starting...\n'); 

%Time of Experiment start 
t0 = GetSecs;
d.time_start_experiment = t0;

%% Initial Baseline 
fprintf('Initial baseline...\n');

if p.TRIGGER_STIM_TRACKER
    fwrite(sport, ['mh',bin2dec('00000001'),0]); %turn on 1 for run and 2 for baseline
    WaitSecs(DURATION_BASELINE_INITIAL);
    fwrite(sport, ['mh',bin2dec('00000000'),0]); %turn off 2 
end     

fprintf('Baseline complete...\n'); 
%% Start Trial

while 1
    [~,keys] = KbWait(-1); %does adding untilTime == 300 mean it will automatically return after 5 min regardless
    if any(keys(p.KEYS.EXIT.VALUE))
        error('Exit Key Pressed');
    elseif any(keys(p.KEYS.START.VALUE)) %start of trial
        fprintf('Trial Start...\n');
        Eyelink('StartRecording');
        WaitSecs(1);
        [~,keys] = KbWait(-1);
        if any(keys(p.KEYS.QUESTION.VALUE))
            fprintf('Question Start...\n');
            fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
            Eyelink('Message','Start of Question Period\n');
            WaitSecs(1);
            [~,keys] = KbWait(-1);
            if any(keys(p.KEYS.END.VALUE))
                fprintf('Question End...\n');
                fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
                Eyelink('Message','End of Question Period\n');
                WaitSecs(1);
                [~,keys] = KbWait(-1);
                if any(keys(p.KEYS.ANSWER.VALUE))
                    fprintf('Answer Start...\n');
                    fwrite(sport,['mh',bin2dec('00000100'),0]); %turn answer period trigger on (for StimTracker)
                    Eyelink('Message','Start of Question Period\n');
                    WaitSecs(1);
                    [~,keys] = KbWait(-1);
                    if any(keys(p.KEYS.END.VALUE))
                        fprintf('Answer End...\n');
                        fwrite(sport,['mh',bin2dec('00000000'),0]); %turn answer period trigger off (for StimTracker)
                        Eyelink('Message','End of Question Period\n');
                        WaitSecs(1);
                    else any(keys(p.KEYS.STOP.VALUE))
                        break;
                    end
                else any(keys(p.KEYS.STOP.VALUE))
                    break;
                end
            else any(keys(p.KEYS.STOP.VALUE))
                break;
            end
        else any(keys(p.KEYS.STOP.VALUE))
            break;
        end
    else any(keys(p.KEYS.STOP.VALUE))
        break;
    end
end

         


 
             
             
             
             
             
             
             
