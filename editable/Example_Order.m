number_questions = 38;
number_runs = 4;
number_participants = 1;

fol_out = [pwd filesep 'Orders' filesep];
if ~exist(fol_out, 'dir')
    mkdir(fol_out);
end

for par = 1:number_participants

    question_order = [randperm(number_questions) randperm(number_questions)];

    for run = 1:number_runs
        questions = question_order(1:19)';
        question_order(1:19) = [];

        number_trials = length(questions);

        xls = {'Trial' 'Question' 'RunType'};
        xls((1:number_trials)+1,1) = num2cell((1:number_trials)');
        xls((1:number_trials)+1,2) = num2cell(questions);
        xls((1:number_trials)+1,3) = {run};

        xlswrite(sprintf('%sPAR%02d_RUN%02d.xlsx', fol_out, par, run), xls);

    end
end