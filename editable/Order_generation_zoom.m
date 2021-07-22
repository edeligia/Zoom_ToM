number_questions_total = 38;
number_runs = 4;
number_participants = 1;

folder_output = [pwd filesep 'Orders' filesep];
if ~exist(folder_output, 'dir')
    mkdir(folder_output);
end

for par = 1:number_participants

    question_order = [randperm(number_questions_total) randperm(number_questions_total)];

    for run = 1:number_runs
        questions = question_order(1:19)';
        question_order(1:19) = [];

        number_trials = length(questions);

        xls = {'Trial' 'Question' 'RunType'};
        xls((1:number_trials)+1,1) = num2cell((1:number_trials)');
        xls((1:number_trials)+1,2) = num2cell(questions);
        xls((1:number_trials)+1,3) = {run};

        xlswrite(sprintf('%sPAR%02d_RUN%02d.xlsx', folder_output, par, run), xls);

    end
end