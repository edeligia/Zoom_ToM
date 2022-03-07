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
p.DIR_IMAGES = [pwd filesep 'Images' filesep];
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
% Create the UDP connection to broadcast messages on port 7000
sharedPort = 7000;
% Note the submask of 255.255.255.255 might not work everywhere.  Will have to contact
% Haitao for the one used in the WIRB
udpSender = udp('255.255,255,255', sharedPort,...
                'LocalPort', sharedPort);
            
% Enable port sharing to allow multiple clients on the same PC to bind to 
% the same port
udpSender.EnablePortSharing = 'on';
udpSender.Terminator = 'CR';
udpSender.BytesAvailableFcnMode = 'terminator';
udpSender.BytesAvailableFcn = @(~,~)fprintf('Message "%s" at %s\n', fgetl(udpSender), datestr(now));
fopen(udpSender);

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
d.filepath_practice_image_correct = 'Pictures/Human/correct';
d.filepath_practice_image_incorrect = 'Pictures/Human/incorrect';
d.filepath_drift_check_image = sprintf('%sdrift_check.png', p.DIR_IMAGES);
d.filepath_fixation_image = sprintf('%sfixation.png', p.DIR_IMAGES);


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

fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start calibration or abort key (%s) to error out...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.ABORT.NAME);
while 1
    [~,keys] = KbWait(-1,3);
    if any(keys(p.KEYS.RUN.VALUE))
        break;
    else any(keys(p.KEYS.ABORT.VALUE))
        error ('Abort Key Pressed');
    end
end

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
fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start run or abort key (%s) to error out...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.ABORT.NAME);
while 1 
    [~,keys] = KbWait(-1,3);
    if any(keys(p.KEYS.RUN.VALUE))
      break;   
    else any(keys(p.KEYS.ABORT.VALUE))
        error ('Abort Key Pressed');
    end
end

%Time of Run start
t0 = GetSecs;
d.time_start_experiment = t0;
d.timestamp_start_experiment = GetTimestamp;

%% Practice Run
fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start the practice run or stop key (%s) to skip practice run...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.STOP.NAME);

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
            
            message = "STOP-VIDEO_NORMAL";
            Send(client, message);
            
            address = '/display/clear';
            oscsend(udpSender,address);
            
            while 1
                [~,keys] = KbWait(-1,3);
                if any(keys(p.KEYS.YES.VALUE))
                    % correct_response_image_practice = imread(d.filepath_practice_image_correct);
                    
                    address = '/display/picture';
                    oscsend(udpSender,address,'s', d.filepath_practice_image_correct);

                    WaitSecs(1);
                    
                    address = '/display/clear';
                    oscsend(udpSender,address);
                    break;
                elseif any(keys(p.KEYS.NO.VALUE))
                    %incorrect_response_image_practice = imread(d.filepath_practice_image_incorrect);
                    
                    address = '/display/picture';
                    oscsend(udpSender,address,'s', d.filepath_practice_image_incorrect);

                    
                    WaitSecs(1);
                    
                    address = '/display/clear';
                    oscsend(udpSender,address);
                    break;
                elseif any(keys(p.KEYS.ABORT.VALUE))
                    error('Abort key pressed');
                end
            end
        end
        break;
    elseif any(keys(p.KEYS.STOP.VALUE))
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
%Display a text message to the screen.  Can also just send text with nothing for
%a clear message.

message = 'We will now begin a 30 second baseline, please remain as still as possible';
address = '/display/message';
oscsend(udpSender,address,'s', message);

WaitSecs(3);

address = '/display/clear';
oscsend(udpSender,address);

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
    error('Abort Key Pressed');
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
fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start the trial period or stop key (%s) to error out...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.STOP.NAME);
while 1
    [~,keys] = KbWait(-1);
    if any(keys(p.KEYS.RUN.VALUE))
        break;
    else any(keys(p.KEYS.ABORT.VALUE))
        error ('Abort Key Pressed');
    end
end

fprintf('Starting Run...\n');

for trial = 1: d.number_trials
    d.trial_data(trial).timing.onset = GetSecs - t0;
    d.latest_trial = trial;
    
    %jitter the trial ITI (save the variable)
    ITI = [1 2 3 4];
    ITI_index = randi(numel(ITI));
    d.trial_data(trial).trial_end_wait = ITI(ITI_index);
    
    [~,~,keys] = KbCheck(-1);
    if any(keys(p.KEYS.STOP.VALUE))
        %ends current trial
        break;
    elseif any(keys(p.KEYS.ABORT.VALUE))
        d.number_trials = trial;
        error('Abort key pressed');
    end
    
    %Calculate length of trial 
    trial_length = 14 +  d.trial_data(trial).trial_end_wait;
    %Send the amount of tile for the current trial. 
    address = '/duration/trial';
    oscsend(udpSender,address,'i', trial_length);

    %     %Calculate time until next live trial and send to unity
    %     while 1
    %         next_condition_number = xls{trial + 2,3};
    %         if next_condition_number == 1 || next_condition_number == 2
    %         message = strcat("DURATION_LIVE-",string(trial_length));
    %         Send(client, message);
    %         break;
    %         else
    %             next_condition_number = next_condition_number + 1;
    %         end
    %     end
    %
    %     next_live_trial_number =
    %     message = strcat("DURATION_LIVE-",string(10));
    %     Send(client, message);
    %
    Eyelink('Message',sprintf('Event: Start of trial %03d\n', trial));
    fprintf('\nTrial %d (%g sec)\n', trial, d.trial_data(trial).timing.onset);
    
    question_number = d.order.data{trial, 2};
    
    d.condition_number = xls{trial + 1, 3};
    
    %save condition type in data
    if d.condition_number == 1
        d.trial_data(trial).condition_type = sprintf('live_human');
    elseif d.condition_number == 2
        d.trial_data(trial).condition_type = sprintf('live_memoji');
    elseif d.condition_number == 3
        d.trial_data(trial).condition_type = sprintf('prerecorded_human');
    elseif d.condition_number == 4
        d.trial_data(trial).condition_type = sprintf('prerecorded_memoji');
    elseif ~d.condition_number
        error('No condition type available');
    end
    
    %filepaths dependent on knowing the condition number (this is an
    %unsophisticated work around)
      
    d.filepath_correct_image_response = sprintf('%s/correct_response_%02d.jpeg', 'Images', d.condition_number);
    d.filepath_incorrect_image_response = sprintf('%s/incorrect_response_%02d.jpeg', 'Images', d.condition_number);
    
    
    if d.condition_number == 3
        movie_filepath = sprintf('%s/%d_question.mp4', 'Videos/Human' , question_number);
    elseif d.condition_number == 4
        movie_filepath = sprintf('%s/%d_question.mp4', 'Videos/Memoji', question_number);
    end
    
    d.trial_data(trial).correct_response = nan;
    d.trial_data(trial).timing.trigger.reaction = [];
    
    %Play a beep to tell the confederate and partici[ant the question period has begun
    %start beep
    PsychPortAudio('Start', sound_handle_beep_start);
    fprintf('Start of question period %d...\n', trial);
    Eyelink('Message','Start of Question Period %d', trial);
    
    %TRIGGER STORY START
    if d.condition_number == 1
        %Display a live video feed of the researcher
        address = '/display/live';
        oscsend(udpSender,address,'s','researcher');
        
        if p.TRIGGER_STIM_TRACKER
            fwrite(sport,['mh',bin2dec('00000001'),0]); %turn question period trigger on (for StimTracker)
            d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
            fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
        end
        
        WaitSecs(10);
        
    elseif d.condition_number == 2
        %Display a live video feed of the memoji user
        address = '/display/live';
        oscsend(udpSender,address,'s','memoji');
        
        if p.TRIGGER_STIM_TRACKER
            fwrite(sport,['mh',bin2dec('00000010'),0]); %turn question period trigger on (for StimTracker)
            d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
            fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
        end
        
        WaitSecs(10);
        
    elseif d.condition_number == 3
        address = '/duration/video';
        oscsend(udpSender,address,'s', movie_filepath);
                
        if p.TRIGGER_STIM_TRACKER
            fwrite(sport,['mh',bin2dec('00000100'),0]); %turn question period trigger on (for StimTracker)
            d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
            fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
        end
        
        video_info = VideoReader(movie_filepath);
        movie_duration = video_info.Duration;
        
        WaitSecs(movie_duration);
        
    elseif d.condition_number == 4
        address = '/duration/video';
        oscsend(udpSender,address,'s', movie_filepath);
        
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
    if any(keys(p.KEYS.STOP.VALUE)) %break is currently breaking out of the larger while loop as well
        %ends current trial
        break;
    elseif any(keys(p.KEYS.ABORT.VALUE))
        d.number_trials = trial;
        error('Abort key pressed');
    end
    
    message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_fixation_image);
    Send(client, message);
    
    Eyelink('Message','End of Question Period %d', trial);
    fprintf('End of question period %d...\n', trial);
    
    %START OF ANSWER PERIOD
    %Play a beep to tell the confederate and partici[ant the answer period has begun
    %start beep
    PsychPortAudio('Start', sound_handle_beep_start);
    fprintf('Start of answer period %d...\n', trial);
    Eyelink('Message','Start of Answer Period %d', trial);
    
    %TRIGGER START OF ANSWER PERIOD
    if p.TRIGGER_STIM_TRACKER
        fwrite(sport,['mh',bin2dec('00010000'),0]); %turn question period trigger on (for StimTracker)
        d.trial_data(trial).timing.trigger.answer_period_start = GetSecs - t0;
        fwrite(sport,['mh',bin2dec('00000000'),0]);
    end
    
    WaitSecs(3);
    
    [~,~,keys] = KbCheck(-1);
    if any(keys(p.KEYS.STOP.VALUE))
        %ends current trial
        break;
    elseif any(keys(p.KEYS.ABORT.VALUE))
        d.number_trials = trial;
        error('Abort key pressed');
    end
    
    fprintf('End of answer period %d...\n', trial);
    %START OF FEEDBACK PHASE    
    while 1
        [~,keys] = KbWait(-1);
        %display image response if in pre-recorded conditions
        if any(keys(p.KEYS.YES.VALUE)) && (d.trial_data(trial).correct_response ~= true) && (d.condition_number == 3 || d.condition_number == 4)
            
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
            
            message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_fixation_image);
            Send(client, message);
            
            d.trial_data(trial).correct_response = true;
            
            break;
            
        elseif any(keys(p.KEYS.NO.VALUE)) && (d.trial_data(trial).correct_response ~= false) && (d.condition_number == 3 || d.condition_number == 4)
            
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
            
            message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_fixation_image);
            Send(client, message);
            
            d.trial_data(trial).correct_response = true;
            
            break;
            
            %display live video feed for reaction response
        elseif any(keys(p.KEYS.YES.VALUE)) && (d.trial_data(trial).correct_response ~= true) && (d.condition_number == 1 || d.condition_number == 2)
            
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
            
            message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_fixation_image);
            Send(client, message);
            
            break;
            
        elseif any(keys(p.KEYS.NO.VALUE)) && (d.trial_data(trial).correct_response ~= true) && (d.condition_number == 1 || d.condition_number == 2)
            
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
            
            message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_fixation_image);
            Send(client, message);
            
            break;
            %triggers the end of the current run            
        elseif any(keys(p.KEYS.STOP.VALUE))
            %end of trial and save data
            fprintf('End of trial %03d\n', trial)
            
            break;
        elseif any(keys(p.KEYS.ABORT.VALUE)) %error out of the run
            d.number_trials = trial;
            error('Abort key pressed');
        end
    end
    
    %ITI
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
message = 'Fixate on the centre of the dot on the bottom middle of the screen';
address = '/display/message';
oscsend(udpSender,address,'s', message);

WaitSecs(3);

address = '/display/clear';
oscsend(udpSender,address);

message = strcat("DISPLAY-PICTURE-FILE", "-", d.filepath_drift_check_image);
Send(client, message);

Eyelink('Message',sprintf('Drift Check'));

WaitSecs(2);

address = '/display/clear';
oscsend(udpSender,address);
%% Stop eyelink recording
fprintf('Eyelink Close');   

if p.USE_EYELINK 
    Eyelink.Collection.Close
else
    Eyelink('InitializeDummy');
end 
%% Final Baseline
message = 'We will now begin a 30 second baseline, please remain as still as possible';
address = '/display/message';
oscsend(udpSender,address,'s', message);

WaitSecs(3);

address = '/display/clear';
oscsend(udpSender,address);

fprintf('Final baseline...\n');
tend = GetSecs + p.DURATION_BASELINE_FINAL;
while 1
    ti = GetSecs;
    if ti > tend
        break;
    end
    
    [~,~,keys] = KbCheck(-1);  
    if any(keys(p.KEYS.ABORT.VALUE))
        error('Error Key Pressed');
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

%% Clean up - close unity connection
fclose(udpSender);
delete(udpSender);
clear udpSender;

%done
disp('Run complete!');

%% Catch
%catch if error
catch err
    %close screen if open
%     Screen('Close', window);
    sca
    sca
    
    address = '/display/clear';
    oscsend(udpSender,address);
    
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
    
    %Close Unity Connection
    fclose(udpSender);
    delete(udpSender);
    clear udpSender;
    
    %rethrow error for troubleshooting
    rethrow(err)
end 
%% Functions
function [timestamp, timestamp_edf] = GetTimestamp
c = round(clock);
timestamp = sprintf('%d-%d-%d_%d-%d_%d',c([4 5 6 3 2 1]));
timestamp_edf = sprintf('%02d%02d', c(5:6));
end 

function oscsend(u,path,varargin)
% Sends a Open Sound Control (OSC) message through a UDP connection
%
% oscsend(u,path)
% oscsend(u,path,types,arg1,arg2,...)
% oscsedn(u,path,types,[args])
%
% u = UDP object with open connection.
% path = path-string
% types = string with types of arguments,
%    supported:
%       i = integer
%       f = float
%       s = string
%       N = Null (ignores corresponding argument)
%       I = Impulse (ignores corresponding argument)
%       T = True (ignores corresponding argument)
%       F = False (ignores corresponding argument)
%       B = boolean (not official: converts argument to T/F in the type)
%    not supported:
%       b = blob
%
% args = arguments as specified by types.
%
% EXAMPLE
%       u = udp('127.0.0.1',7488);  
%       fopen(u);
%       oscsend(u,'/test','ifsINBTF', 1, 3.14, 'hello',[],[],false,[],[]);
%       fclose(u);
%
% See http://opensoundcontrol.org/ for more information about OSC.

% MARK MARIJNISSEN 10 may 2011 (markmarijnissen@gmail.com)
    
    %figure out little endian for int/float conversion
    [~, ~, endian] = computer;
    littleEndian = endian == 'L';

    % set type
    if nargin >= 2,
        types = oscstr([',' varargin{1}]);
    else
        types = oscstr(',');
    end;
    
    % set args (either a matrix, or varargin)
    if nargin == 3 && length(types) > 2
        args = varargin{2};
    else
        args = varargin(2:end);
    end;

    % convert arguments to the right bytes
    data = [];
    for i=1:length(args)
        switch(types(i+1))
            case 'i'
                data = [data oscint(args{i},littleEndian)];
            case 'f'
                data = [data oscfloat(args{i},littleEndian)];
            case 's'
                data = [data oscstr(args{i})];
            case 'B'
                if args{i}
                    types(i+1) = 'T';
                else
                    types(i+1) = 'F';
                end;
            case {'N','I','T','F'}
                %ignore data
            otherwise
                warning(['Unsupported type: ' types(i+1)]);
        end;
    end;
    
    %write data to UDP
    data = [oscstr(path) types data];
    fwrite(u,data);
end

%Conversion from double to float
function float = oscfloat(float,littleEndian)
   if littleEndian
        float = typecast(swapbytes(single(float)),'uint8');
   else
        float = typecast(single(float),'uint8');
   end;
end

%Conversion to int
function int = oscint(int,littleEndian)
   if littleEndian
        int = typecast(swapbytes(int32(int)),'uint8');
   else
        int = typecast(int32(int),'uint8');
   end;
end

%Conversion to string (null-terminated, in multiples of 4 bytes)
function string = oscstr(string)
    string = [string 0 0 0 0];
    string = string(1:end-mod(length(string),4));
end
end 

