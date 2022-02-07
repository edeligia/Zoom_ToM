function EyelinkCalibrationTest(par_num)

%% Requires PTB
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
participant_number = par_num;
filename_edf = sprintf('PAR%02d', participant_number);

screen_number = max(Screen('Screens'));
screen_rect = [0 0 500 500];
screen_colour_background = [0 0 0];
screen_colour_text = [255 255 255];
screen_font_size = 30;

full_path_to_put_edf = [pwd filesep filename_edf];


%% Test

%create window for calibration
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