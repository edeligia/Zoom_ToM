function tom_localizer_MK_oct(subjID, run)
%Work around to turn off sync 
Screen('Preference','SkipSyncTests', 1);

%% Variables unique to scanner / computer

[rootdir b c]		= fileparts(mfilename('fullpath'));			% path to the directory containing the behavioural / stimuli directories. If this script is not in that directory, this line must be changed. 
triggerKey			= '+';										% this is the value of the key the scanner sends to the presentation computer

%% Set up necessary variables
orig_dir			= pwd;
textdir				= fullfile(rootdir, 'text_files');
behavdir			= fullfile(rootdir, 'behavdir');
designs				= [ 1 2 2 1 2 1 2 1 1 2 ;
					    2 1 2 1 1 2 2 1 2 1 ; ];
design				= designs(run,:);
conds				= {'belief','photo'};
condPrefs			= {'b','p'};								% stimuli textfile prefixes, used in loading stimuli content
fixDur				= 12;										% fixation duration
storyDur			= 10;										% story duration
questDur			=  4;										% probe duration
trialsPerRun		=  length(design);
key					= zeros(trialsPerRun,1);
%RT					= key;
items				= key;
trialsOnsets        = key;                                      % trial onsets in seconds
ips					= ((trialsPerRun) * (fixDur + storyDur + questDur) + (fixDur))/2;

KEYS.TRUE.NAME = 'T'; 
KEYS.FALSE.NAME = 'F';
%% Verify that all necessary files and folders are in place. 
if isempty(dir(textdir))
	uiwait(warndlg(sprintf('Your stimuli directory is missing! Please create directory %s and populate it with stimuli. When Directory is created, hit ''Okay''',textdir),'Missing Directory','modal'));
end
	outcome = questdlg(sprintf('Your behavioral directory is missing! Please create directory %s.',behavdir),'Missing Directory','Okay','Do it for me','Do it for me');
	if strcmpi(outcome,'Do it for me')

if isempty(dir(behavdir))
		mkdir(behavdir);
		if isempty(dir(behavdir))
			warndlg(sprintf('Couldn''t create directory %s!',behavdir),'Missing Directory');
			return
		end
	else
		if isempty(dir(behavdir))
			return
		end
	end
end

%% Psychtoolbox
%  Here, all necessary PsychToolBox functions are initiated and the
%  instruction screens are set up.
try
	PsychJavaTrouble;
	cd(textdir);
	HideCursor;
	displays    = Screen('screens');
	[w, ~]  = Screen('OpenWindow',displays(1),0);
	scrnRes     = Screen('Resolution',displays(1));               % Get Screen resolution
	[x0, y0]		= RectCenter([0 0 scrnRes.width scrnRes.height]);   % Screen center.
	Screen(   'Preference', 'SkipSyncTests', 0);                       
	Screen(w, 'TextFont', 'Helvetica');                         
	Screen(w, 'TextSize', 30);
	task		= sprintf('True or False');
	instr_1		= sprintf('Press T for "True"');
	instr_2		= sprintf('Press F for "False"');
	Screen(w, 'DrawText', task, x0-125, y0-60, [255]);
	Screen(w, 'DrawText', instr_1, x0-300, y0, [255]);
	Screen(w, 'DrawText', instr_2, x0-300, y0+60, [255]);
	Screen(w, 'Flip');													% Instructional screen is presented.
catch exception
	ShowCursor;
	sca;
	warndlg(sprintf('PsychToolBox has encountered the following error: %s',exception.message),'Error');
	return
end

%set key values
KbName('UnifyKeyNames');
for key = fields(KEYS)'
    key = key{1};
    eval(sprintf('KEYS.%s.VALUE = KbName(KEYS.%s.NAME);', key, key))
end


%% open serial port for stim tracker
% if p.TRIGGER_STIM_TRACKER
%     %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
%     sport=serial(p.TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
%     fopen(sport);
% else
%     sport = nan;
% end


%% Wait for the trigger (start in our case)
%  If your scanner does not use a '+' as a trigger pulse, change the value 
%  of triggerKey accordingly. 

while 1  
    FlushEvents;
    trig = GetChar;
    if strcmp(trig, triggerKey);
        break
    end
end

%% Main Experimental Loop
counter				= zeros(1,2)+(5*(run-1));
experimentStart		= GetSecs;
Screen(w, 'TextSize', 24);
try
    for trial = 1:trialsPerRun
        cd(textdir);
        trialStart		= GetSecs;
        %         if p.TRIGGER_STIM_TRACKER
        %             fwrite(sport, ['mh',bin2dec('00000001'),0]);
        %             WaitSecs(0.1);
        %             fwrite(sport, ['mh', bin2dec('00000000'), 0]);
        %         end
        empty_text		= ' ';
        Screen(w, 'DrawText', empty_text,x0,y0);
        Screen(w, 'Flip');
        counter(1,design(trial)) = counter(1,design(trial)) + 1;
        
        %%%%%%%%% Determine stimuli filenames %%%%%%%%%
        trialT			= design(trial);							% trial type. 1 = false belief, 2 = false photograph
        numbeT			= counter(1,trialT);						% the number of the stimuli
        storyname		= sprintf('%d%s_story.txt',numbeT,condPrefs{trialT});
        questname		= sprintf('%d%s_question.txt',numbeT,condPrefs{trialT});
        items(trial,1)	= numbeT;
        
        %%%%%%%%% Open Story %%%%%%%%%
        textfid			= fopen(storyname);
        lCounter		= 1;										% line counter
        while 1
            tline		= fgetl(textfid);							% read line from text file.
            if ~ischar(tline), break, end
            Screen(w, 'DrawText',tline,x0-380,y0-160+lCounter*45,[255]);
            lCounter	= lCounter + 1;
        end
        fclose(textfid);
        
        WaitSecs(2);				% wait for fixation period to elapse
        
        %%%%%%%%% Display Story %%%%%%%%%
        Screen(w, 'Flip');
        trialsOnsets (trial) = GetSecs-experimentStart;
        %%%%%%%%% Open Question %%%%%%%%%
        textfid			= fopen(questname);
        lCounter		= 1;
        while 1
            tline		= fgetl(textfid);							% read line from text file.
            if ~ischar(tline), break, end
            Screen(w, 'DrawText',tline,x0-380,y0-160+lCounter*45,[255]);
            lCounter	= lCounter + 1;
        end
        WaitSecs(10);		% wait for story presentation period
        
        %%%%%%%%% Display Question %%%%%%%%%
        Screen(w, 'Flip');
        
        responseStart	= GetSecs;
        
        %%%%%%%%% Collect Response %%%%%%%%%
        while 1
            WaitSecs(2);
            KbCheck;    % check to see if a key is being pressed
            break;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %--------------------------SEE NOTE 2-----------------------------%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % 			button						= intersect([89:92], find(keyCode));
        % 			if(RT(trial,1) == 0) & ~isempty(button)
        % 				RT(trial,1)				= GetSecs - responseStart;
        % 				key(trial,1)			= str2num(KbName(button));
        % % 			end
        %             button = find(keyCode);
        %             if(RT(trial,1) == 0) & ~isempty(button)
        %                 RT(trial,1) = GetSecs - responseStart;
        %                 key(trial,1) = str2num(KbName(button));
        %             end
        % 		end

    end
catch exception
	ShowCursor;
	sca
	warndlg(sprintf('The experiment has encountered the following error during the main experimental loop: %s',exception.message),'Error');
	return
end


%% Final fixation, save information
Screen(w, 'Flip');
trials_end			= GetSecs;
while 1
    WaitSecs(2);
    break;
end

experimentEnd		= GetSecs;
experimentDuration	= experimentEnd - experimentStart;
numconds			= 2;

        
        cd(behavdir);
        %%%%%%%%% Save information in the event of a crash %%%%%%%%%
        save(sprintf('tom_localizer_MK_oct_subject%02d_run%02d.mat',subjID, run));
end
% try
% 	sca
% 	%responses = sortrows([design' items key RT]);
% 	save([subjID '.tom_localizer.' num2str(run) '.mat'],'subjID','run','design','trialsOnsets','experimentDuration','ips');
% 	ShowCursor;
% 	cd(orig_dir);
% catch exception
% 	sca
% 	ShowCursor;
% 	warndlg(sprintf('The experiment has encountered the following error while saving the behavioral data: %s',exception.message),'Error');
% 	cd(orig_dir);
% end
% end main function