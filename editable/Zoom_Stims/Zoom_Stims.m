function zoom_mov(subjID)

%% Most basic attempt to play movie files in Matlab via Psychtoolbox
% Errors using Screen so have added 'SkipSyncTests' for now, but need to
% look into the timing 

Screen('Preference', 'SkipSyncTests', 1);

%% Variables unique to computer

[rootdir b c]		= fileparts(mfilename('fullpath'));			% path to the directory containing the behavioural / stimuli directories. If this script is not in that directory, this line must be changed 
triggerKey			= '+';										

%% param
% TRIGGER_CABLE_COM_STRING = 'COM3';

%% open serial port for stim tracker
% sport=serial(TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
% fopen(sport);


%% Set up variables 
orig_dir			= pwd;
stimdir             = fullfile(rootdir, 'stimuli');
behavdir			= fullfile(rootdir, 'behavioural');
moviefName          = fullfile(stimdir, 'Stims_Owl1.mov');
movieDur = 15;

try
	PsychJavaTrouble;
	HideCursor;
    Screen('Preference', 'SkipSyncTests', 1);
	displays    = Screen('screens');
	[w, wRect]  = Screen('OpenWindow',displays(end),0);
	scrnRes     = Screen('Resolution',displays(end));               % Get Screen resolution
	[x0 y0]		= RectCenter([0 0 scrnRes.width scrnRes.height]);   % Screen center                       
	Screen(w, 'TextFont', 'Helvetica');                         
	Screen(w, 'TextSize', 32);
    instructions = 'Please wait while the movie loads';   
    DrawFormattedText(w, instructions, 'center' , 'center', 255,70); 
	Screen(w, 'Flip');												% Instructional screen is presented.
catch exception
	ShowCursor;
	sca;
	warndlg(sprintf('PsychToolBox has encountered the following error: %s',exception.message),'Error');
	return
end


%% Verify that all necessary files and folders are in place. 
if isempty(dir(stimdir))
	uiwait(warndlg(sprintf('Your stimuli directory is missing! Please create directory %s and populate it with stimuli. When Directory is created, hit ''Okay''',stimdir),'Missing Directory','modal'));
end
if ~exist(moviefName)
    error('Your stimuli is missing. please copy the movie file to the stimuli folder and try again.');
end
if isempty(dir(behavdir))
	outcome = questdlg(sprintf('Your behavioral directory is missing! Please create directory %s.',behavdir),'Missing Directory','Okay','Do it for me','Do it for me');
	if strcmpi(outcome,'Do it for me')
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


% Now want to open a new window to play the movie in

[movie] = Screen('OpenMovie', w, moviefName);
rate = 1;

% Give the display a moment to recover from change of display mode when
% opening a new window. 

WaitSecs(2);
% fwrite(sport,['mh',1,0]); %send trigger to Stim Tracker
% WaitSecs(1); %PTB command, could use built-in, doesn't have to be 1sec, a few msec is fine
% fwrite(sport,['mh',0,0]); %turn trigger off (for StimTracker)

%% wait for trigger to begin 
while 1  
    FlushEvents;
    trig = GetChar;
    if trig == '+'
        break
    end
end
Screen(w, 'Flip');


%% Main Experiment
experimentStart = GetSecs;

%% present movie
  
Screen('PlayMovie', movie, rate, 0, 1.0);
trialStart = GetSecs;
timing_adjustment = trialStart - experimentStart;

while(GetSecs - trialStart < movieDur -.2)
    % Wait for next movie frame, retrieve texture handle to it
    tex = Screen('GetMovieImage', w, movie);
    % Valid texture returned? A negative value means end of movie reached:
    if tex<=0
        % done, break
        break;
    end;
    % Draw the new texture immediately to screen:
    Screen('DrawTexture', w, tex);
    % Update display:
    Screen(w, 'Flip');
    % Release texture:
    Screen('Close', tex);
end
Screen('CloseMovie', movie);
Screen(w, 'Flip');


experimentEnd		= GetSecs;
experimentDuration	= experimentEnd - experimentStart;

%close connection
% fclose(sport);

try
	sca
    cd(behavdir);
	save('subjID','timing_adjustment','experimentDuration');
	ShowCursor;
	cd(orig_dir);
catch exception
	sca
	ShowCursor;
	warndlg(sprintf('The experiment has encountered the following error while saving the behavioral data: %s',exception.message),'Error');
	cd(orig_dir);
end

end %main function






