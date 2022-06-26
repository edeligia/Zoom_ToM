function ME_Zoom(participant_number, run_number)
%% Notes 
% condition numbers 
% 1 = live + human
% 2 = live + memoji 
% 3 = pre-recorded + human 
% 4 = pre-recorded + memoji 

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
p.DIR_VIDEOSTIMS_PRACTICE = ['Videos' filesep 'Practice_Stims' filesep]; 

%stim tracker
%the left port on Eva's laptop is COM3 and on the culham lab msi laptop 
p.TRIGGER_CABLE_COM_STRING = 'COM6';

%timings
p.DURATION_BASELINE = 30;
p.DURATION_BASELINE_FINAL = 30;

%buttons
p.KEYS.RUN.NAME = 'RETURN';
p.KEYS.YES.NAME = 'Y';
p.KEYS.NO.NAME = 'N';
p.KEYS.SKIP.NAME = 'SPACE';
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
d.filepath_practice_image_correct = 'Images/correct_response_03.jpeg';
d.filepath_practice_image_incorrect = 'Images/incorrect_response_03.jpeg';

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
%% Chat and participant instructions
%Change the layout of both applications to the chat interface.  The Participant and
%Researcher users will be made visible for this portion.

command = "UI_PARTICIPANT/Conceal";
TCPSend(command);

%Option 1 for changing the mode of the Researcher to Setup
command = "MODE_RESEARCHER/0";
TCPSend(command);

%Option 2 for changing the mode of the Participant to Focus
value = 1;
command = "MODE_PARTICIPANT/"+value;
TCPSend(command);

%Display a live video feed of the researcher
%Switch the main live source to the Researcher
command = "DISPLAY_LIVE/Researcher";
TCPSend(command);

% 0 = Setup layout
% 1 = Chat layout 
% 2 = Full Screen layout

%Unmute the microphone of the researcher
state = 'false';
command = "MUTE_RESEARCHER/"+state;
TCPSend(command);

%Unmute the microphone of the participant
state = 'false';
command = "MUTE_PARTICIPANT/"+state;
TCPSend(command);


%Notify the researcher that the experimental run has started 
command = "EXPERIMENT_START";
TCPSend(command);
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

%% open serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
    sport=serial(p.TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
    fopen(sport);
else
    sport = nan;
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

%Option 2 for changing the mode of the Participant to Focus
value = 2;
command = "MODE_PARTICIPANT/"+value;
TCPSend(command);

%Muting all users
command = "MUTE/True";
TCPSend(command);

%% Practice Run
fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start the practice run or skip key (%s) to skip practice run...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.SKIP.NAME);

while 1
    [~,keys] = KbWait(-1,3);
    if any(keys(p.KEYS.RUN.VALUE))
        fprintf('\nCan error out of practice run with abort key (%s)...\n----------------------------------------------\n\n', p.KEYS.ABORT.NAME);
        
        for practice_trial = 1:4
            practice_movie_filepath = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_PRACTICE, practice_trial);

            message = 'Pre-recorded';
            command = "DISPLAY_MESSAGE/"+message;
            TCPSend(command);

            
            WaitSecs(1);
            
            %Play a beep to tell the confederate and partici[ant the question period has begun
            %start beep
            PsychPortAudio('Start', sound_handle_beep_start);

         
            path = practice_movie_filepath;
            command = "DISPLAY_VIDEO/"+path;
            TCPSend(command);
            
            WaitSecs(10);
            
            path = 'Images/fixation.png';
            command = "DISPLAY_PICTURE/"+path;
            TCPSend(command);
            
            %START OF ANSWER PERIOD
            %Play a beep to tell the confederate and partici[ant the answer period has begun
            %start beep
            PsychPortAudio('Start', sound_handle_beep_start);

            WaitSecs(3);
           
            command = 'DISPLAY_CLEAR';
            TCPSend(command);

            %Wait for key press to show reponse
            while 1
                [~,keys] = KbWait(-1,3);
                if any(keys(p.KEYS.YES.VALUE))
                    % correct_response_image_practice = imread(d.filepath_practice_image_correct);
                    
                    path =  d.filepath_practice_image_correct;
                    command = "DISPLAY_PICTURE/"+path;
                    TCPSend(command);

                    WaitSecs(1);
                    
                    command = 'DISPLAY_CLEAR';
                    TCPSend(command);
            
                    break;
                elseif any(keys(p.KEYS.NO.VALUE))
                    %incorrect_response_image_practice = imread(d.filepath_practice_image_incorrect);
                    
                    path =  d.filepath_practice_image_incorrect;
                    command = "DISPLAY_PICTURE/"+path;
                    TCPSend(command);
                    
                    WaitSecs(1);
                    
                    command = 'DISPLAY_CLEAR';
                    TCPSend(command);
                    break;
                elseif any(keys(p.KEYS.ABORT.VALUE))
                    error('Abort key pressed');
                end
            end
            
            command = 'DISPLAY_CLEAR';
            TCPSend(command);
        end
        break;
    elseif any(keys(p.KEYS.SKIP.VALUE))
        break;
    end
end

%% Initial Baseline 
fprintf('\n----\nSTART FNIRS RECORDING NOW\n-------\n\n');
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
command = "DISPLAY_MESSAGE/"+message;
TCPSend(command);

WaitSecs(3);

message = '';
command = "DISPLAY_MESSAGE/"+message;
TCPSend(command);

if p.TRIGGER_STIM_TRACKER
    fwrite(sport, ['mh',5,0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
end

tbaseline = GetSecs; 
fprintf('Initial baseline...\n');
tend = tbaseline + p.DURATION_BASELINE;

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

%Check for abort key to end run
[~,~,keys] = KbCheck(-1);
if any(keys(p.KEYS.ABORT.VALUE))
    error('Abort Key Pressed');
end 

fprintf('Baseline complete...\n'); 
%% Start Eyetracking Recording
Eyelink('StartRecording')
    
%% Enter trial phase
fprintf('\n----------------------------------------------\nWaiting for run key (%s) to start the trial period or abort key (%s) to error out...\n----------------------------------------------\n\n', p.KEYS.RUN.NAME, p.KEYS.ABORT.NAME);
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
    %Trigger statt of trial
    
    if p.TRIGGER_STIM_TRACKER
        fwrite(sport,['mh',6,0]);
        Eyelink('Message','Event: Start of trial %03d\n', trial);
        d.trial_data(trial).timing.onset = GetSecs - t0;
        fwrite(sport,['mh',bin2dec('00000000'),0]);
    end
        
    question_number = d.order.data{trial, 2};
    d.condition_number = xls{trial + 1, 3};
    ITI = d.order.data{trial,4};
    
    %define trial as either live or pre-recorded 
    if d.condition_number == 1
        d.trial_data(trial).liveness_type = sprintf('Live');
    elseif d.condition_number == 2
        d.trial_data(trial).liveness_type = sprintf('Live');
    elseif d.condition_number == 3
        d.trial_data(trial).liveness_type = sprintf('Pre-recorded');
    elseif d.condition_number == 4
        d.trial_data(trial).liveness_type = sprintf('Pre-recorded');
    elseif ~d.condition_number
        error('No condition type available');
    end
    
    message = d.trial_data(trial).liveness_type;
    command = "DISPLAY_MESSAGE/"+message;
    TCPSend(command);

    if d.condition_number == 1 || 2
        command = "DISPLAY_QUESTION/"+question_number;
        TCPSend(command);
    end
    
    WaitSecs(1);
    
    %Notify researcher that a new trial has begun
    command = "TRIAL_START";
    TCPSend(command);

    
%     %jitter the trial ITI (save the variable)
%     ITI = [1 2 3 4];
%     ITI_index = randi(numel(ITI));
%     d.trial_data(trial).trial_end_wait = ITI(ITI_index);
    
    [~,~,keys] = KbCheck(-1);
    if any(keys(p.KEYS.SKIP.VALUE))%ends current trial
        d.trial_data(trial).flag = true; 
        save(d.filepath_data, 'p', 'd')
        break;
    elseif any(keys(p.KEYS.ABORT.VALUE))
        d.number_trials = trial;
        error('Abort key pressed');
    end
    
    %Mute the microphone of the participant
    state = 'true';
    command = "MUTE_PARTICIPANT/"+state;
    TCPSend(command);

    duration_question = 10;
    %Send the amount of time for the current question period. 
    command = "CLOCK_START_TRIAL/"+duration_question;
    TCPSend(command);

%     %Calculate length of trial and send the duration of the current trial
%     trial_length = 14 +  ITI;
%     command = "CLOCK_START_WAIT/"+trial_length;
%     TCPSend(command);
 
    Eyelink('Message',sprintf('Event: Start of condition %03d\n', d.condition_number));
    fprintf('\nTrial %d (%g sec)\n', trial, d.trial_data(trial).timing.onset);
     
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
    if d.condition_number == 3  
        d.filepath_correct_image_response = sprintf('%s/correct_response_%02d.jpeg', 'Images', d.condition_number);
        d.filepath_incorrect_image_response = sprintf('%s/incorrect_response_%02d.jpeg', 'Images', d.condition_number);
    elseif d.condition_number == 4
        d.filepath_correct_image_response = sprintf('%s/correct_response_%02d.jpeg', 'Images', d.condition_number);
        d.filepath_incorrect_image_response = sprintf('%s/incorrect_response_%02d.jpeg', 'Images', d.condition_number);  
    end
       
    if d.condition_number == 3
        movie_filepath = sprintf('%s/%d_question.mp4', 'Videos/Human' , question_number);
    elseif d.condition_number == 4
        movie_filepath = sprintf('%s/%d_question.mp4', 'Videos/Memoji', question_number);
    end
    
     if d.condition_number == 3
        movie_filepath_matlab = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_HUMAN, question_number);
    elseif d.condition_number == 4
        movie_filepath_matlab = sprintf('%s%d_question.mp4', p.DIR_VIDEOSTIMS_MEMOJI, question_number);
     end 
    
    d.trial_data(trial).correct_response = nan;
    d.trial_data(trial).timing.trigger.reaction = [];
    
    %Play a beep to t  ell the confederate and partici[ant the question period has begun
    %start beep
    PsychPortAudio('Start', sound_handle_beep_start);
    fprintf('Start of question period %d...\n', trial);
    Eyelink('Message','Start of Question Period %d', trial);
    
    %TRIGGER STORY START
    if d.condition_number == 1

        %Mute the microphone of the memoji
        state = 'true';
        command = "MUTE_MEMOJI/"+state;
        TCPSend(command);
        
        %Unmute the microphone of the researcher
        state = 'false';
        command = "MUTE_RESEARCHER/"+state;
        TCPSend(command);
        
        %Display a live video feed of the researcher
        command = "DISPLAY_LIVE/Researcher";
        TCPSend(command);
        

        %Start recording Human video
        type = 'Human';
        command = "RECORD_START/"+type+"&"+question_number+"_question";
        TCPSend(command);
        
        if p.TRIGGER_STIM_TRACKER
            fwrite(sport,['mh',1,0]); %turn question period trigger on (for StimTracker)
            d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
            fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
        end
        
        WaitSecs(10);
        
        %Stop recording Human video
        command = "RECORD_STOP";
        TCPSend(command);
                
        %Mute the microphone of the researcher
        state = 'true';
        command = "MUTE_RESEARCHER/"+state;
        TCPSend(command);
        
    elseif d.condition_number == 2

        %Mute the microphone of the researcher
        state = 'true';
        command = "MUTE_RESEARCHER/"+state;
        TCPSend(command);
        
        %Unmute the microphone of the memoji
        state = 'false';
        command = "MUTE_MEMOJI/"+state;
        TCPSend(command);

        %Display a live video feed of the memoji user
        command = "DISPLAY_LIVE/Memoji";
        TCPSend(command);
        
        %Start recording Memoji video
        type = "Memoji";
        command = "RECORD_START/"+type+"&"+question_number+"_question";
        TCPSend(command);
        
        if p.TRIGGER_STIM_TRACKER
            fwrite(sport,['mh',2,0]); %turn question period trigger on (for StimTracker)
            d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
            fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
        end
        
        WaitSecs(10);
        
        %Stop recording Human video 
        command = "RECORD_STOP";
        TCPSend(command);
        
        %Mute the microphone of the memoji
        state = 'true';
        command = "MUTE_MEMOJI/"+state;
        TCPSend(command);
        
    elseif d.condition_number == 3
        %Mute all users
        command = "MUTE/True";
        TCPSend(command);
        
        path = movie_filepath;
        command = "DISPLAY_VIDEO/"+path;
        TCPSend(command);
                
        if p.TRIGGER_STIM_TRACKER
            fwrite(sport,['mh',3,0]); %turn question period trigger on (for StimTracker)
            d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
            fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
        end
        
        video_info = VideoReader(movie_filepath_matlab);
        movie_duration = video_info.Duration;
        
        WaitSecs(movie_duration);
        
    elseif d.condition_number == 4
        %Mute all users
        command = "MUTE/True";
        TCPSend(command);
        
        path = movie_filepath;
        command = "DISPLAY_VIDEO/"+path;
        TCPSend(command);
        
        if p.TRIGGER_STIM_TRACKER
            fwrite(sport,['mh', 4 ,0]); %turn question period trigger on (for StimTracker)
            d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
            fwrite(sport,['mh',bin2dec('00000000'),0]); %turn question period trigger off (for StimTracker)
        end
        
        video_info = VideoReader(movie_filepath_matlab);
        movie_duration = video_info.Duration;
        
        WaitSecs(movie_duration);
    end
    
    [~,~,keys] = KbCheck(-1);
    if any(keys(p.KEYS.SKIP.VALUE)) %break is currently breaking out of the larger while loop as well
        %ends current trial
        d.trial_data(trial).flag = true; 
        save(d.filepath_data, 'p', 'd')
        break;
    elseif any(keys(p.KEYS.ABORT.VALUE))
        d.number_trials = trial;
        error('Abort key pressed');
    end
    
    path = 'Images/fixation.png';
    command = "DISPLAY_PICTURE/"+path;
    TCPSend(command);

    Eyelink('Message','End of Question Period %d', trial);
    fprintf('End of question period %d...\n', trial);
    
    %Unmute the microphone of the participant
    state = 'false';
    command = "MUTE_PARTICIPANT/"+state;
    TCPSend(command)
    
    %START OF ANSWER PERIOD
    %Play a beep to tell the confederate and partici[ant the answer period has begun
    %start beep
    PsychPortAudio('Start', sound_handle_beep_start);
    fprintf('Start of answer period %d...\n', trial);
    Eyelink('Message','Start of Answer Period %d', trial);
    
    %TRIGGER START OF ANSWER PERIOD
    if p.TRIGGER_STIM_TRACKER
        fwrite(sport,['mh',7,0]); %turn question period trigger on (for StimTracker)
        d.trial_data(trial).timing.trigger.answer_period_start = GetSecs - t0;
        fwrite(sport,['mh',bin2dec('00000000'),0]);
    end
    
    WaitSecs(3);
    
    %Mute the microphone of the participant
    state = 'true';
    command = "MUTE_PARTICIPANT/"+state;
    TCPSend(command)
    
    [~,~,keys] = KbCheck(-1);
    if any(keys(p.KEYS.SKIP.VALUE))
        %ends current trial
        d.trial_data(trial).flag = true;
        save(d.filepath_data, 'p', 'd')
        break;
    elseif any(keys(p.KEYS.ABORT.VALUE))
        d.number_trials = trial;
        error('Abort key pressed');
    end
    
    fprintf('End of answer period %d...\n', trial);
    %START OF FEEDBACK PHASE 
    %Get time of response start 
    t_resp_start = GetSecs;

    while 1
        [~,keys] = KbWait(-1);
        %display image response if in pre-recorded conditions
        if any(keys(p.KEYS.YES.VALUE)) && (d.trial_data(trial).correct_response ~= true) && (d.condition_number == 3 || d.condition_number == 4)
            t_resp = GetSecs;
            
            path = d.filepath_correct_image_response;
            command = "DISPLAY_PICTURE/"+path;
            TCPSend(command);
            
            WaitSecs(3 - (t_resp - t_resp_start));
            
            Eyelink('Message','Answer correct for trial %d', trial);
            
            %TRIGGER REACTION PRERECORDED
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',8,0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            WaitSecs(1);
            
            command = 'DISPLAY_CLEAR';
            TCPSend(command);
            
            path = 'Images/fixation.png';
            command = "DISPLAY_PICTURE/"+path;
            TCPSend(command);
                       
            d.trial_data(trial).correct_response = true;
            
            break;
            
        elseif any(keys(p.KEYS.NO.VALUE)) && (d.trial_data(trial).correct_response ~= false) && (d.condition_number == 3 || d.condition_number == 4)
            
            path = d.filepath_incorrect_image_response;
            command = "DISPLAY_PICTURE/"+path;
            TCPSend(command);
            
            Eyelink('Message','Answer incorrect for trial %d', trial);
            
            %TRIGGER REACTION PRERECORDED
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',8,0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            WaitSecs(1);
            
            command = 'DISPLAY_CLEAR';
            TCPSend(command);
                        
            path = 'Images/fixation.png';
            command = "DISPLAY_PICTURE/"+path;
            TCPSend(command);
            
            d.trial_data(trial).correct_response = false;
            
            break;
            
            %display live video feed for reaction response
        elseif any(keys(p.KEYS.YES.VALUE)) && (d.trial_data(trial).correct_response ~= true) && (d.condition_number == 1 || d.condition_number == 2)
            
            if d.condition_number == 1
                command = "DISPLAY_LIVE/Researcher";
                TCPSend(command);
            elseif d.condition_number == 2
                command = "DISPLAY_LIVE/Memoji";
                TCPSend(command);
            end
            
            Eyelink('Message','Answer correct for trial %d', trial);
            
            %TRIGGER REACTION PRERECORDED
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',8,0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = true;
            
            WaitSecs(1);
            
            command = 'DISPLAY_CLEAR';
            TCPSend(command);
            
            path = 'Images/fixation.png';
            command = "DISPLAY_PICTURE/"+path;
            TCPSend(command);
            
            break;
            
        elseif any(keys(p.KEYS.NO.VALUE)) && (d.trial_data(trial).correct_response ~= true) && (d.condition_number == 1 || d.condition_number == 2)
            
            if d.condition_number == 1
                command = "DISPLAY_LIVE/Researcher";
                TCPSend(command);
            elseif d.condition_number == 2
                command = "DISPLAY_LIVE/Memoji";
                TCPSend(command);
            end
            
            Eyelink('Message','Answer incorrect for trial %d', trial);
            
            %TRIGGER REACTION PRERECORDED
            if p.TRIGGER_STIM_TRACKER
                fwrite(sport,['mh',8,0]);
                d.trial_data(trial).timing.trigger.reaction(end+1) = GetSecs - t0;
                fwrite(sport,['mh',bin2dec('00000000'),0]);
            end
            
            d.trial_data(trial).correct_response = false;
            
            WaitSecs(1);
            
            command = 'DISPLAY_CLEAR';
            TCPSend(command);
            
            path = 'Images/fixation.png';
            command = "DISPLAY_PICTURE/"+path;
            TCPSend(command);
            
            break;
            %triggers the end of the current trial             
        elseif any(keys(p.KEYS.SKIP.VALUE)) %end of trial
            fprintf('End of trial %03d\n', trial)
            d.trial_data(trial).flag = true; 
            save(d.filepath_data, 'p', 'd')
            break;
        elseif any(keys(p.KEYS.ABORT.VALUE)) %error out of the run
            d.number_trials = trial;
            save(d.filepath_data, 'p', 'd')
            error('Abort key pressed');
        end
    end
    
    %Notify the researcher that the trial had ended
    command = "TRIAL_END";
    TCPSend(command);

    path = 'Images/fixation.png';
    command = "DISPLAY_PICTURE/"+path;
    TCPSend(command);
    
    %ITI
    WaitSecs(ITI);
    
    fprintf('Saving...\n');
    save(d.filepath_data, 'p', 'd')
    
end

%Notify the researcher that the experiment ended
command = "EXPERIMENT_END";
TCPSend(command);

%% Drift Check 
message = 'Fixate on the centre of the dot on the bottom middle of the screen';
command = "DISPLAY_MESSAGE/"+message;
TCPSend(command);

WaitSecs(3);

path = 'Images/drift_check.png';
command = "DISPLAY_PICTURE/"+path;
TCPSend(command);

Eyelink('Message',sprintf('Drift Check'));

WaitSecs(2);

message = '';
command = "DISPLAY_MESSAGE/"+message;
TCPSend(command);
%% Stop eyelink recording
fprintf('Eyelink Close');   

if p.USE_EYELINK 
    Eyelink.Collection.Close
else
    Eyelink('InitializeDummy');
end 
%% Final Baseline
message = 'We will now begin a 30 second baseline, please remain as still as possible';
command = "DISPLAY_MESSAGE/"+message;
TCPSend(command);

WaitSecs(3);

message = '';
command = "DISPLAY_MESSAGE/"+message;
TCPSend(command);

tbaseline = GetSecs; 
fprintf('Final baseline...\n');
tend = tbaseline + p.DURATION_BASELINE_FINAL;

%Trigger start of final baseline
if p.TRIGGER_STIM_TRACKER
    fwrite(sport,['mh',5,0]);
    WaitSecs(0.1);
    fwrite(sport,['mh',bin2dec('00000000'),0]);
end

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
    fwrite(sport, ['mh',5,0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
end

%% End
d.time_end_experiment = GetSecs;
d.timestamp_end_experiment = GetTimestamp;

%% Tell Participant It is the End
message = 'The run is now complete, thank you!';
command = "DISPLAY_MESSAGE/"+message;
TCPSend(command);

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
    
    command = 'DISPLAY_CLEAR';
    TCPSend(command);
    
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

function TCPSend(msg)
		%The IP address (192.168.0.151) here is just an example.  It needs to be swapped for
		%the IP of the computer used be the researcher.  
    tcpipClient = tcpip('129.100.118.96',7778,'NetworkRole','Client');
    set(tcpipClient,'Timeout',30);
    fopen(tcpipClient);
    fwrite(tcpipClient,msg);
    fclose(tcpipClient);
end
end 

