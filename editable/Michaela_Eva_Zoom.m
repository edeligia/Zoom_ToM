function Michaela_Eva_Zoom (participant_number , run_number) 
%% Notes 
%condition_types
%1 = live 
%2 = pre-recorded 

% condition numbers 
% 1 = live + human
% 2 = live + memoji 
% 3 = pre-recorded + human 
% 4 = pre-recorded + memoji 

%% Output files (8 characters) 
% cd('C:\Users\evade\Documents\Zoom_project\Memoji_Zoom_Data')

%% Debug Settings
p.USE_EYELINK = true;
p.TRIGGER_STIM_TRACKER = true;

if ~p.TRIGGER_STIM_TRACKER    
    warning('One or more debug settings is active!')
end

%% Start Timestamp 

[d.timestamp, d.timestamp_edf] = GetTimestamp;

%% Parameters

%Folder to save EDF file to 
filepath_participant_edf = sprintf('PAR%02d', participant_number);

% screen_rect [ 0 0 width length]
% 0 is both, 1 is likely laptop and 2 is likely second screen 
screen_number = max(Screen('Screens'));
screen_rect = [ ];
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;

%Work around to turn off sync 
Screen('Preference','SkipSyncTests', 1);

%directories 
p.DIR_DATA = [pwd filesep 'Data' filesep];
p.DIR_DATA_EDF = [pwd filesep 'Data_EDF' filesep];
p.DIR_ORDERS = [pwd filesep 'Orders' filesep];
p.DIR_VIDEOSTIMS_HUMAN = [pwd filesep 'VideoStims' filesep 'Human' filesep]; 
p.DIR_VIDEOSTIMS_MEMOJI = [pwd filesep 'VideoStims' filesep 'Memoji' filesep]; 
p.DIR_PARTICIPANT_EDF = [pwd filesep 'Data_EDF' filesep filepath_participant_edf filesep];
p.DIR_IMAGES = [pwd filesep 'ImageResponses' filesep];

%stim tracker
%the left port on Eva's laptop is COM3 and on the culham lab msi laptop 
%p.TRIGGER_STIM_TRACKER = true;
p.TRIGGER_CABLE_COM_STRING = 'COM3';

%timings
p.DURATION_BASELINE = 30;
p.DURATION_BASELINE_FINAL = 30;

%buttons
p.KEYS.RUN.NAME = 'RETURN';
p.KEYS.QUESTION.NAME = 'Q';
p.KEYS.ANSWER.NAME = 'A';
p.KEYS.END.NAME = 'E';
p.KEYS.YES.NAME = 'Y';
p.KEYS.NO.NAME = 'N';
p.KEYS.EXIT.NAME = 'H'; 
p.KEYS.STOP.NAME = 'SPACE';
p.KEYS.ABORT.NAME = 'P';

%%  Check Requirements
%psychtoolbox
try
    AssertOpenGL();
catch err
    warning('PsychToolbox might not be installed or setup correctly!')
    rethrow(err)
end

%Eyelink SDK
try
    Eyelink;
catch
    error('Eyelink requires the SDK from SR Research (http://download.sr-support.com/displaysoftwarerelease/EyeLinkDevKit_Windows_1.11.5.zip)')
end

%Requires directory added to path
if isempty(which('Eyelink.Collection.Connect'))
    error('The "AddToPath" directory must be added to the MATLAB path. Run "setup.m" or add manually.');
end

%Movie files 
% if isempty(dir(VideoStims))
% 	uiwait(warndlg(sprintf('Your stimuli directory is missing! Please create directory %s and populate it with stimuli. When Directory is created, hit ''Okay''',stimdir),'Missing Directory','modal'));
% end

%% Prepare Orders

orderfilepath = sprintf('%sPAR%02d_RUN%02d.xlsx', p.DIR_ORDERS, participant_number, run_number);

[numbers_only_info,~,all_info_cell_matrix] = xlsread(orderfilepath);

%get header info
% order_headers = all_info_cell_matrix(1,:);

%get number of rows (ie. number of trials) excluding headers 
order_data = all_info_cell_matrix(2:end,:);

%get number of trials from order  
p.number_trials = size(order_data, 1);

%get condition number from order 
p.condition_number = all_info_cell_matrix{2, 3};

%save condition type in data 
if p.condition_number == 1
    d.condition_type = sprintf('live_human');
elseif p.condition_number == 2
    d.condition_type = sprintf('live_memoji');
elseif p.condition_number == 3
    d.condition_type = sprintf('prerecorded_human');
elseif p.condition_number == 4
    d.condition_type = sprintf('prerecorded_memoji');
elseif ~p.condition_number
    error('No condition type available');
end

%% Prep 

%time script started
d.timestamp_start_script = GetTimestamp;

%put inputs in data struct
d.participant_number = participant_number;
d.run_number = run_number;

%filenames 
d.filepath_data = sprintf('%sPAR%02d_RUN%02d_%s.mat', p.DIR_DATA, d.participant_number, d.run_number, d.timestamp_start_script);
d.filepath_error = strrep(d.filepath_data, '.mat', '_ERROR.mat');
d.filename_edf_on_system = sprintf('P%02d%s', d.participant_number, d.timestamp_edf);
d.filepath_run_edf = sprintf('%sParticipant_%02d_Run%03d_%s', p.DIR_PARTICIPANT_EDF, d.participant_number, d.run_number, d.timestamp);
d.filepath_correct_image_response = sprintf('%scorrect_response_%02d.jpeg', p.DIR_IMAGES, p.condition_number); 
d.filepath_incorrect_image_response = sprintf('%sincorrect_response_%02d.jpeg', p.DIR_IMAGES, p.condition_number); 

%create output directories
if ~exist(p.DIR_DATA, 'dir'), mkdir(p.DIR_DATA); end
if ~exist(p.DIR_DATA_EDF, 'dir'), mkdir(p.DIR_DATA_EDF); end
if ~exist(p.DIR_PARTICIPANT_EDF, 'dir'), mkdir(p.DIR_PARTICIPANT_EDF); end

%set key values
KbName('UnifyKeyNames');
for key = fields(p.KEYS)'
    key = key{1};
    eval(sprintf('p.KEYS.%s.VALUE = KbName(p.KEYS.%s.NAME);', key, key))
end

%call GetSecs and KbCheck now to improve latency on later calls (it's a MATLAB thing)
for i = 1:10
    GetSecs;
    KbCheck;
end

movieDur = 15;

        
%% Calibrate Eyetracker 
%create window for calibration

try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end

%init
DrawFormattedText(window, 'Eyelink Connect', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.Connect
else
    Eyelink('InitializeDummy');
end 
    
%set window used
DrawFormattedText(window, 'Eyelink Set Window', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.SetupScreen(window)
else
    Eyelink('InitializeDummy');
end 

%set file to write to
DrawFormattedText(window, 'Eyelink Set EDF', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.SetEDF(d.filename_edf_on_system)
else
    Eyelink('InitializeDummy');
end

%calibrate
DrawFormattedText(window, 'Eyelink Calibration', 'center', 'center', screen_colour_text);
Screen('Flip', window);
if p.USE_EYELINK 
    Eyelink.Collection.Calibration
else
    Eyelink('InitializeDummy');
end

%add another screen to say press R to begin 
DrawFormattedText(window, 'Waiting for RETURN key to run or H key to exit', 'center', 'center', screen_colour_text);
Screen('Flip', window);

%% Try 
try
%% open serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
    sport=serial(p.TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
    fopen(sport);
else
    sport = nan;
end

%% Wait for Run Start 
fprintf('\n----------------------------------------------\nWaiting for run key (%s) or exit key (%s)...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.EXIT.NAME);
while 1 
    [~,keys] = KbWait(-1);
    if any(keys(p.KEYS.RUN.VALUE))
      break;   
    else any(keys(p.KEYS.EXIT.VALUE))
        error ('Exit Key Pressed');
    end
end

fprintf('Starting...\n');
Screen('Flip', window);

%Time of Experiment start 
t0 = GetSecs;
d.time_start_experiment = t0;
d.timestamp_start_experiment = GetTimestamp;

%% Initial Baseline 

if p.TRIGGER_STIM_TRACKER
    fwrite(sport, ['mh',bin2dec('00000001'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
end

fprintf('Initial baseline...\n');
tend = t0 + p.DURATION_BASELINE;
while 1
    ti = GetSecs;
    if ti > tend
        break;
    end
end

%Check for exit key to end run
[~,~,keys] = KbCheck(-1);
if any(keys(p.KEYS.EXIT.VALUE))
    error('Exit Key Pressed');
end

if p.TRIGGER_STIM_TRACKER     
    fwrite(sport, ['mh',bin2dec('00000001'),0]); %turn off 2 
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]);
end   

%KS
%calculate end time of baseline
%calcualte time to set trigger low
%set trigger high
%wait a little
%set trigger low
%while time < end time (wait rest of time)
%check for stop key
%reaches ent time

fprintf('Baseline complete...\n'); 

%close screen 
% Screen('Close', window);
% sca
% sca
ShowCursor;

%% Start Eyetracking Recording 
    Eyelink('StartRecording')

    if p.TRIGGER_STIM_TRACKER     
    fwrite(sport, ['mh',bin2dec('00000001'),0]); %turn off 2 
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]);
    end   
    
%% Enter trial phase 
   fprintf('Starting Run...\n');
   
for trial = 1: p.number_trials 
    d.trial_data(trial).timing.onset = GetSecs - t0;
    d.latest_trial = trial;
       
    Eyelink('Message',sprintf('Event: Start of trial %03d\n', trial));
    fprintf('\nTrial %d (%g sec)\n', trial, d.trial_data(trial).timing.onset); 
    
    question_number = numbers_only_info(trial, 2);
   
    if p.condition_number == 3
        movie_filepath = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_HUMAN, question_number);
    elseif p.condition_number == 4
        movie_filepath = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_MEMOJI, question_number);
    end


    d.trial_data(trial).correct_response = nan;
    d.trial_data(trial).timing.trigger.reaction = [];
    
    trial_in_progress = true; 
    phase = 0;
    
    while trial_in_progress
        [~,keys] = KbWait(-1); %if any key is pressed that is incorrect the trial section must be restarted 
        if any(keys(p.KEYS.QUESTION.VALUE)) && phase == 0 && (p.condition_number == 1 || p.condition_number == 2)
            fprintf('Start of question period %d...\n', trial);
            
            sca
            sca
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
                d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
            end
            
            Eyelink('Message','Start of Question Period %d', trial);
            WaitSecs(1);
            while 1
                [~,keys] = KbWait(-1);
                if any(keys(p.KEYS.END.VALUE))
                    fprintf('End of question period %d...\n', trial);
                    
                    if p.TRIGGER_STIM_TRACKER
                    fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
                    d.trial_data(trial).timing.trigger.question_period_end = GetSecs - t0;
                    fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
                    end
                    
                    Eyelink('Message','End of Question Period %d', trial);
                    phase = 1;
                    break;
                elseif any(keys(p.KEYS.EXIT.VALUE)) %break is currently breaking out of the larger while loop as well 
                    %ends current trial
                    
                    trial_in_progress = false;
                    break;
                elseif any(keys(p.KEYS.ABORT.VALUE))
                    d.number_trials = trial;
                    error('Abort key pressed');
                end
            end
        elseif any(keys(p.KEYS.QUESTION.VALUE)) && phase == 0 && (p.condition_number == 3 || p.condition_number == 4)
%             window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
%             Screen(window, 'Flip');	
            movie = Screen('OpenMovie', window, movie_filepath);
            rate = 1; 
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
                d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
            end
            
            Eyelink('Message','Start of Question Period %d', trial);
            fprintf('Start of question period %d...\n', trial);
            
            WaitSecs(1); %Give the display a moment to recover from change of display mode 
            
            Screen(window, 'Flip');
            Screen('PlayMovie', movie, rate, 0, 1.0);
            movie_start = GetSecs;
                       
            while(GetSecs - movie_start < movieDur -.2)
                % Wait for next movie frame, retrieve texture handle to it
                tex = Screen('GetMovieImage', window, movie);
                % Valid texture returned? A negative value means end of movie reached:
                if tex<=0
                    % done, break
                    break;
                end
                % Draw the new texture immediately to screen:
                Screen('DrawTexture', window, tex);
                % Update display:
                Screen(window, 'Flip');
                % Release texture:
                Screen('Close', tex);
            end
%             Screen('CloseMovie', movie);
            Screen(window, 'Flip');
            
            fprintf('End of question period %d...\n', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
                d.trial_data(trial).timing.trigger.question_period_end = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
            end
            
            Eyelink('Message','End of Question Period %d', trial);
            phase = 1;    
        elseif any(keys(p.KEYS.ANSWER.VALUE)) && phase == 1
            fprintf('Start of answer period %d...\n', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00000100'),0]); %turn question period trigger on (for StimTracker)
                d.trial_data(trial).timing.trigger.answer_period_start = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]); 
            end
            
            Eyelink('Message','Start of Answer Period %d', trial);
            WaitSecs(1);
            while 1
                [~,keys] = KbWait(-1);
                if any(keys(p.KEYS.END.VALUE))
                    fprintf('End of answer period %d...\n', trial);
                     
                    if p.TRIGGER_STIM_TRACKER
                        fwrite(sport,['mh',bin2dec('00000100'),0]); %turn question period trigger on (for StimTracker)
                        d.trial_data(trial).timing.trigger.answer_period_end = GetSecs - t0;
                        fwrite(sport,['mh',bin2dec('00000000'),0]); 
                     end
                    
                    Eyelink('Message','End of answer Period %d', trial);
                    phase = 2;
                    break;
                elseif any(keys(p.KEYS.EXIT.VALUE)) %KS revisit this (no abort, etc)
                    %ends current trial
                    trial_in_progress = false;
                    break;
                elseif any(keys(p.KEYS.ABORT.VALUE))
                    d.number_trials = trial;
                    error('Abort key pressed');
                end
            end
        %no image response if in live conditions   
        elseif any(keys(p.KEYS.YES.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= true) && (p.condition_number == 1 || p.condition_number == 2)
            
            Eyelink('Message','Answer correct for trial %d', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00001000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = true;
            
            phase = 3; 
        elseif any(keys(p.KEYS.NO.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= false) && (p.condition_number == 1 || p.condition_number == 2)
            Eyelink('Message','Answer incorrect for trial %d', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00001000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = false;

            phase = 3; 
       %display image response if in pre-recorded conditions
        elseif any(keys(p.KEYS.YES.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= true) && (p.condition_number == 3 || p.condition_number == 4)
            correct_response_image = imread(d.filepath_correct_image_response);
            
%             window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
            imageTexture = Screen('MakeTexture', window, correct_response_image);
            Screen('DrawTexture', window, imageTexture, [], [], 0);
            Screen('Flip', window);

            Eyelink('Message','Answer correct for trial %d', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00001000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = true;
            
            phase = 3;
            
            WaitSecs(1);
            
            Screen('Flip', window);
        elseif any(keys(p.KEYS.NO.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= false) && (p.condition_number == 3 || p.condition_number == 4)
            incorrect_response_image = imread(d.filepath_incorrect_image_response);
            
%             window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
            imageTexture = Screen('MakeTexture', window, incorrect_response_image);
            Screen('DrawTexture', window, imageTexture, [], [], 0);
            Screen('Flip', window);

            Eyelink('Message','Answer incorrect for trial %d', trial);
            
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00001000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = false;

            phase = 3; 
            WaitSecs(1);
            Screen('Flip', window);
        elseif any(keys(p.KEYS.STOP.VALUE)) && phase == 3
            
            d.trial_data(trial).timing.offset = GetSecs - t0;
            trial_in_progress = false;
        elseif any(keys(p.KEYS.EXIT.VALUE))  
            %ends current trial
            trial_in_progress = false;
            break;
        elseif any(keys(p.KEYS.ABORT.VALUE)) %exit the run
            d.number_trials = trial;
            error('Abort key pressed');
        end
    end

    
    %jitter the trial ITI (add a save of the variable) 
    ITI = [1 2 3 4];
    ITI_index = randi(numel(ITI));
    d.trial_data(trial).trial_end_wait = ITI(ITI_index);
    WaitSecs(d.trial_data(trial).trial_end_wait);
    
    %end of trial and save data
    fprintf('End of trial %03d\n', trial)
    
    if p.TRIGGER_STIM_TRACKER
        fwrite(sport,['mh',bin2dec('00000001'),0]);
        Eyelink('Message','Event: End of trial %03d\n', trial);
        d.trial_data(trial).timing.offset = GetSecs - t0;
        fwrite(sport,['mh',bin2dec('00000000'),0]);
    end
 
    fprintf('Saving...\n');
    save(d.filepath_data, 'p', 'd')
end

%% Stop eyelink recording
fprintf('Eyelink Close');   

if p.USE_EYELINK 
    Eyelink.Collection.Close
else
    Eyelink('InitializeDummy');
end 

%% Final Baseline
%Open blank screen for final baseline
try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect); 
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end

Screen('Flip', window);

fprintf('Final baseline...\n');
tend = GetSecs + p.DURATION_BASELINE_FINAL;
while 1
    ti = GetSecs;
    if ti > tend
        break;
    end
    
    [~,~,keys] = KbCheck(-1);  
    if any(keys(p.KEYS.EXIT.VALUE))
        error('Exit Key Pressed');
    end 
end

%% trigger stim tracker (end of exp)
if p.TRIGGER_STIM_TRACKER
    fwrite(sport, ['mh',bin2dec('00000001'),0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
end

%% End
d.time_end_experiment = GetSecs;
d.timestamp_end_experiment = GetTimestamp;

%% Done
save(d.filepath_data, 'p', 'd')
disp Complete! 

%% Close Screens
sca
sca

%% close serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    try
        fclose(sport);
    catch
        warning('Could not close serial connection')
    end
end

%% Save EDF and Shutdown Eyelink 

%get edf
fprintf('Eyelink Pull EDF...\n');

if p.USE_EYELINK 
    Eyelink.Collection.PullEDF([d.filename_edf_on_system '.edf'], d.filepath_run_edf)
else
    Eyelink('InitializeDummy');
end 

%shutdown
fprintf('Eyelink Shutdown');

if p.USE_EYELINK 
    Eyelink.Collection.Shutdown
else
    Eyelink('InitializeDummy');
end

%done
disp('Run complete!');

%% Catch
%catch if error
catch err
    %close screen if open
%     Screen('Close', window);
    sca
    sca
    
    %save everything
    save(['ErrorDump_' d.timestamp_start_script])
    
    %show cursor
    ShowCursor;
    
    %if connection was established...
    if Eyelink('IsConnected')==1
        %try to close
        try
            Eyelink.Collection.Close
        catch
            warning('Could not close Eyelink')
        end
        
        %try to get data
        try
            Eyelink.Collection.PullEDF([d.filename_edf_on_system '.edf'], d.filepath_run_edf)
        catch
            warning('Could not pull EDF')
        end
        
        %try to shutddown
        try
            Eyelink.Collection.Shutdown
        catch
            warning('Could not shut down connection to Eyelink')
        end
        
    end 
    
    %rethrow error for troubleshooting
    rethrow(err)
end 

%% Functions
function [timestamp, timestamp_edf] = GetTimestamp
c = round(clock);
timestamp = sprintf('%d-%d-%d_%d-%d_%d',c([4 5 6 3 2 1]));
timestamp_edf = sprintf('%02d%02d', c(5:6));
 
         

 

             
             
             
             
             
             
             
