% dataset = 'Training';
dataset = 'Testing';

root_directory = [pwd filesep dataset];
task_name = dataset;

bids_info = fNIRSTools.bids.io.getBIDSInfo(root_directory, task_name, nan);
% bids_info = fNIRSTools.bids.io.getBIDSInfo(root_directory, task_name, 1, 1, 1);

%%

suffix_mc = '_MC-SPLINESG';
suffix_od = '_OD';
suffix_wf = '_MC-W5';
suffix_hp = '_HP-0.0167';
suffix_mbll = '_MBLL';
suffix_ar = '_AR-4s';
suffix_sdc = '_SDCREG-FORMATCOMBINE';

input_suffixes = {};
input_suffixes{1} = ['raw'];
input_suffixes{2} = ['raw' suffix_mc];
input_suffixes{3} = ['raw' suffix_mc suffix_od];
input_suffixes{4} = ['raw' suffix_mc suffix_od suffix_wf];
input_suffixes{5} = ['raw' suffix_mc suffix_od suffix_wf suffix_hp];
input_suffixes{6} = ['raw' suffix_mc suffix_od suffix_wf suffix_hp suffix_mbll];
input_suffixes{7} = ['raw' suffix_mc suffix_od suffix_wf suffix_hp suffix_mbll suffix_ar];
input_suffixes{8} = ['raw' suffix_mc suffix_od suffix_wf suffix_hp suffix_mbll suffix_ar suffix_sdc];

% labels = {'Raw' 'MC-SplineSG' '+OD+BP (0.01 - 0.2 Hz)'};
labels = {'raw' suffix_mc suffix_od suffix_wf suffix_hp suffix_mbll suffix_ar suffix_sdc};
labels = cellfun(@(x) strrep(x,'_',''), labels, 'UniformOutput', false);

normalize = 1;

avg_freq = false;

%%

freq_range = [];
suffix = '_All';
fNIRSTools.bids.util.plotTimeseries(bids_info, input_suffixes, suffix, labels, normalize, freq_range, avg_freq)

freq_range = [0 0.25];
suffix = '_All_Norm-ZoomFreq';
fNIRSTools.bids.util.plotTimeseries(bids_info, input_suffixes, suffix, labels, normalize, freq_range, avg_freq)
