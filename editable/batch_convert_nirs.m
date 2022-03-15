function batch_convert_nirs
% converts Nirstar participant files output into .nirs format
% need to be in paricipant specific folder (or folder that contains all the
% participant runs)
% par_id is the name of the run files without the run number specified 
num_runs = 4;
par_id = '2022-03-07_00';
dir_runs = [pwd filesep];
for num_runs = 3:num_runs
    pathname = sprintf('%s%s%d', dir_runs, par_id, num_runs);
    HomerOfflineConverter(pathname)
end 
end
