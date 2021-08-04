curDir = pwd;
clc
try 
	version = PsychtoolboxVersion;
	disp(sprintf('Psychtoolbox found. Version:\n----------------------------\n%s',version));
catch
	uiwait(warndlg('Psychtoolbox not detected on this machine. You must install psychtoolbox for ep_localizer to work correctly.','modal'));
	return
end
uiwait(msgbox('Select your main experimental directory. The directory ep_localizer will be made here.','modal'));
folder_name = uigetdir(pwd);
root_dir = fullfile(folder_name,'mov_localizer');
stimuli_dir = fullfile(root_dir,'stimuli');
beha_dir = fullfile(root_dir,'behavioural');
fprintf('\n');
disp(sprintf('Making directory %s',root_dir))
mkdir(root_dir);
fileList{1} = root_dir;
disp(sprintf('Making directory %s',stimuli_dir))
mkdir(stimuli_dir);
fileList{end+1} = stimuli_dir;
disp(sprintf('Making directory %s',beha_dir))
mkdir(beha_dir);
disp(sprintf('\n----------------------------\n'));
disp(sprintf('Copying mov_localizer.m'));
copyfile(fullfile(pwd,'mov_localizer.m'),fullfile(root_dir,'mov_localizer.m'));
fileList{end+1} = fullfile(root_dir,'mov_localizer.m');
disp(sprintf('Copying mov_localizer_rc.m'));
copyfile(fullfile(pwd,'mov_localizer_rc.m'),fullfile(root_dir,'mov_localizer_rc.m'));
fileList{end+1} = fullfile(root_dir,'mov_localizer_rc.m');
disp(sprintf('\n----------------------------\n'));
disp('...Validating...');
jlen = 0;
for i=1:length(fileList)
	if ~exist(fileList{i})
		fprintf('Could not find %s! Setup failed.',fileList{i})
		return
	end
	j = sprintf('%.1f',(i/length(fileList)*100));
	fprintf(repmat('\b',[1 jlen]));
	jlen = length(j);
	fprintf(j);
end
disp(sprintf('\n----------------------------\n'));
fprintf('Setup has completed successfully!\n');
fprintf('You now need to purchase the stimuli and save the movie as "partly_cloudy.mov" in the stimuli folder\n') 