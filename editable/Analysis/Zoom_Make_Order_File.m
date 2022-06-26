%WARNING - assumes that order of mat files matches order of data folders
%Creates an excel file containing:
%   Time Start:     samples prior to this should be removed
%   Time End:       samples after this should be removed
%   Event Table:    onset/offset of each eveent
%   ALL TIMES ARE IN SECONDS RELATIVE TO THE FIRST TRIGGER (can be negative)

% MK updates on Homa's script 24/06/2022 

function Zoom_Make_Order_File

dir_root = [pwd filesep raw' filesep];
TRIAL_DURATION_SEC = 20;

%% find participant folders
list = dir(dir_root);
list = list(arrayfun(@(i) i.name(1)~='.', list));
par_names = {list.name};
par_count = length(par_names);

%% process each participant
for p = 1:par_count
    dir_par = [dir_root par_names{p} filesep];
    fprintf('Participant %d of %d: %s\n', p, par_count, par_names{p});
    
    list = dir(dir_par);
    list = list(arrayfun(@(i) i.name(1)~='.' && i.isdir, list));
    run_names = {list.name};
    run_count = length(run_names);
    
    mat_list = dir([dir_par '*.mat']);
    mat_count = length(mat_list);
    
    if run_count ~= mat_count
        error('Number of data folders (%d) does not match number of mat files (%d)!', run_count, mat_count);
    end
    
    for r = 1:run_count
        dir_run = [dir_par run_names{r} filesep];
        fprintf('\tRun %d of %d: %s\n', r, run_count, run_names{r});
        
        fp_out = [dir_run run_names{r} '_order.xlsx'];
        if exist(fp_out, 'file')
            fprintf('\t\torder file already exists, skipping!\n');
        else
            mat = load([mat_list(r).folder filesep mat_list(r).name]);
            xls = cell(mat.d.latest_trial + 5, 5);
            xls{1,1} = 'All times must be in seconds relative to the first trigger (or first sample if there is no trigger';
            
            %all times will be relative to first trigger
            %for GRATO, this occurs at start of init baseline
            time_first_trigger = mat.d.time_start_experiment;
            
            %start/end times
            xls(2,1:2) = {'Time Start' , mat.d.time_start_experiment - time_first_trigger}; %start of initial baseline
            xls(3,1:2) = {'Time End' , mat.d.time_end_experiment - time_first_trigger}; %end of final baseline
            
            %event table
            xls(5,1:5) = {'Onset' 'Duration' 'Condition' 'Weight' 'Interest'};
            for t = 1:mat.d.latest_trial
                cond = mat.d.trial_data(t).Condition.Task;
                cond(1) = upper(cond(1));
                
                onset = mat.d.trial_data(t).timing.trigger; %already in seconds relative to time_first_trigger
                
                xls(5+t,:) = {onset , TRIAL_DURATION_SEC , cond , 1, true};
            end
            
            %save
            writecell(xls, fp_out);
        end
    end
end