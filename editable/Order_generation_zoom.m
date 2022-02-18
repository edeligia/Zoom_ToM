number_questions_total = 10;
number_runs = 1;
number_participants = 30;
number_conditions_total = 2;
number_trials_total = 20;

folder_output = [pwd filesep 'FB_Orders' filesep];
if ~exist(folder_output, 'dir')
    mkdir(folder_output);
end

for par = 1:number_participants

    question_order = [randperm(number_questions_total) randperm(number_questions_total)];
    for trial_number = 1: number_trials_total 
        condition_order = [randi(2,number_trials_total,1)];
    end
    
    for run = 1:number_runs
        questions = question_order(1:20)';
        question_order(1:20) = [];
        conditions = condition_order;
        
        number_trials = length(questions);
        number_questions = 10;
        
        assign_cond1 = randperm(number_questions, round(number_questions/2));
        
        order = [];
        for first = [true false]
            questions = randperm(number_questions, number_questions)';
            
            if first
                conditions = arrayfun(@(x) ~any(x==assign_cond1), questions) + 1;
            else
                conditions = arrayfun(@(x) any(x==assign_cond1), questions) + 1;
            end
            
            order = [order; questions conditions];
        end
        
        xls = {'Trial' 'Question' 'ConditionType'};
        xls((1:number_trials)+1,1) = num2cell((1:number_trials)');
        xls(2:21,2:3) = num2cell(order);

        xlswrite(sprintf('%sPAR%02d_RUN%02d.xlsx', folder_output, par, run), xls);

    end
end