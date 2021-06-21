 
%%  Requires PTB
try
    AssertOpenGL();
catch err
    warning('PsychToolbox might not be installed or setup correctly!')
    rethrow(err)
end

%% Requires SR Research Eyelink SDK to be installed
try
    Eyelink;
catch
    error('Eyelink requires the SDK from SR Research (http://download.sr-support.com/displaysoftwarerelease/EyeLinkDevKit_Windows_1.11.5.zip)')
end

%% Requires directory added to path
if isempty(which('Eyelink.Collection.Connect'))
    error('The "AddToPath" directory must be added to the MATLAB path. Run "setup.m" or add manually.');
end

%% Parameters
%% screen_rect [ 0 0 width length]
screen_number = max(Screen('Screens'));
screen_rect = [];
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;

filename_edf = 'testfile.edf';
full_path_to_put_edf = [pwd filesep filename_edf];

number_demo_trial = 3;

%stim tracker
p.TRIGGER_CABLE_COM_STRING = 'COM4';

%% Test
%create window for calibration

Screen('Preference','SkipSyncTests', 1);

try
  window = Screen('OpenWindow', screen_number, screen_colour_background, screen_rect);
  Screen('TextSize', window, screen_font_size);
  HideCursor;
catch err
  warning('An error occured while opening the Screen(not related to Eyelink)');
  rethrow(err);
end

%try in case of error
try

%init
DrawFormattedText(window, 'Eyelink Connect', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Connect
    
%set window used
DrawFormattedText(window, 'Eyelink Set Window', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.SetupScreen(window)

%set file to write to
DrawFormattedText(window, 'Eyelink Set EDF', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.SetEDF(filename_edf)

%calibrate
DrawFormattedText(window, 'Eyelink Calibration', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Calibration

%% open serial port for stim tracker

if p.TRIGGER_STIM_TRACKER
    %sport=serial('/dev/tty.usbserial-00001014','BaudRate',115200);
    sport=serial(p.TRIGGER_CABLE_COM_STRING,'BaudRate',115200);
    fopen(sport);
else
    sport = nan;
end

%% trigger stim tracker (start of exp)
if p.TRIGGER_STIM_TRACKER
    fwrite(sport,['mh',1,0]); %send trigger to Stim Tracker
    WaitSecs(1);
    fwrite(sport,['mh',0,0]); %turn trigger off (for StimTracker)
end

%collect
for trial = 1:number_demo_trial
    fprintf('Demo trial %d of %d...\n', trial, number_demo_trial);
    
    DrawFormattedText(window, sprintf('Demo Trial %d of %d', trial, number_demo_trial), 'center', 'center', screen_colour_text);
    Screen('Flip', window);
    
    Eyelink('StartRecording');
    Eyelink('Message',sprintf('Event: Start of trial %03d\n', trial));
    WaitSecs(1);
    Eyelink('Message','Event: ~1 second into trial\n');
    WaitSecs(1);
    Eyelink('Message','Event: End of trial %03d\n', trial);
    Eyelink('StopRecording');
    
    if trial < number_demo_trial
        DrawFormattedText(window, 'Inter-Trial Time', 'center', 'center', screen_colour_text);
        Screen('Flip', window);
        WaitSecs(1);
    end
end

%% trigger stim tracker (end of exp)
if p.TRIGGER_STIM_TRACKER
    fwrite(sport,['mh',1,0]); %send trigger to Stim Tracker
    WaitSecs(1);
    fwrite(sport,['mh',0,0]); %turn trigger off (for StimTracker)
end

%close
DrawFormattedText(window, 'Eyelink Close', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Close

%get edf
DrawFormattedText(window, 'Eyelink Pull EDF', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.PullEDF(filename_edf, full_path_to_put_edf)

%shutdown
DrawFormattedText(window, 'Eyelink Shutdown', 'center', 'center', screen_colour_text);
Screen('Flip', window);
Eyelink.Collection.Shutdown

%done
Screen('Close', window);
ShowCursor;
disp('Demo complete!');

%catch if error
catch err
    %close screen if open
    Screen('Close', window);
    
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
            Eyelink.Collection.PullEDF(filename_edf, full_path_to_put_edf)
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