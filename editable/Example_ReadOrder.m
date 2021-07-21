par = 1;
run = 2;

fol_out = [pwd filesep 'Orders' filesep];

filepath = sprintf('%sPAR%02d_RUN%02d.xlsx', fol_out, par, run);

[numbers_only_info,~,all_info_cell_matrix] = xlsread(filepath)

headers = all_info_cell_matrix(1,:)
values = all_info_cell_matrix(2:end,:)


trial = 10;
question_number = numbers_only_info(10,2)
question_number = values{10,2}