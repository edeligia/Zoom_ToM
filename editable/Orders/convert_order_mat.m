for par_num = 1:30

DIR_OUT = [pwd filesep 'Mat Orders' filesep];
DIR_IN = [pwd filesep];

for run = 1:4
    orderfilepath = sprintf('%sPAR%02d_RUN%02d.xlsx', DIR_IN, par_num, run);

    [~,~,xls] = xlsread(orderfilepath);

    fp = sprintf('%sPAR%02d_RUN%02d.xlsx', DIR_OUT, par_num, run);
    fprintf('Writing: %s\n', fp);
    fp = strrep(fp, '.xlsx', '.mat');
    save(fp, 'xls');
end
end 