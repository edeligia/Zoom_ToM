p.DIR_ORDERS = [pwd filesep 'Orders' filesep];
d.participant_number = participant_number;
d.run_number = run_number;
d.filepath_order = sprintf('%sParticipant%02d_Run%d.mat', p.DIR_ORDERS, d.participant_number, d.run_number);
%read order
%[~,~,xls] = xlsread([p.DIR_ORDERS d.filename_order]);
load(d.filepath_order);
%order raw file is the excel file
d.order.raw = xls;
%order headers are the first row containing all the columns
d.order.headers = xls(1,:);
%the data is the second row onwards for all the columns 
d.order.data = xls(2:end,:);

%% Prepare Order
%the number of trials is the number of rows in column 1
d.number_trials = size(d.order.data, 1);
for trial = 1:d.number_trials
    %handle blank rows at end of excel
    if ~any(~cellfun(@(x) length(x)==1 && isnan(x), d.order.data(trial,:)))
        d.number_trials = trial;
        break;
    end
    
    %copy from excel
    for f = 1:length(d.order.headers)
        eval(sprintf('d.trial_data(trial).Condition.%s = d.order.data{trial,f};', d.order.headers{f}));
    end