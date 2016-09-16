%% look at the neural data in response to cortical stimulation

% load in subject

% this is from my z_constants
%
% % clear workspace
% close all; clear all; clc
%
% % set input output working directories - for David's PC right now
% Z_ConstantsStimResponse;
%
% % add path for scripts to work with data tanks
% addpath('./scripts')
%
% % subject directory, change as needed
% % SUB_DIR = fullfile(myGetenv('subject_dir')); - for David's PC right now
%
% % data directory
%
% %PUT PATH TO DATA DIRECTORY WITH CONVERTED DATA FILES
%
% % DJC Desktop
% DATA_DIR = 'C:\Users\djcald\Data\ConvertedTDTfiles';
%
% % DJC Laptop
% %DATA_DIR = 'C:\Users\David\GoogleDriveUW\GRIDLabDavidShared\ResponseTiming';
%
% SIDS = {'acabb1'};

%%
sid = SIDS{2};

% ui box for input
list_str = {'1st block','2nd block','1st block with no tactor','2nd block with no tactor'};

[s,v] = listdlg('PromptString','Pick experiment',...
    'SelectionMode','single',...
    'ListString',list_str);

% load in data
if (strcmp(sid, 'c19968'))
    folder_data = strcat(DATA_DIR,'\c19968');
    
    if s == 1
        load(fullfile(folder_data,'ReactionTime_c19968-7.mat'))
        block = '1';
    elseif s == 2
        load(fullfile(folder_data,'ReactionTime_c19968-11.mat'))
        block = '2';
    elseif s == 3
        load(fullfile(folder_data,'ReactionTime_c19968-3.mat'))
        block = '1_cort_stimOnly';
    elseif s == 4
        load(fullfile(folder_data,'ReactionTime_c19968-4.mat'))
        block = '1_cort_stimOnly';
        
    end
    
end

%% neural data

% the eco data is crashing it right now
clearvars -except ECO1 ECO2 Tact sid block
eco1 = ECO1.data;
fs_data = ECO1.info.SamplingRateHz;
eco_fs = fs_data;
clear ECO1
eco2 = ECO2.data;
clear ECO2


data = [eco1 eco2];
clearvars eco1 eco2

load([sid,'_compareResponse_block_',block,'.mat'])

%% get train times

% look at stim from file saved (this is the sample where things were
% delivered
tact = Tact.data;
fs_tact = Tact.info.SamplingRateHz;
stimFromFile = tact(:,3);

% get stimulation times of delivery
trainTimes = find(stimFromFile~=0);

% convert sample times for eco

convertSamps = fs_tact/fs_data;

trainTimesConvert = round(stimTimes/convertSamps);


%% cortical brain data
% ui box for input
prompt = {'Channel of interest?','Trim ends?','condition'};
dlg_title = 'Channel of Interest';
num_lines = 1;
defaultans = {'10','y','-1'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);

chanInt = str2num(answer{1});
trimEnds = answer{2};
condInt = str2num(answer{3});
condInt = find(uniqueCond==condInt);
% where to begin plotting with artifact
artifact_end = round(0.05*eco_fs);

%where to end plotting
sampsEnd = round(2*eco_fs);

%presamps - where to begin looking for "rest" period (500 ms before?)
presamps = round(0.5*eco_fs);

trainTimesCell = {};
trainTimesCellThresh = {};

for i = 1:length(uniqueCond)
    
    trainTimesCell{i} = trainTimesConvert(condType==uniqueCond(i));
    trim = buttonLocs{i};
    trim = trim(trim>respLo & trim<respHi);
    zTrim = zscore(trim);
    if ~isempty(trainTimesCell{i}) % check to make sure not indexing empty cell
        trainTimesCellThresh{i} = trainTimesCell{i}(abs(zTrim)<3);
    end
end

%%

% epoched button press, before stim to after
epochedCortEco = squeeze(getEpochSignal(data,(trainTimesCellThresh{condInt} + artifact_end),(trainTimesCellThresh{condInt}+ sampsEnd)));

% get pre stim period for comparison
epochedPreStim = squeeze(getEpochSignal(data,(trainTimesCellThresh{condInt} - presamps), trainTimesCellThresh{condInt}));

% plot channel of interest
figure

% channel of interest, plot mean
t_epoch = [artifact_end:artifact_end+size(epochedCortEco,1)-1]/eco_fs;
t_epochPre = [-presamps:0-1]/eco_fs;

exampChanPost = mean(squeeze(epochedCortEco(:,chanInt,:)),2)-mean(exampChanPost);
exampChanPre = mean(squeeze(epochedPreStim(:,chanInt,:)),2)-mean(exampChanPre);


subplot(2,1,1)
plot(1e3*t_epoch,exampChanPost);
xlabel('time (ms)')
ylabel('Voltage (V)')
title(['Post stim Raw data for Channel ', num2str(chanInt)])

subplot(2,1,2)
plot(1e3*t_epochPre,exampChanPre);
xlabel('time (ms)')
ylabel('Voltage (V)')
title(['Pre Stim Raw data for Channel ', num2str(chanInt)])
%         pause(1)

% trial by trial notch and extract power
%%
% from quick screen

% trials
trialHG = zeros(size(epochedCortEco,1),size(epochedCortEco,2),size(epochedCortEco,3));
trialBeta = zeros(size(epochedCortEco,1),size(epochedCortEco,2),size(epochedCortEco,3));

% rest
restHG = zeros(size(epochedPreStim,1),size(epochedPreStim,2),size(epochedPreStim,3));
restBeta = zeros(size(epochedPreStim,1),size(epochedPreStim,2),size(epochedPreStim,3));

% for each trial, run the functions below - only want to filter pre and
% post
for i = 1:size(epochedCortEco,3)
    % notch filter to eliminate line noise
    sigT = squeeze(epochedCortEco(:,:,i));
    sigR = squeeze(epochedPreStim(:,:,i));
    
    sigT = notch(sigT, [60 120 180], eco_fs, 4);
    sigR = notch(sigR, [60 120 180], eco_fs, 4);
    
    % extract HG and Beta power bands
    logHGPowerT = log(hilbAmp(sigT, [70 200], eco_fs).^2);
    logBetaPowerT = log(hilbAmp(sigT, [12 30], eco_fs).^2);
    
    logHGPowerR = log(hilbAmp(sigR, [70 200], eco_fs).^2);
    logBetaPowerR = log(hilbAmp(sigR, [12 30], eco_fs).^2);
    
    trialHG(:,:,i) = logHGPowerT;
    trialBeta(:,:,i) = logBetaPowerT;
    
    
    restHG(:,:,i) = logHGPowerR;
    restBeta(:,:,i) = logBetaPowerR;
end

% part for getting rid of funny filtering at beginning and end
t_min = 0.2; % in seconds
t_max = 1.5; % in seconds

t_minPre = -0.4;
t_maxPre = -0.1;

if strcmp(trimEnds,'y')
    
    %temporary ones
    
    t_epochT = t_epoch(t_epoch>t_min & t_epoch<t_max);
    t_epochPreT = t_epochPre(t_epochPre>t_minPre & t_epochPre<t_maxPre);
    trialHGT = trialHG(t_epoch>t_min & t_epoch<t_max,:,:);
    trialBetaT = trialBeta(t_epoch>t_min & t_epoch<t_max,:,:);
    restHGT = restHG(t_epochPre>t_minPre & t_epochPre<t_maxPre,:,:);
    restBetaT = restBeta(t_epochPre>t_minPre & t_epochPre<t_maxPre,:,:);
    
    clear t_epoch t_epochPre trialHG trialBeta restHG restBeta
    
    t_epoch = t_epochT;
    t_epochPre = t_epochPreT;
    trialHG = trialHGT;
    trialBeta = trialBetaT;
    restHG = restHGT;
    restBeta = restBetaT;
    
end
%%
% sort by reaction time
[sorted,indexes] = sort(cort);

trialHGsort = trialHG(:,:,indexes);
trialBetasort = trialBeta(:,:,indexes);

restHGsort = restHG(:,:,indexes);
restBetasort = restBeta(:,:,indexes);


% find significant differences for all channels

restHG_ave = squeeze(mean(restHGsort,1));
restBeta_ave = squeeze(mean(restBetasort,1));
trialHG_ave = squeeze(mean(trialHGsort,1));
trialBeta_ave = squeeze(mean(trialBetasort,1));

numChans = size(raw_eco,2);
chans = 1:numChans;

ptarg = 0.05 / numChans;

HGSigs = ttest2(restHG_ave, trialHG_ave, ptarg, 'r', 'unequal', 2);
BetaSigs = ttest2(restBeta_ave, trialBeta_ave, ptarg, 'r', 'unequal', 2);

HGSigs = HGSigs == 1; % make boolean
BetaSigs = BetaSigs == 1; % make boolean


HGRSAs = signedSquaredXCorrValue(restHG_ave, trialHG_ave, 2);
BetaRSAs = signedSquaredXCorrValue(restBeta_ave, trialBeta_ave, 2);

%HG figure
figure
plot(chans, HGRSAs);
hold on;
plot(chans(HGSigs), HGRSAs(HGSigs), '*');

xlabel('channel number');
ylabel('R^2');
title('Aggregated HG Response');
legend('aggregate activity');

% Beta
figure;
plot(chans, BetaRSAs);
hold on;
plot(chans(BetaSigs), BetaRSAs(BetaSigs), '*');

xlabel('channel number');
ylabel('R^2');
title('Aggregated Beta Response');
legend('aggregate activity');


% plot example channel
%% plot channel of interest


trial = 1:length(sorted);

figure
imagesc(1e3*t_epoch,trial,squeeze(trialHGsort(:,chanInt,:))')
axis xy
xlabel('Time (ms)')
ylabel('Trial')
title(['High Gamma power in channel ', num2str(chanInt)])

figure
imagesc(1e3*t_epoch,trial,squeeze(trialBetasort(:,chanInt,:))')
axis xy
xlabel('Time (ms)')
ylabel('Trial')
title(['Beta power in channel ', num2str(chanInt)])

%%


%     % from Stavros code - filter ?
%
%     % assume stimulation is over by 210 ms or so, so select segments where
%     % t>210
%
%     % attempt to fit exponential decay to post-stim segment
%     %pp = smooth(c2plot(supsam(2)+1:end),smoothfw);
%     pp = exampChan((t_epoch>210):end);
%     [f,gof] = fit([1:length(pp)]',pp','exp2'); % 2-term exponential
%     if gof.adjrsquare>0.8
%         % subtract exp function if R2>0.8
%         ppc = pp' - f([1:length(pp)]');
%     else
%         ppc = pp';
%     end
%
%     % smooth post-stim segment using Savitzky-Golay filtering
%     smppc = sgolayfilt(ppc,5,81);
%
%     % end of stavros code

%% time frequency wavelet

fw = 1:1:200;


[C_post, ~, C_totPost, ~] = time_frequency_wavelet(squeeze(epochedCortEco(t_epoch>t_min & t_epoch<t_max,chanInt,:)), fw, eco_fs, 1, 1, 'CPUtest');
[C_pre, ~, C_totPre, ~] = time_frequency_wavelet(squeeze(epochedPreStim(t_epochPre>t_minPre &t_epochPre<t_maxPre,chanInt,:)), fw, eco_fs, 1, 1, 'CPUtest');
C_norm = normalize_data(C_post',C_pre');

figure
imagesc(1e3*t_epoch,fw,C_norm);
set_colormap_threshold(gcf, [-1 1], [-7 7], [1 1 1]);
colorbar
axis xy
xlabel('time (ms)');
ylabel('frequency (hz)');
title(['Normalized wavelet data for Channel ', num2str(chanInt)])


figure
imagesc(1e3*t_epoch,fw,C_post');
%set_colormap_threshold(gcf, [-1 1], [-7 7], [1 1 1]);
colorbar
axis xy
xlabel('time (ms)');
ylabel('frequency (hz)');
title(['Normalized wavelet data for Channel ', num2str(chanInt)])



figure
imagesc(1e3*t_epochPre,fw,C_pre');
%set_colormap_threshold(gcf, [-1 1], [-7 7], [1 1 1]);
colorbar
axis xy
xlabel('time (ms)');
ylabel('frequency (hz)');
title(['Normalized wavelet data for Channel ', num2str(chanInt)])




% pick condition type where stimulation was delivered
if s == 1
    trainTimesCond1 = trainTimes(condType==0);
elseif s == 2
    trainTimesCond1 = trainTimes(condType==0 | condType==1);
end

sampsEnd = round(2*fs_stim);

% epoched button press
epochedButton = squeeze(getEpochSignal(buttonDataClip,trainTimesCond1,(trainTimesCond1 + sampsEnd)));

figure
t_epoch = [0:size(epochedButton,1)-1]/fs_stim;
plot(t_epoch,epochedButton);

%% tactor brain data