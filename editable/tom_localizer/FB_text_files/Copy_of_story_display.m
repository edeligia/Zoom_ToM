function story_display(participant_number, run_number)

cd('C:\Users\evade\Documents\GitHub\Zoom_ToM\editable\tom_localizer\FB_text_files');

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
%% Parameters 
screen_number = max(Screen('Screens'));
screen_rect = [ ];
screen_colour_background = [0 0 0];
% screen_colour_text = [255 255 255];
screen_font_size = 30;
Screen('Preference', 'SkipSyncTests', 1);
scrnRes     = Screen('Resolution',screen_number);               % Get Screen resolution
[x0 y0]		= RectCenter([0 0 scrnRes.width scrnRes.height]);   % Screen center.
d.story_disp = 10;
d.quest_disp = 4;
ITI = 12;

%buttons
p.KEYS.START.NAME = 'RETURN';
p.KEYS.EXIT.NAME = 'ESCAPE';
p.KEYS.TRUE.NAME = 'T';
p.KEYS.FALSE.NAME = 'F';
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
        Screen('DrawText',window, tline, x0-600, y0-500+lCounter*45,[255]);
        lCounter	= lCounter + 1;
    end
    
    fclose(textfid);
    Screen('Flip', window);
    
    WaitSecs(d.story_disp);
    
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
        Screen('DrawText',window, tline, x0-600, y0-500+lCounter*45,[255]);
        lCounter	= lCounter + 1;
    end
    
    fclose(textfid);
    Screen('Flip', window);
    d.trial_data(trial).timing.question = GetSecs - t0;
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
    
    % ITI
    WaitSecs(ITI);
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