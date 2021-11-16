function ME_Zoom(participant_number, run_number)
%% Notes 
%condition_types
%1 = live 
%2 = pre-recorded 

%tester

% condition numbers 
% 1 = live + human
% 2 = live + memoji 
% 3 = pre-recorded + human 
% 4 = pre-recorded + memoji 

%% Debug Settings
p.USE_EYELINK = false;
p.TRIGGER_STIM_TRACKER = false;

if ~p.TRIGGER_STIM_TRACKER    
    warning('One or more debug settings is active!')
end

%% Start Timestamp 

[d.timestamp, d.timestamp_edf] = GetTimestamp;

%% Parameters

%Folder to save EDF file to 
filepath_participant_edf = sprintf('PAR%02d', participant_number);

%Folder for participant specific data
filepath_participant_mat = sprintf('PAR%02d', participant_number);

% screen_rect [ 0 0 width length]
screen_number = max(Screen('Screens'));
screen_rect = [ ];
screen_colour_background = [0 0 0];
screen_font_size = 30;

%Work around to turn off sync 
Screen('Preference','SkipSyncTests', 1);

%directories 
p.DIR_DATA = [pwd filesep 'Data' filesep filepath_participant_mat filesep];
p.DIR_DATA_EDF = [pwd filesep 'Data_EDF' filesep];
p.DIR_ORDERS = [pwd filesep 'Orders' filesep 'Mat Orders' filesep];
p.DIR_VIDEOSTIMS_HUMAN = [pwd filesep 'VideoStims' filesep 'Human' filesep]; 
p.DIR_VIDEOSTIMS_MEMOJI = [pwd filesep 'VideoStims' filesep 'Memoji' filesep]; 
p.DIR_PARTICIPANT_EDF = [pwd filesep 'Data_EDF' filesep filepath_participant_edf filesep];
p.DIR_IMAGES = [pwd filesep 'ImageResponses' filesep];
p.DIR_VIDEOSTIMS_PRACTICE = [pwd filesep 'VideoStims' filesep 'Practice_Stims' filesep]; 

%stim tracker
%the left port on Eva's laptop is COM3 and on the culham lab msi laptop 
p.TRIGGER_CABLE_COM_STRING = 'COM3';

%timings
p.DURATION_BASELINE = 2;
p.DURATION_BASELINE_FINAL = 2;

%buttons
p.KEYS.RUN.NAME = 'RETURN';
p.KEYS.QUESTION.NAME = 'Q';
p.KEYS.ANSWER.NAME = 'A';
p.KEYS.YES.NAME = 'Y';
p.KEYS.NO.NAME = 'N';
p.KEYS.EXIT.NAME = 'H'; 
p.KEYS.STOP.NAME = 'SPACE';
p.KEYS.ABORT.NAME = 'P';

%sound
p.SOUND.LATENCY = .060;
p.SOUND.VOLUME = 1; %1 = 100%

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

%Setup a network connection to the Unity application so messages can be
%sent
client = tcpip('127.0.0.1',55001,'NetworkRole','Client');
set(client, 'Timeout', 30);

%% Prepare Orders

% orderfilepath = sprintf('%sPAR%02d_RUN%02d.xlsx', p.DIR_ORDERS, participant_number, run_number);
% 
% [numbers_only_info,~,all_info_cell_matrix] = xlsread(orderfilepath);
% d.order.raw = all_info_cell_matrix; 
% 
% %get header info
% % order_headers = all_info_cell_matrix(1,:);
% 
% %get number of rows (ie. number of trials) excluding headers 
% order_data = all_info_cell_matrix(2:end,:);
% 
% %get number of trials from order  
% p.number_trials = size(order_data, 1);
% 
% %get condition number from order 
% p.condition_number = all_info_cell_matrix{2, 3};

%% Prep 

%time script started
d.timestamp_start_script = GetTimestamp;

%put inputs in data struct
d.participant_number = participant_number;
d.run_number = run_number;

%filenames 
d.filepath_order = sprintf('%sPAR%02d_RUN%02d.mat', p.DIR_ORDERS, d.participant_number, d.run_number);
d.filepath_data = sprintf('%sPAR%02d_RUN%02d_%s.mat', p.DIR_DATA, d.participant_number, d.run_number, d.timestamp_start_script);
d.filepath_error = strrep(d.filepath_data, '.mat', '_ERROR.mat');
d.filename_edf_on_system = sprintf('P%02d%s', d.participant_number, d.timestamp_edf);
d.filepath_run_edf = sprintf('%sParticipant_%02d_Run%03d_%s', p.DIR_PARTICIPANT_EDF, d.participant_number, d.run_number, d.timestamp);
d.filepath_practice_image_correct = sprintf('%scorrect_response_03.jpeg', p.DIR_IMAGES);
d.filepath_practice_image_incorrect = sprintf('%sincorrect_response_03.jpeg', p.DIR_IMAGES);


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

%Read orders 
load(d.filepath_order);
xls = xls;
d.order.raw = xls;
d.order.headers = xls(1,:);
d.order.data = xls(2:end,:);

%get number of trials from order  
d.number_trials = size(d.order.data, 1);

%get condition number from order 

%prepare start/stop beeps
freq = 48000;
beep_duration = 0.5;
beep_start = MakeBeep(500,beep_duration,freq);
sound_handle_beep_start = PsychPortAudio('Open', [], 1, [], freq, size(beep_start,1), [], p.SOUND.LATENCY);
PsychPortAudio('Volume', sound_handle_beep_start, p.SOUND.VOLUME);
PsychPortAudio('FillBuffer', sound_handle_beep_start, beep_start);

%% Try 
try
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
Screen('Flip', window);

%init
fprintf('Eyelink Connect...\n');
if p.USE_EYELINK 
    Eyelink.Collection.Connect
else
    Eyelink('InitializeDummy');
end 
    
%set window used
fprintf('Eyelink Set Window...\n');
if p.USE_EYELINK 
    Eyelink.Collection.SetupScreen(window)
else
    Eyelink('InitializeDummy');
end 

%set file to write to
fprintf('Eyelink Set EDF...\n');
if p.USE_EYELINK 
    Eyelink.Collection.SetEDF(d.filename_edf_on_system)
else
    Eyelink('InitializeDummy');
end

%calibrate
fprintf('Eyelink Calibration...\n');
if p.USE_EYELINK 
    Eyelink.Collection.Calibration
else
    Eyelink('InitializeDummy');
end

Screen('Flip', window);

sca
sca
%% Wait for Run Start 
fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start run or exit key (%s) to error out...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.EXIT.NAME);
while 1 
    [~,keys] = KbWait(-1,3);
    if any(keys(p.KEYS.RUN.VALUE))
      break;   
    else any(keys(p.KEYS.EXIT.VALUE))
        error ('Exit Key Pressed');
    end
end

%Time of Run start
t0 = GetSecs;
d.time_start_experiment = t0;
d.timestamp_start_experiment = GetTimestamp;

%% Practice Run
fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start the practice run or exit key (%s) to skip practice run...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.EXIT.NAME);

while 1
    [~,keys] = KbWait(-1,3);
    if any(keys(p.KEYS.RUN.VALUE))
        fprintf('\nCan error out of practice run with abort key (%s)...\n----------------------------------------------\n\n', p.KEYS.ABORT.NAME);

        for practice_trial = 1:4
            practice_movie_filepath = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_PRACTICE, practice_trial);
            message = "DISPLAY-VIDEO_NORMAL";
            Send(client, message);
            
            message = strcat("PLAY-VIDEO_NORMAL","-",practice_movie_filepath);
            Send(client, message);
            
            WaitSecs(10);
            
            message = "DISPLAY-PICTURE-BLACK_FRAME";
            Send(client, message);
          
            while 1
                [~,keys] = KbWait(-1,3);
                if any(keys(p.KEYS.YES.VALUE))
                    % correct_response_image_practice = imread(d.filepath_practice_image_correct);
                    
                    message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_practice_image_correct);
                    Send(client, message);
                    
                    WaitSecs(1);
                    break;
                elseif any(keys(p.KEYS.NO.VALUE))
                    %                 incorrect_response_image_practice = imread(d.filepath_practice_image_incorrect);
                    
                    message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_practice_image_incorrect);
                    Send(client, message);
                    
                    WaitSecs(1);
                    break;
                elseif any(keys(p.KEYS.ABORT.VALUE))
                    error('Abort key pressed');
                end
            end
        end
        break;
    elseif any(keys(p.KEYS.EXIT.VALUE))
        break;
    end
end

%% open serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
    sport=serial(p.TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
    fopen(sport);
else
    sport = nan;
end

%% Initial Baseline 
fprintf('\n----------------------------------------------\nWaiting for RUN key (%s) to start the baseline or ABORT key (%s)...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.ABORT.NAME);
while 1
    [~,keys] = KbWait(-1);
    if any(keys(p.KEYS.RUN.VALUE))
        break;
    else any(keys(p.KEYS.ABORT.VALUE))
        error ('Abort Key Pressed');
    end
end
message = "DISPLAY-TEXT-MESSAGE-We will now begin a 30 second baseline, please remain as still as possible";
Send(client, message);

WaitSecs(3);

message = "DISPLAY-TEXT-CLEAR";
Send(client, message);

message = "DISPLAY-PICTURE-BLACK_FRAME";
Send(client, message);

if p.TRIGGER_STIM_TRACKER
    fwrite(sport, ['mh',bin2dec('01000000'),0]);
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

%Check for abort key to end run
[~,~,keys] = KbCheck(-1);
if any(keys(p.KEYS.ABORT.VALUE))
    error('Exit Key Pressed');
end

if p.TRIGGER_STIM_TRACKER     
    fwrite(sport, ['mh',bin2dec('01000000'),0]); %turn off 2 
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]);
end   

fprintf('Baseline complete...\n'); 
%% Start Eyetracking Recording
Eyelink('StartRecording')
    
%% Enter trial phase
fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start the trial period or exit key (%s) to error out...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.EXIT.NAME);
while 1 
    [~,keys] = KbWait(-1);
    if any(keys(p.KEYS.RUN.VALUE))
      break;   
    else any(keys(p.KEYS.EXIT.VALUE))
        error ('Exit Key Pressed');
    end
end

fprintf('Starting Run...\n');
   
for trial = 1: d.number_trials 
    d.trial_data(trial).timing.onset = GetSecs - t0;
    d.latest_trial = trial;
       
    Eyelink('Message',sprintf('Event: Start of trial %03d\n', trial));
    fprintf('\nTrial %d (%g sec)\n', trial, d.trial_data(trial).timing.onset); 
    
    question_number = d.order.data{trial, 2};
   
    d.condition_number = xls{trial + 1, 3};

    %save condition type in data
    if d.condition_number == 1
        d.condition_type = sprintf('live_human');
    elseif d.condition_number == 2
        d.condition_type = sprintf('live_memoji');
    elseif d.condition_number == 3
        d.condition_type = sprintf('prerecorded_human');
    elseif d.condition_number == 4
        d.condition_type = sprintf('prerecorded_memoji');
    elseif ~d.condition_number
        error('No condition type available');
    end
    
    %filepaths dependent on knowing the condition number (this is an
    %unsophisticated work around)
    d.filepath_correct_image_response = sprintf('%scorrect_response_%02d.jpeg', p.DIR_IMAGES, d.condition_number);
    d.filepath_incorrect_image_response = sprintf('%sincorrect_response_%02d.jpeg', p.DIR_IMAGES, d.condition_number);

    
    if d.condition_number == 3
        movie_filepath = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_HUMAN, question_number);
    elseif d.condition_number == 4
        movie_filepath = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_MEMOJI, question_number);
    end

    d.trial_data(trial).correct_response = nan;
    d.trial_data(trial).timing.trigger.reaction = [];
    
    trial_in_progress = true; 
    phase = 0;
    while trial_in_progress
        [~,keys] = KbWait(-1,3);
        if any(keys(p.KEYS.QUESTION.VALUE)) && phase == 0
            %Play a beep to tell the confederate the trial has begun
            %start beep
            PsychPortAudio('Start', sound_handle_beep_start);
            fprintf('Start of question period %d...\n', trial);
            Eyelink('Message','Start of Question Period %d', trial);
            
            %TRIGGER STORY START
            if d.condition_number == 1
                message = "DISPLAY-LIVE_NORMAL";
                Send(client, message);
                
                if p.TRIGGER_STIM_TRACKER
                    fwrite(sport,['mh',bin2dec('00000001'),0]); %turn question period trigger on (for StimTracker)
                    d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
                    fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
                end
                
                WaitSecs(10);
            
            elseif d.condition_number == 2
                message = "DISPLAY-LIVE_MEMOJI";
                Send(client, message);
                
                if p.TRIGGER_STIM_TRACKER
                    fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
                    d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
                    fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
                end
                
                WaitSecs(10);
              
            elseif d.condition_number == 3 
                message = "DISPLAY-VIDEO_NORMAL";
                Send(client, message);
                
                message = strcat("PLAY-VIDEO_NORMAL", "-", movie_filepath);
                Send(client, message);
                
                if p.TRIGGER_STIM_TRACKER
                    fwrite(sport,['mh',bin2dec('00000100'),0]); %turn question period trigger on (for StimTracker)
                    d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
                    fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
                end
                           
                video_info = VideoReader(movie_filepath);
                movie_duration = video_info.Duration; 
                
                WaitSecs(movie_duration);
                                
            elseif d.condition_number == 4
                message = "DISPLAY-VIDEO_MEMOJI";
                Send(client, message);
                
                message = strcat("PLAY-VIDEO_MEMOJI", "-", movie_filepath);
                Send(client, message);

                if p.TRIGGER_STIM_TRACKER
                    fwrite(sport,['mh',bin2dec('00001000'),0]); %turn question period trigger on (for StimTracker)
                    d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
                    fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
                end
                              
                video_info = VideoReader(movie_filepath);
                movie_duration = video_info.Duration; 
                
                WaitSecs(movie_duration); 
            end
            
            [~,~,keys] = KbCheck(-1);
            if any(keys(p.KEYS.EXIT.VALUE)) %break is currently breaking out of the larger while loop as well
                %ends current trial
                trial_in_progress = false;
                break;
            elseif any(keys(p.KEYS.ABORT.VALUE))
                d.number_trials = trial;
                error('Abort key pressed');
            end
            phase = 1;
            
            message = "DISPLAY-PICTURE-BLACK_FRAME";
            Send(client, message);
            
            Eyelink('Message','End of Question Period %d', trial);
            fprintf('End of question period %d...\n', trial);
            
        elseif any(keys(p.KEYS.ANSWER.VALUE)) && phase == 1
            fprintf('Start of answer period %d...\n', trial);
            
            %TRIGGER START OF ANSWER PERIOD LIVE
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('00010000'),0]); %turn question period trigger on (for StimTracker)
                d.trial_data(trial).timing.trigger.answer_period_start = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            Eyelink('Message','Start of Answer Period %d', trial);
            WaitSecs(3);
            
            [~,~,keys] = KbCheck(-1);
            if any(keys(p.KEYS.EXIT.VALUE)) %KS revisit this (no abort, etc)
                %ends current trial
                trial_in_progress = false;
                break;
            elseif any(keys(p.KEYS.ABORT.VALUE))
                d.number_trials = trial;
                error('Abort key pressed');
            end
            
            fprintf('End of answer period %d...\n', trial);
            phase = 3;
            %display image response if in pre-recorded conditions
        elseif any(keys(p.KEYS.YES.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= true) && (d.condition_number == 3 || d.condition_number == 4)
            
            message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_correct_image_response);
            Send(client, message);
            Eyelink('Message','Answer correct for trial %d', trial);
            
            
            %TRIGGER REACTION PRERECORDED
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('10000000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            WaitSecs(1);
            
            message = "DISPLAY-PICTURE-BLACK_FRAME";
            Send(client, message);
            
            d.trial_data(trial).correct_response = true;
            
            phase = 3;
            
        elseif any(keys(p.KEYS.NO.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= false) && (d.condition_number == 3 || d.condition_number == 4)
            
            message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_incorrect_image_response);
            Send(client, message); 
            
            Eyelink('Message','Answer incorrect for trial %d', trial);
            
            %TRIGGER REACTION PRERECORDED
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('10000000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            WaitSecs(1);
            
            message = "DISPLAY-PICTURE-BLACK_FRAME";
            Send(client, message);
            
            d.trial_data(trial).correct_response = true;
                        
            phase = 3;
            
            %display live video feed for reaction response
        elseif any(keys(p.KEYS.YES.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= true) && (d.condition_number == 3 || d.condition_number == 4)
            
            if d.condition_number == 1
                message = "DISPLAY-LIVE_NORMAL";
                Send(client, message);
            elseif d.condition_number == 2
                message = "DISPLAY-LIVE_MEMOJI";
                Send(client, message);
            end
            
            Eyelink('Message','Answer correct for trial %d', trial);
            
            %TRIGGER REACTION PRERECORDED
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('10000000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = true;
            
            WaitSecs(1);
            
            message = "DISPLAY-PICTURE-BLACK_FRAME";
            Send(client, message);
            
            phase = 3;
        elseif any(keys(p.KEYS.YES.VALUE)) && phase >= 2 && (d.trial_data(trial).correct_response ~= true) && (d.condition_number == 1 || d.condition_number == 2)
            
            if d.condition_number == 1
                message = "DISPLAY-LIVE_NORMAL";
                Send(client, message);
            elseif d.condition_number == 2
                message = "DISPLAY-LIVE_MEMOJI";
                Send(client, message);
            end
            
            Eyelink('Message','Answer incorrect for trial %d', trial);
            
            %TRIGGER REACTION PRERECORDED
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',bin2dec('10000000'),0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = true;
            
            WaitSecs(1);
            
            message = "DISPLAY-PICTURE-BLACK_FRAME";
            Send(client, message);
            
            phase = 3;
            
            %triggers the end of the current run
        elseif any(keys(p.KEYS.STOP.VALUE)) && phase == 3
            
            d.trial_data(trial).timing.offset = GetSecs - t0;
            trial_in_progress = false;
            
            message = "DISPLAY-PICTURE-BLACK_FRAME";
            Send(client, message);
        elseif any(keys(p.KEYS.EXIT.VALUE))
            %ends current trial
            trial_in_progress = false;
            
            %end of trial and save data
            fprintf('End of trial %03d\n', trial)
        
            break;
        elseif any(keys(p.KEYS.ABORT.VALUE)) %error out of the run
            d.number_trials = trial;
            error('Abort key pressed');
        end
    end
        
        %ITI
        %jitter the trial ITI (save the variable)
        ITI = [1 2 3 4];
        ITI_index = randi(numel(ITI));
        d.trial_data(trial).trial_end_wait = ITI(ITI_index);
        WaitSecs(d.trial_data(trial).trial_end_wait);
        
        if p.TRIGGER_STIM_TRACKER
            fwrite(sport,['mh',bin2dec('00000001'),0]);
            Eyelink('Message','Event: End of trial %03d\n', trial);
            d.trial_data(trial).timing.offset = GetSecs - t0;
            fwrite(sport,['mh',bin2dec('00000000'),0]);
        end
        
        fprintf('Saving...\n');
        save(d.filepath_data, 'p', 'd')
    end

%% Drift Check 
message = "DISPLAY-TEXT-MESSAGE-Fixate on the centre of the dot on the bottom middle of the screen";
Send(client, message);

WaitSecs(3);

message = "DISPLAY-TEXT-CLEAR";
Send(client, message);

message = "DISPLAY-PICTURE-BLACK_FRAME";
Send(client, message);

Eyelink('Message',sprintf('Drift Check'));

WaitSecs(2);

%% Stop eyelink recording
fprintf('Eyelink Close');   

if p.USE_EYELINK 
    Eyelink.Collection.Close
else
    Eyelink('InitializeDummy');
end 
%% Final Baseline
message = "DISPLAY-TEXT-MESSAGE-We will now begin a 30 second baseline, please remain as still as possible";
Send(client, message);

WaitSecs(3);

message = "DISPLAY-TEXT-CLEAR";
Send(client, message);

message = "DISPLAY-PICTURE-BLACK_FRAME";
Send(client, message);

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

%% trigger stim tracker (end of exp which is also end of baseline)
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
end 

function Send(client, message)
    fopen(client);
    fwrite(client, message);
    fclose(client);
    fprintf('%s\n',message);
end
end 

