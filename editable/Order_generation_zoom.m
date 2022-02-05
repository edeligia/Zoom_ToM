number_questions_total = 10;
number_runs = 1;
number_participants = 2;
number_conditions_total = 2;
number_trials_total = 20;

folder_output = [pwd filesep 'Orders' filesep];
if ~exist(folder_output, 'dir')
    mkdir(folder_output);
end

for par = 1:number_participants

    question_order = [randperm(number_questions_total) randperm(number_questions_total)];
    for trial_number = 1: number_trials_total 
        run_order = [randi(2,number_trials_total,1)];
    end
    
    for run = 1:number_runs
        questions = question_order(1:20)';
        question_order(1:20) = [];
        runs = run_order;
        
        number_trials = length(questions);

        xls = {'Trial' 'Question' 'ConditionType'};
        xls((1:number_trials)+1,1) = num2cell((1:number_trials)');
        xls((1:number_trials)+1,2) = num2cell(questions);
        xls((1:number_trials)+1,3) = num2cell(runs);

        xlswrite(sprintf('%sPAR%02d_RUN%02d.xlsx', folder_output, par, run), xls);

    end
end