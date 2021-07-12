  
%%  Requires PTB
try
    AssertOpenGL();
catch err
    warning('PsychToolbox might not be installed or setup correctly!')
    rethrow(err)
end

sqeaesqeaesqeaeu

%% Requires SR Research Eyelink SDK to be installed
try
    Eyelink;
catch
    error('Eyelink requires the SDK from SR Research (http://download.sr-support.com/displaysoftwarerelease/EyeLinkDevKit_Windows_1.11.5.zip)')
end

%% Requires directory added to path
if isempty(which('Eyelink.Collection.Connect'))
    error('The "AddToPath" directory must be added to the MATLAB path. Run "setup.m" or add manually.');
end

%% Parameters
%% screen_rect [ 0 0 width length]
screen_number = max(Screen('Screens'));
screen_rect = [];
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;

filename_edf = 'testtwo.edf';
full_path_to_put_edf = [pwd filesep filename_edf];

number_trials = 3;

%stim tracker
%the left port on Eva's laptop is COM3 and on the culham lab msi laptop 
p.TRIGGER_STIM_TRACKER = true;
p.TRIGGER_CABLE_COM_STRING = 'COM3';

%timings
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
%try

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
%% Start Run 

    for trial = 1: number_trials
        fprintf('Trial %d of %d...\n', trial, number_trials);

%     while 1
        [~,keys] = KbWait(-1); %does adding untilTime == 300 mean it will automatically return after 5 min regardless
        if any(keys(p.KEYS.EXIT.VALUE))
            error('Exit Key Pressed');
        elseif any(keys(p.KEYS.START.VALUE)) %start of trial
            fprintf('Trial Start...\n');
            Eyelink('StartRecording');
            Eyelink('Message',sprintf('Event: Start of trial %03d\n', trial));
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
                        Eyelink('Message','Start of Answer Period\n');
                        WaitSecs(1);
                        [~,keys] = KbWait(-1);
                        if any(keys(p.KEYS.END.VALUE))
                            fprintf('Answer End...\n');
                            fwrite(sport,['mh',bin2dec('00000000'),0]); %turn answer period trigger off (for StimTracker)
                            Eyelink('Message','End of Answer Period\n');
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

%     end

%% close serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    try
        fclose(sport);
    catch
        warning('Could not close serial connection')
    end
end

%Open screen 
try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end

%get edf
DrawFormattedText(window, 'Eyelink Pull EDF', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.PullEDF(filename_edf, full_path_to_put_edf)

%shutdown
DrawFormattedText(window, 'Eyelink Shutdown', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Shutdown

%done
Screen('Close', window);
ShowCursor;
disp('Study complete!');

% %catch if error
% catch err
%     %close screen if open
%     Screen('Close', window);
%     
%     %show cursor
%     ShowCursor;
%     
%     %if connection was established...
%     if Eyelink('IsConnected')==1
%         %try to close
%         try
%             Eyelink.Collection.Close
%         catch
%             warning('Could not close Eyelink')
%         end
%         
%         %try to get data
%         try
%             Eyelink.Collection.PullEDF(filename_edf, full_path_to_put_edf)
%         catch
%             warning('Could not pull EDF')
%         end
%         
%         %try to shutddown
%         try
%             Eyelink.Collection.Shutdown
%         catch
%             warning('Could not shut down connection to Eyelink')
%         end
%         
%     end
%     
%     %rethrow error for troubleshooting
%     rethrow(err)
% end
         


 
             
             
             
             
             
             
             
