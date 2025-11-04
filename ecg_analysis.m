clear; clc;
% load simulator mat
fname = "tests/noisySignal.mat";
S = load(fname);

if isfield(S, "Time") && isfield(S, "Signal")
    Time = S.Time(:); 
    Signal = S.Signal(:);
else
    error("inputted structure is wrong needs to have a Time and Signal array")
end


% ecg matlab
t = Time(:);
x = Signal(:);
% make column vectors 

% get sampling rate 1/f
fs = 1/median(diff(t)); % diff gets sampling interval

% do some cleanup
x = x - median(x); % remove DC

% remove baseline wander 
[b_hp, a_hp] = butter(2, 0.5/(fs/2), 'high');
x_hp = filtfilt(b_hp, a_hp, x);

% have a notch filter 50Hz (mains)
f0 = 50; 
bw = 1.0;             % 1 Hz notch width 
x_n = bandstop(x_hp, [f0 - bw/2, f0 + bw/2], fs, ...
               "Steepness", 0.95, "StopbandAttenuation", 60);

% bandpass filter for ecg
% normalize between 0 and 1 a: denominator coefficients b: numerator coef.
[b, a] = butter(2, [5 40]/(fs/2)); % cutoff frequencies 5 to 40
xf = filtfilt(b,a,x_n); % apply filter forwards and backwards

% do R peak detection
minDistance = round(0.30 * fs); % 0.25s is 240 bpm thats too fast
prom = max(0.15*std(xf), 0.02); % adaptive prominence
% get median of all noises so you get avg noise -> R peaks is 4 times noise
[pks, locs] = findpeaks(xf, "MinPeakProminence", prom, "MinPeakDistance", minDistance);

% protect against too few peaks -> strategy is too aggresive
if numel(locs) < 3
    [pks, locs] = findpeaks(xf, "MinPeakProminence", max(0.10*std(xf), 0.01) , "MinPeakDistance", minDistance);
end

% get metrics from the difference in R peaks
rr_interval = diff(locs) / fs; % gaps between r peaks
if isempty(rr_interval)
    error("no beats found big error");
end
% get the heartbeat which is rr_interval every 60 seconds
hr = 60/mean(rr_interval);
% get standard deviations of heart rates
sdn_rr = std(rr_interval)*1000; % get it in milliseconds instead of seconds
rms_rr = sqrt(mean(diff(rr_interval).^2)) * 1000; % ms
% check for irregular rythmn by measuring irregular intervals
pnn50 = mean(abs(diff(rr_interval)*1000)> 50)*100; % percentage

flags = {}; % used to store different types of data types
if hr > 100
    flags{end+1} = "Elevated heart rate patterns associated with tachycardia";
elseif hr < 60
    flags{end+1} = "Reduced heart rate patterns associated with bradycardia";
end
if (sdn_rr > 100 || rms_rr > 50)
    flags{end+1} = "Irregular rythmn and high HRV may be linked to arrhythmias or ectopic activity";
end
if isempty(flags)
    flags{end+1} = "No significant abnormal rythmn indicators observed in this signal";
end

% display the findings
fprintf("----ECG Pattern Report-----\n");
fprintf("fs        : %.2f Hz\n", fs);
fprintf("Beats     : %d Beats\n", numel(locs));
fprintf("Mean HR   : %.1f bpm\n", hr);
fprintf("SDNN      : %.5f ms\n", sdn_rr);
fprintf("RMSSD     : %.5f ms\n", rms_rr);
fprintf("pNN50     : %.5f %%\n", pnn50);
if ~isempty(flags)
    fprintf("Notes     : %s\n", strjoin(string(flags), ", "));
end

% visualize everything raw signal vs nose reduced one
figure;

subplot(2,1,1);
plot(t, x, 'k');
grid on;
xlabel("Time (s)"); ylabel("Amplitude (mV)");
title("Original ECG Signal");
legend("Raw ECG");
subplot(2,1,2);
plot(t, xf, 'b'); hold on;
plot(t(locs), xf(locs), 'ro', 'MarkerFaceColor', 'r');
xlabel("Time (s)"); ylabel("Amplitude (mV)");
title("Filtered ECG with Detected R-Peaks");
legend("Filtered Signal", "R-peaks");
grid on;

