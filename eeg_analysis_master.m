% Add the fieldtrip package
addpath('C:\Users\KeChen\Documents\MATLAB\fieldtrip-20210629')
ft_defaults
%% load the data
clear
% define trials
% cd('D:\Data\EEG Data\071221')
datapath = pwd;
filename = 'eeg03_071521_2021-07-15_18_36_21_export.edf';
cfg            = [];
cfg.dataset    = filename;
% cfg.lpfilter   = 'yes';
% % cfg.lpfreq     = 25;
cfg.continuous = 'yes';
cfg.channel    = 'all';
data_orig           = ft_preprocessing(cfg);
%% rename the field
montage_rename          = [];
montage_rename.labelold = {'EEG EEG1A-B' 'EEG EEG2A-B' 'EMG EMG'};
montage_rename.labelnew = {'EEG1' 'EEG2' 'EMG'};
montage_rename.tra      = eye(3);

cfg         = [];
cfg.montage = montage_rename;
data_continuous = ft_preprocessing(cfg, data_orig);
%% visually inspect the data
cfg             = [];
cfg.continuous  = 'yes';
cfg.viewmode    = 'vertical'; % all channels separate
cfg.blocksize   = 10;         % view the continuous data in 30-s blocks
ft_databrowser(cfg, data_continuous);
%% 
% event = ft_read_event(filename, 'detect flank', []);
%%
% segment the continuous data in segments of 10-seconds
% we call these epochs trials, although they are not time-locked to a particular event
cfg          = [];
cfg.length   = 10; % in seconds;
cfg.overlap  = 0;
data_epoched = ft_redefinetrial(cfg, data_continuous)


%% detect movement artifacts 
cfg                              = [];
cfg.continuous                   = 'yes';
cfg.artfctdef.muscle.interactive = 'yes';

% channel selection, cutoff and padding
cfg.artfctdef.muscle.channel     = 'EMG';
cfg.artfctdef.muscle.cutoff      = 5; % z-value at which to threshold (default = 4)
cfg.artfctdef.muscle.trlpadding  = 0;

% algorithmic parameters
cfg.artfctdef.muscle.bpfilter    = 'yes';
cfg.artfctdef.muscle.bpfreq      = [20 45]; % [20 45] works very well for my data; typicall [110 140] but sampling rate is too low for that
cfg.artfctdef.muscle.bpfiltord   = 4;
cfg.artfctdef.muscle.bpfilttype  = 'but';
cfg.artfctdef.muscle.hilbert     = 'yes';
cfg.artfctdef.muscle.boxcar      = 0.2;
%% automated artifact rejection according to some threshold/
% conservative rejection intervals around EMG events
cfg.artfctdef.muscle.pretim  = 5; % pre-artifact rejection-interval in seconds
cfg.artfctdef.muscle.psttim  = 5; % post-artifact rejection-interval in seconds

% keep a copy for the exercise
cfg_muscle_epoched = cfg;

% feedback, explore the right threshold for all data (one trial, th=4 z-values)
cfg = ft_artifact_muscle(cfg, data_continuous);

% make a copy of the samples where the EMG artifacts start and end, this is needed further down
EMG_detected = cfg.artfctdef.muscle.artifact;
%% visualize the artifact
cfg_art_browse             = cfg;
cfg_art_browse.continuous  = 'yes';
cfg_art_browse.viewmode    = 'vertical';
cfg_art_browse.blocksize   = 10; % view the data in 10-minute blocks
ft_databrowser(cfg_art_browse, data_continuous);

%% for epoch data 
cfg_muscle_epoched.continuous                   = 'no';
cfg_muscle_epoched.artfctdef.muscle.interactive = 'yes';
cfg_muscle_epoched = ft_artifact_muscle(cfg_muscle_epoched, data_epoched);

%% replace the artifactual segments with zero
cfg = [];
cfg.artfctdef.muscle.artifact = EMG_detected;
cfg.artfctdef.reject          = 'value';
cfg.artfctdef.value           = 0;
data_continuous_clean = ft_rejectartifact(cfg, data_continuous);
data_epoched_clean    = ft_rejectartifact(cfg, data_epoched);

%% visualize data after removing artifacts
cfg             = [];
cfg.continuous  = 'yes';
cfg.viewmode    = 'vertical';
cfg.blocksize   = 60; % view the data in blocks
ft_databrowser(cfg, data_continuous_clean);

%%
% define the EEG frequency bands of interest
freq_bands = [
  0.5  4    % slow-wave band actity
  4    8    % theta band actity
  8   11    % alpha band actity
  11  16    % spindle band actity
  ];

cfg = [];
cfg.output        = 'pow';
cfg.channel       = 'EEG2';  % {'EEG1', 'EEG2'}
cfg.method        = 'mtmfft';
cfg.taper         = 'hanning';
cfg.foi           = 0.5:0.5:30; % in 0.5 Hz steps
cfg.keeptrials    = 'yes';
freq_epoched = ft_freqanalysis(cfg, data_epoched_clean);
%% reconstruct the time
begsample = data_epoched_clean.sampleinfo(:,1);
endsample = data_epoched_clean.sampleinfo(:,2);
time      = ((begsample+endsample)/2) / data_epoched_clean.fsample;
%%

freq_continuous           = freq_epoched;
freq_continuous.powspctrm = permute(freq_epoched.powspctrm, [2, 3, 1]);
freq_continuous.dimord    = 'chan_freq_time'; % it used to be 'rpt_chan_freq'
freq_continuous.time      = time;             % add the description of the time dimension
%%

figure
cfg                = [];
cfg.baseline       = [min(freq_continuous.time) max(freq_continuous.time)];
cfg.baselinetype   = 'normchange';
cfg.zlim           = [-0.5 0.5];
ft_singleplotTFR(cfg, freq_continuous);

%%
cfg                     = [];
cfg.frequency           = freq_bands(1,:);
cfg.avgoverfreq         = 'yes';
freq_continuous_swa     = ft_selectdata(cfg, freq_continuous);

cfg                     = [];
cfg.frequency           = freq_bands(2,:);
cfg.avgoverfreq         = 'yes';
freq_continuous_theta   = ft_selectdata(cfg, freq_continuous);

cfg                     = [];
cfg.frequency           = freq_bands(3,:);
cfg.avgoverfreq         = 'yes';
freq_continuous_alpha   = ft_selectdata(cfg, freq_continuous);

cfg                     = [];
cfg.frequency           = freq_bands(4,:);
cfg.avgoverfreq         = 'yes';
freq_continuous_spindle = ft_selectdata(cfg, freq_continuous);

%%
  data_continuous_swa                  = [];
  data_continuous_swa.label            = {'swa'};
  data_continuous_swa.time{1}          = freq_continuous_swa.time;
  data_continuous_swa.trial{1}         = squeeze(freq_continuous_swa.powspctrm)';

  data_continuous_swa_spindle          = [];
  data_continuous_swa_spindle.label    = {'theta'};
  data_continuous_swa_spindle.time{1}  = freq_continuous_theta.time;
  data_continuous_swa_spindle.trial{1} = squeeze(freq_continuous_theta.powspctrm)';

  data_continuous_alpha                = [];
  data_continuous_alpha.label          = {'alpha'};
  data_continuous_alpha.time{1}        = freq_continuous_alpha.time;
  data_continuous_alpha.trial{1}       = squeeze(freq_continuous_alpha.powspctrm)';

  data_continuous_spindle              = [];
  data_continuous_spindle.label        = {'spindle'};
  data_continuous_spindle.time{1}      = freq_continuous_spindle.time;
  data_continuous_spindle.trial{1}     = squeeze(freq_continuous_spindle.powspctrm)';

  cfg = [];
  data_continuous_perband = ft_appenddata(cfg, ...
  data_continuous_swa, ...
  data_continuous_swa_spindle, ...
  data_continuous_alpha, ...
  data_continuous_spindle);

%%
cfg        = [];
cfg.scale  = 100; % in percent
cfg.demean = 'no';
data_continuous_perband = ft_channelnormalise(cfg, data_continuous_perband);

cfg        = [];
cfg.boxcar = 30;
data_continuous_perband = ft_preprocessing(cfg, data_continuous_perband);
%% browse the power of each band
cfg             = [];
cfg.continuous  = 'yes';
cfg.viewmode    = 'vertical';
cfg.blocksize   = 60; %view the whole data in blocks
ft_databrowser(cfg, data_continuous_perband);