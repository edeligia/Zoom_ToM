number_questions_total = 38;
number_runs = 4;
number_participants = 1; %to be increased when script is tested
number_conditions_total = 4;
number_trials_total = 16; %doing each run seperately 
optseq_filepath = sprintf('IAPS-%03d', run);
%creates the folder in directory
% folder_output = [pwd filesep 'Task_Orders' filesep];
% if ~exist(folder_output, 'dir')
%     mkdir(folder_output);
% end

%generate random order of trials
for par = 1:number_participants

    question_order = [randperm(number_questions) randperm(number_questions)];

    for run = 1:number_runs
        %read in optseq order
        optseq_filepath = sprintf('IAPS-%03d', run);
        [~,~,xls_op] = xlsread(optseq_filepath);
        
        questions = question_order(1:16)';
%         question_order(1:16) = [];

        number_trials = length(questions);

        xls = {'Trial' 'Question' 'RunType'};
        xls((1:number_trials)+1,1) = num2cell((1:number_trials)');
        xls((1:number_trials)+1,2) = num2cell(questions);
        xls((1:number_trials)+1,3) = {run};

        xlswrite(sprintf('%sPAR%02d_RUN%02d.xlsx', folder_output, par, run), xls);

    end
end