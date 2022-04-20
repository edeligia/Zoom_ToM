function HomerPrep
% converts Nirstar participant files output into .nirs format
% need to be in paricipant specific folder (or folder that contains all the
% participant runs)
% par_id is the name of the run files without the run number specified 

%% Setup Inputs
% this will break for more than 10 runs sorry
num_runs = 4;
%filepath for folder with all the runs 
input_directory = ('C:\Users\evade\Documents\Zoom_project\Data\Piloting_2022\HV');
%need to have manually created folders in your output folder that have the
%same name as each run folder in the raw data 
output_directory = ('C:\Users\evade\Documents\Zoom_project\Data\Piloting_2022\HV\2022-03-29-HOMER');
% corresponds to the data folder without the run number
par_id = '2022-03-29_00';

%% Convert to 2 wavelength 
dir_runs = [output_directory filesep];

PrepareDataWavelengths(input_directory, output_directory)

%% Convert to .nirs
for num_runs = 1:num_runs
    pathname = sprintf('%s%s%d', dir_runs, par_id, num_runs);
    HomerOfflineConverter(pathname)
end 
end
