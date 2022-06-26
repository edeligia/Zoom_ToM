function FB_localizer(participant_number, run_number)
%%Notes
%Participant presses T for true and F key for false 
%Can error out the script with ESC only during the answer period where it is looking
%for a key press 
%Participant responses are saved in a behavioural mat file that has 1 =
%true and 2 = false and 0 = no response

%% Path needs to be set each time script is run
%Need to be in FB_text_files folder where the script is located 
cd('C:\Users\CulhmanLab\Documents\GitHub\Zoom_ToM\editable\FB_localizer\FB_text_files');

%% Prepare Orders
fol_out = [pwd filesep 'Orders' filesep];

filepath = sprintf('%sPAR%02d_RUN%02d.xlsx', fol_out, participant_number, run_number);

[numbers_only_info,~,all_info_cell] = xlsread(filepath);

% order_headers = all_info_cell_matrix(1,:);
d.order_data = all_info_cell(2:end,:);
% add a column for behavioural data 

response_row = zeros(size(numbers_only_info,1),1);
d.behavioural_data = [numbers_only_info, response_row];
%% Set up necessary variables
textdir				= [pwd filesep 'FB_text_files' filesep];
behavdir			= [pwd filesep 'FB_behavioural' filesep];

%time script started
d.timestamp_start_script = GetTimestamp;

%put inputs in data struct
d.participant_number = participant_number;
d.run_number = run_number;

%Folder for participant specific data
filepath_participant_mat = sprintf('PAR%02d', participant_number);
p.DIR_DATA = [pwd filesep 'FB_behavioural' filesep filepath_participant_mat filesep];
d.filepath_data = sprintf('%sPAR%02d_RUN%02d_%s.mat', p.DIR_DATA, d.participant_number, d.run_number, d.timestamp_start_script);

%create output directories
if ~exist(p.DIR_DATA, 'dir'), mkdir(p.DIR_DATA); end

%% Debug 
p.TRIGGER_STIM_TRACKER = true;

if ~p.TRIGGER_STIM_TRACKER    
    warning('One or more debug settings is active!')
end
%% Parameters 
screen_number = 0;
screen_rect = [ ];
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;
Screen('Preference', 'SkipSyncTests', 1);
scrnRes     = Screen('Resolution',screen_number);               % Get Screen resolution
[x0 y0]		= RectCenter([0 0 scrnRes.width scrnRes.height]);   % Screen center.
d.story_disp = 10;
d.quest_disp = 4;
ITI = 7;

%buttons
p.KEYS.START.NAME = 'RETURN';
p.KEYS.EXIT.NAME = 'ESCAPE';
p.KEYS.TRUE.NAME = 'T';
p.KEYS.FALSE.NAME = 'F';

%stim tracker
%the left port on Eva's laptop is COM3 and on the culham lab msi laptop 
p.TRIGGER_CABLE_COM_STRING = 'COM6';

%timings
p.DURATION_BASELINE = 20;
p.DURATION_BASELINE_FINAL = 20;
%%  Check Requirements
%psychtoolbox
try
    AssertOpenGL();
catch err
    warning('PsychToolbox might not be installed or setup correctly!')
    rethrow(err)
end

%set key values
KbName('UnifyKeyNames');
for key = fields(p.KEYS)'
    key = key{1};
    eval(sprintf('p.KEYS.%s.VALUE = KbName(p.KEYS.%s.NAME);', key, key))
end

window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
try

Screen('TextSize', window, screen_font_size);

% DrawFormattedText(window, ' ', 'center', 'center', screen_colour_text);
Screen('Flip', window);

%% Wait for Run Start

DrawFormattedText(window, 'Press ENTER to start run', 'center', 'center', screen_colour_text);
Screen('Flip', window);     

while 1
    [~,keys] = KbWait(-1, 3);
    if any(keys(p.KEYS.START.VALUE))
        break;
    elseif any(keys(p.KEYS.ESCAPE.VALUE))
        error('Escape Key Pressed');
    end
end

%Time of Run start
t0 = GetSecs;
d.time_start_experiment = t0;
d.timestamp_start_experiment = GetTimestamp;

d.number_trials = size(d.order_data, 1);
%% Participant Instructions 
DrawFormattedText(window, 'Press T for TRUE and F for FALSE.', 'center', 'center', screen_colour_text);
Screen('Flip', window); 

WaitSecs(3);

Screen('Flip', window);

%% open serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
    sport=serial(p.TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
    fopen(sport);
else
    sport = nan;
end

%% Initial Baseline 

DrawFormattedText(window, 'We will now have a 30 second baseline. Please remain still.', 'center', 'center', screen_colour_text);
Screen('Flip', window);  

WaitSecs(3);

Screen('Flip', window);

if p.TRIGGER_STIM_TRACKER
    fwrite(sport, ['mh',1,0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh',0,0]); 
end

tbaseline = GetSecs;
fprintf('Initial baseline...\n');
tend = tbaseline + p.DURATION_BASELINE;

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
    fwrite(sport, ['mh',1,0]); %turn off 2 
    WaitSecs(0.1);
    fwrite(sport, ['mh', bin2dec('00000000'), 0]);
end   

fprintf('Baseline complete...\n'); 

%% Enter trial phase
for trial = 1:d.number_trials
    d.trial_data(trial).timing.onset = GetSecs - t0;
    d.latest_trial = trial;

%% Display Story 
    %get trial number and story number
    %1 = FB and 2 = photo
    story_number = numbers_only_info(trial, 2);
    condition_number = numbers_only_info(trial, 3);
    story_name = sprintf('%d_%d_story.txt', story_number, condition_number);

    textfid			= fopen(story_name);
    lCounter		= 1;
    
    while 1
        tline		= fgetl(textfid);							% read line from text file.
        if ~ischar(tline), break, end
        Screen('DrawText',window, tline, x0-300, y0-200+lCounter*45,[255]);
        lCounter	= lCounter + 1;
    end
    
    fclose(textfid);
    Screen('Flip', window);
    
    if p.TRIGGER_STIM_TRACKER
        fwrite(sport,['mh',2,0]); %turn story period trigger on (for StimTracker)
        d.trial_data(trial).timing.trigger.story_period_start = GetSecs - t0;
        fwrite(sport,['mh',bin2dec('00000000'),0]); %turn story period trigger off (for StimTracker)
    end
    
    WaitSecs(d.story_disp);
    
    if p.TRIGGER_STIM_TRACKER
        fwrite(sport,['mh',2,0]); %turn story period trigger on (for StimTracker)
        d.trial_data(trial).timing.trigger.story_period_end = GetSecs - t0;
        fwrite(sport,['mh',bin2dec('00000000'),0]); %turn story period trigger off (for StimTracker)
    end
%% Display Question
%get trial number and story number
    %1 = FB and 2 = photo
    question_number = numbers_only_info(trial, 2);
    condition_number = numbers_only_info(trial, 3);
    question_name = sprintf('%d_%d_question.txt', question_number, condition_number);
    textfid			= fopen(question_name);
    lCounter		= 1;
    
    while 1
        tline		= fgetl(textfid);							% read line from text file.
        if ~ischar(tline), break, end
        Screen('DrawText',window, tline, x0-300, y0-200+lCounter*45,[255]);
        lCounter	= lCounter + 1;
    end
    
    fclose(textfid);
    Screen('Flip', window);
    
     if p.TRIGGER_STIM_TRACKER
        fwrite(sport,['mh',3,0]); %turn story period trigger on (for StimTracker)
        d.trial_data(trial).timing.trigger.question_period_start = GetSecs - t0;
        fwrite(sport,['mh',bin2dec('00000000'),0]); %turn story period trigger off (for StimTracker)
     end
    
    question_display_start = GetSecs;
    
    %record behavioural data 1 = true and 2 = false and 0 = no response
    while (GetSecs - question_display_start) < d.quest_disp
        [~,~,keys] = KbCheck;
        if any(keys(p.KEYS.TRUE.VALUE))
          d.behavioural_data(trial, 4) = 1;
        elseif any(keys(p.KEYS.FALSE.VALUE))
          d.behavioural_data(trial, 4) = 2;
        elseif any(keys(p.KEYS.EXIT.VALUE))
          error('Exit key pressed');
        end
    end
    Screen('Flip', window);
    
    if p.TRIGGER_STIM_TRACKER
        fwrite(sport,['mh',3,0]); %turn story period trigger on (for StimTracker)
        d.trial_data(trial).timing.trigger.story_period_start = GetSecs - t0;
        fwrite(sport,['mh',bin2dec('00000000'),0]); %turn story period trigger off (for StimTracker)
    end
    
    % ITI
    WaitSecs(ITI);
end
%% Final Baseline
fprintf('Final baseline...\n');

DrawFormattedText(window, 'We will now have a 30 second baseline. Please remain still.', 'center', 'center', screen_colour_text);
Screen('Flip', window);

WaitSecs(3);

Screen('Flip', window);

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
    fwrite(sport, ['mh',1,0]);
    WaitSecs(0.1);
    fwrite(sport, ['mh',0,0]); 
end

%% close serial port for stim tracker
if p.TRIGGER_STIM_TRACKER
    try
        fclose(sport);
    catch
        warning('Could not close serial connection')
    end
end

%% End
sca
sca

d.time_end_experiment = GetSecs;
d.timestamp_end_experiment = GetTimestamp;
%% Done
save(d.filepath_data, 'p', 'd')
disp Complete! 

catch err
    sca
    sca
    
    %save everything
    save(['ErrorDump_' d.timestamp_start_script])
    
    %show cursor
    ShowCursor;
    
    rethrow(err)
end

%% Functions
    function [timestamp, timestamp_edf] = GetTimestamp
        c = round(clock);
        timestamp = sprintf('%d-%d-%d_%d-%d_%d',c([4 5 6 3 2 1]));
        timestamp_edf = sprintf('%02d%02d', c(5:6));
    end

end