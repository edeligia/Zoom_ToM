function mov_localizer_rc(subjID)

%% Version: March 28, 2019
%__________________________________________________________________________
%
% This script will localize theory-of-mind network areas and pain matrix
% areas by contrasting activation during mental and pain events, as identified via
% reverse correlation analyses in two samples of adults (see Richardson et al., 2018).
%
% To run this script, you need Matlab and the PsychToolbox, which is available
% as a free download. Make sure to follow the GStreamer instructions if prompted 
% in order to make movie screening from PsychToolbox work.
%
% In addition, you will need to purchase the movie "Partly Cloudy" from
% Pixar Animation Studios. 
%__________________________________________________________________________
%
%							INPUTS
%
% - subjID: STRING The string you wish to use to identify the participant. 
%			"PI name"_"study name"_"participant number" is a common
%			convention. This will be the name used to save the files.
%
% Example usage: 
%					mov_localizer('SAX_MOV_01')
%
%__________________________________________________________________________
%
%							OUTPUTS
%	The script outputs a behavioural file into the behavioural directory.
%	This contains information about the IPS of the scan, and the coded 
%   timing of events in the movie. It also contains information necessary 
%   to perform the analysis with SPM. The file is saved as 
%   subjectID.mov.1.m
%
%__________________________________________________________________________
%
%						  CONDITIONS 
%
%				1 - mental - events that reliably evoke activity in ToM
%				regions
%				2 - pain - events that reliably evoke activity in the Pain
%				Matrix
%
%__________________________________________________________________________
%
%							TIMING
%
%   time = 5:59 - including fixation before movie and credits
%   IPS = 180 - can be made shorter if you stop scan during credits
%__________________________________________________________________________
%
%							NOTES
%
%	Note 1
%		Make sure to change the inputs in the 'Variables unique to scanner/
%		computer' section of the script. 
%
%__________________________________________________________________________
%
%					ADVICE FOR ANALYSIS
%	We analyze this experiment by modelling coded events as a trial block 
%   with a boxcar lasting the event duration.
%
%	Analysis consists of five primary steps:
%		1. Motion correction by rigid rotation and translation about the 6 
%		   orthogonal axes of motion.
%		2. (optional) Normalization to the SPM template. 
%		3. Smoothing, FWHM, 5 mm smoothing kernel if normalization has been
%		   performed, 8 mm otherwise.
%		4. Modeling
%				- Each condition in each run gets a parameter, a boxcar
%				  plot convolved with the standard HRF.
%				- The data is high pass filtered (filter frequency is 128
%				  seconds per cycle)
%		5. A simple contrast and a map of t-test t values is produced for 
%		   analysis in each subject. We look for activations thresholded at
%		   p < 0.001 (voxelwise) with a minimum extent threshold of 5
%		   contiguous voxels. 
%
%	Random effects analyses show significant results with n > 10
%	participants, though it should be evident that the experiment is
%	working after 3 - 5 individuals.
%__________________________________________________________________________
%
%					SPM Parameters
%
%	If using scripts to automate data analysis, these parameters are set in
%	the SPM.mat file prior to modeling or design matrix configuration. 
%
%	SPM.xGX.iGXcalc    = {'Scaling'}		global normalization: OPTIONS:'Scaling'|'None'
%	SPM.xX.K.HParam    = filter_frequency   high-pass filter cutoff (secs) [Inf = no filtering]
%	SPM.xVi.form       = 'none'             intrinsic autocorrelations: OPTIONS: 'none'|'AR(1) + w'
%	SPM.xBF.name       = 'hrf'				Basis function name 
%   SPM.xBF.T0         = 8                 	reference time bin - samples to the middle of TR 
%	SPM.xBF.UNITS      = 'scans'			OPTIONS: 'scans'|'secs' for onsets
%	SPM.xBF.Volterra   = 1					OPTIONS: 1|2 = order of convolution; 1 = no Volterra
%__________________________________________________________________________
%
%	Created by Jorie Koster-Hale and Nir Jacoby; edited by Hilary
%	Richardson
%__________________________________________________________________________
%
%					Changelog
% 
%__________________________________________________________________________
%
%% Variables unique to scanner / computer

[rootdir b c]		= fileparts(mfilename('fullpath'));			% path to the directory containing the behavioural / stimuli directories. If this script is not in that directory, this line must be changed 
triggerKey			= '+';										% this is the value of the key the scanner sends to the presentation computer


%% param
TRIGGER_CABLE_COM_STRING = 'COM43';

%% open serial port for stim tracker
% sport=serial(TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
% fopen(sport);

%% Set up necessary variables
orig_dir			= pwd;
stimdir             = fullfile(rootdir, 'stimuli');
behavdir			= fullfile(rootdir, 'behavioural');
moviefName          = fullfile(stimdir, 'partly_cloudy.mp4');

p.DURATION_BASELINE = 5;  %fixation time before movie. we stopped scanning in the middle of credits, so no post movie fixation
movieDur = 349;

%% check if it was run before shuffle order of stories
bfname = [subjID '.movloc.1.mat'];
if exist(fullfile(behavdir,bfname),'file')
    rerunflag = questdlg('Behavioural file already exist, do you want to re-run the current subject/run? Old behavioural file will be overwritten','Run again?','Yes','No','No');
    if ~strcmp(rerunflag,'Yes')
        error('Repeated subject/run command aborted');
    end
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


%% Psychtoolbox
%  Here, all necessary PsychToolBox functions are initiated and the
%  instruction screens are set up.
try
	PsychJavaTrouble;
	HideCursor;
    Screen('Preference', 'SkipSyncTests', 1);
	displays    = Screen('screens');
	[w, wRect]  = Screen('OpenWindow',displays(end),0);
	scrnRes     = Screen('Resolution',displays(end));               % Get Screen resolution
	[x0 y0]		= RectCenter([0 0 scrnRes.width scrnRes.height]);   % Screen center.
	Screen(   'Preference', 'SkipSyncTests', 0);                       
	Screen(w, 'TextFont', 'Helvetica');                         
	Screen(w, 'TextSize', 32);
    instructions = 'Please wait while the movie loads';   
    DrawFormattedText(w, instructions, 'center' , 'center', 255,70);  % original instructions was "Get Ready!" size 40
	Screen(w, 'Flip');												% Instructional screen is presented.
catch exception
	ShowCursor;
	sca;
	warndlg(sprintf('PsychToolBox has encountered the following error: %s',exception.message),'Error');
	return
end

p.KEYS.ABORT.NAME = 'P';

%set key values
KbName('UnifyKeyNames');
for key = fields(p.KEYS)'
    key = key{1};
    eval(sprintf('p.KEYS.%s.VALUE = KbName(p.KEYS.%s.NAME);', key, key))
end
%% Open movie file
movie = Screen('OpenMovie', w, moviefName);
rate = 1;

%% wait for the 1st trigger pulse
while 1  
    FlushEvents;
    trig = GetChar;
    if trig == '+'
        break
    end
end
Screen(w, 'Flip');

%% Initial Baseline 

% if p.TRIGGER_STIM_TRACKER
%     fwrite(sport, ['mh',bin2dec('00000001'),0]);
%     WaitSecs(0.1);
%     fwrite(sport, ['mh', bin2dec('00000000'), 0]); 
% end

p.experimentStart = GetSecs;

fprintf('Initial baseline...\n');

tend = p.experimentStart + p.DURATION_BASELINE;
while 1
    ti = GetSecs;
    if ti > tend
        break;
    end
end

%% present movie
  
Screen('PlayMovie', movie, rate, 0, 1.0);

% fwrite(sport,['mh',1,0]); %send trigger to Stim Tracker
% WaitSecs(0.1); %PTB command, could use built-in, doesn't have to be 1sec, a few msec is fine
%fwrite(sport,['mh',0,0]); %turn trigger off (for StimTracker)

p.trialStart = GetSecs;
p.timing_adjustment = p.trialStart - p.experimentStart;

while(GetSecs - p.trialStart < movieDur -.2)
    % Wait for next movie frame, retrieve texture handle to it
    tex = Screen('GetMovieImage', w, movie);
    % Valid texture returned? A negative value means end of movie reached:
    if tex<=0
        % done, break
        break;
    end;
    
      [~,~,keys] = KbCheck(-1);
      if any(keys(p.KEYS.ABORT.VALUE))
            error('Abort key pressed');
      end
    % Draw the new texture immediately to screen:
    Screen('DrawTexture', w, tex);
    % Update display:
    Screen(w, 'Flip');
    % Release texture:
    Screen('Close', tex);
end
Screen('CloseMovie', movie);
Screen(w, 'Flip');


p.experimentEnd = GetSecs;
p.experimentDuration = p.experimentEnd - p.experimentStart;

%close connection
%fclose(sport);

save(behavdir, 'p');

%% Analysis Info

% Event coding based on reverse correlation analyses, replicated across
% two samples of adults (Richardson et al., 2018), and subsequently
% accounting for hemodynamic lag. 
% All timings in seconds and assume 10 sec fixation before movie
conds(1).names = 'mental';
conds(2).names = 'pain';
conds(1).onsets = [86, 98, 120, 176, 238, 252, 300]; % mental
conds(2).onsets = [70, 92, 106, 136, 194, 210, 228, 262, 312]; % pain
conds(1).durs = [4, 6, 4, 16, 6, 8, 6]; % mental
conds(2).durs = [4, 2, 4, 10, 4, 12, 6, 6, 4]; % pain

try
	sca
    cd(behavdir);
	save(bfname,'subjID','timing_adjustment','experimentDuration','ips','conds');
	ShowCursor;
	cd(orig_dir);
catch exception
	sca
	ShowCursor;
	warndlg(sprintf('The experiment has encountered the following error while saving the behavioral data: %s',exception.message),'Error');
	cd(orig_dir);
end

end %main function
