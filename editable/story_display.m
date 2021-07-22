function story_display(participant_number, run_number)
cd('C:\Users\evade\Documents\Zoom_project\Stims-Redcay+Rice\text_files');

%% Prepare Orders
fol_out = [pwd filesep 'Orders' filesep];

filepath = sprintf('%sPAR%02d_RUN%02d.xlsx', fol_out, participant_number, run_number);

[numbers_only_info,~,all_info_cell_matrix] = xlsread(filepath);

% order_headers = all_info_cell_matrix(1,:);
order_data = all_info_cell_matrix(2:end,:);

%% Parameters 

screen_number = max(Screen('Screens'));
screen_rect = [ ];
screen_colour_background = [0 0 0];
% screen_colour_text = [255 255 255];
screen_font_size = 30;
Screen('Preference', 'SkipSyncTests', 1);
scrnRes     = Screen('Resolution',screen_number);               % Get Screen resolution
[x0 y0]		= RectCenter([0 0 scrnRes.width scrnRes.height]);   % Screen center.

%buttons
KEYS.START.NAME = 'SPACE'; % to advance to the next question prompt
KEYS.ESCAPE.NAME = 'ESCAPE'; 

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
for key = fields(KEYS)'
    key = key{1};
    eval(sprintf('KEYS.%s.VALUE = KbName(KEYS.%s.NAME);', key, key))
end

window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);

Screen('TextSize', window, screen_font_size);

% DrawFormattedText(window, ' ', 'center', 'center', screen_colour_text);
Screen('Flip', window);

%% Trials
number_trials = size(order_data, 1);

for trial = number_trials
    fprintf('\n----------------------------------------------\nWaiting for start key (%s) or escape key (%s)...\n----------------------------------------------\n\n', KEYS.START.NAME, KEYS.ESCAPE.NAME);
   
    while 1
        [~,keys] = KbWait(-1);
        if any(keys(KEYS.START.VALUE))
            break;
        else any(keys(KEYS.ESCAPE.VALUE))
            number_trials = trial;
            error('Escape Key Pressed');
        end
    end
    

    %get trial number and story number
    question_number = numbers_only_info(trial, 2);
    question_name = sprintf('%d_question.txt', question_number);
    textfid			= fopen(question_name);
    lCounter		= 1;
    
    while 1
        tline		= fgetl(textfid);							% read line from text file.
        if ~ischar(tline), break, end
        Screen('DrawText',window, tline, x0-380,y0-160+lCounter*45,[255]);
        lCounter	= lCounter + 1;
    end
    
    fclose(textfid);
    Screen('Flip', window);
    
    while 1
        [~,keys] = KbWait(-1);
        if any(keys(KEYS.START.VALUE))
%             Screen('Close', window);
            break;
        else any(keys(KEYS.ESCAPE.VALUE))
            number_trials = trial;
            error('Escape Key Pressed');
        end
    end
 end

