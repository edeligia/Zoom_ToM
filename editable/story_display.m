function story_display(participant_number, run_number)

cd('C:\Users\evade\Documents\GitHub\Zoom_ToM\editable\text_files');

%% Prepare Orders
fol_out = [pwd filesep 'Orders' filesep];

filepath = sprintf('%sPAR%02d_RUN%02d.xlsx', fol_out, participant_number, run_number);

[numbers_only_info,~,all_info_cell_matrix] = xlsread(filepath);

% order_headers = all_info_cell_matrix(1,:);
order_data = all_info_cell_matrix(2:end,:);

%% Parameters 

screen_number = max(Screen('Screens'));
screen_rect = [0 0 850 500];
screen_colour_background = [0 0 0];
% screen_colour_text = [255 255 255];
screen_font_size = 30;
Screen('Preference', 'SkipSyncTests', 1);
scrnRes     = Screen('Resolution',screen_number);               % Get Screen resolution
[x0 y0]		= RectCenter([0 0 scrnRes.width scrnRes.height]);   % Screen center.

%buttons
KEYS.START.NAME = 'SPACE'; % to advance to the next question prompt
KEYS.ESCAPE.NAME = 'ESCAPE'; 
KEYS.BACK.NAME = 'B';
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
try

Screen('TextSize', window, screen_font_size);

% DrawFormattedText(window, ' ', 'center', 'center', screen_colour_text);
Screen('Flip', window);

%% Trials
number_trials = size(order_data, 1);

for trial = 1:number_trials
    fprintf('\n----------------------------------------------\nWaiting for start key (%s) or escape key (%s) for trial %03d ...\n----------------------------------------------\n\n', KEYS.START.NAME, KEYS.ESCAPE.NAME, trial);
   
    while 1
        [~,keys] = KbWait(-1, 2);
        if any(keys(KEYS.START.VALUE))
            break;
        elseif any(keys(KEYS.ESCAPE.VALUE))
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
        Screen('DrawText',window, tline, x0-600, y0-500+lCounter*45,[255]);
        lCounter	= lCounter + 1;
    end
    
    fclose(textfid);
    Screen('Flip', window);
    
    
    
%     while 1
%         [~,keys] = KbWait(-1,3);
%         if any(keys(KEYS.START.VALUE))
%             break;
%         else any(keys(KEYS.ESCAPE.VALUE))
%             number_trials = trial;
%             error('Escape Key Pressed');
%         end
%     end
end

while 1
    [~,keys] = KbWait(-1, 2);
    if any(keys(KEYS.START.VALUE))
        break;
    elseif any(keys(KEYS.ESCAPE.VALUE))
        number_trials = trial;
        error('Escape Key Pressed');
    end
end
    

sca
sca

catch err
    sca
    sca
    rethrow(err)
end

