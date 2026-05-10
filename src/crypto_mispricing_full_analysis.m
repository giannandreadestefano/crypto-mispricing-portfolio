%% Crypto Mispricing and Portfolio Diversification
% Full MATLAB script for the research project:
% "Crypto Mispricing and Portfolio Diversification: Evidence from a Long-Short Strategy"
%
% This script includes:
% - 60/40 benchmark portfolio construction using SPY and AGG
% - Fama-French and Momentum factor preparation
% - CryptoCompare data collection
% - Size and Risk-Adjusted Momentum signal construction
% - Weekly long-short crypto strategy backtest
% - Hybrid 60/40 + crypto portfolio integration
% - Performance metrics, regressions, GARCH models, bootstrap and stress tests
%
% Author: Giannandrea De Stefano, with Gabriele Achia and Paolo Gaudenzi
% Academic project for Econometric Theory
%
% Note:
% API keys, raw datasets and local file paths are not included in this repository.
% To run the script, users must provide the required input datasets and set their
% own CryptoCompare API key as an environment variable.

clc

clear

%% Importazione e Pulizia dei Dati da CSV
T = readtable('spy_agg_data.csv');
T(1,:) = [];

T.Properties.VariableNames = {
   'Date','AGG_Close','SPY_Close','AGG_High','SPY_High',...
   'AGG_Low','SPY_Low','AGG_Open','SPY_Open','AGG_Volume','SPY_Volume'
};

head(T)

%% Costruzione del portafoglio 60/40 con RIBILANCIAMENTO MENSILE

% 1) Definizione dell’asset allocation target
w_target = [0.60; 0.40]; 
% 60% per l’azionario (SPY), 40% per l’obbligazionario (AGG)

% 2) Selezione degli ETF (colonne rinominate: T.SPY_Close, T.AGG_Close)
spyPrices = T.SPY_Close;
aggPrices = T.AGG_Close;

% 3) Calcolo dei rendimenti logaritmici giornalieri
spyRet = diff(log(spyPrices));
aggRet = diff(log(aggPrices));

% 4) Allineamento delle date (le prime righe di rendimenti corrispondono alla differenza tra la 2^ e 1^ riga dei prezzi)
retDates = T.Date(2:end);

%% 5) Prepara vettori/variabili dove salveremo i valori di portafoglio e i pesi nel tempo
N = length(retDates);
portVal    = nan(N,1);   % Valore complessivo del portafoglio in ciascun giorno
weightSPY  = nan(N,1);   % Peso di SPY sul totale
weightAGG  = nan(N,1);   % Peso di AGG sul totale

% 6) Imposta il capitale iniziale e i pesi il primo giorno
portVal(1)   = 1;           % partiamo con 1 unità di capitale (o 100)
weightSPY(1) = w_target(1);
weightAGG(1) = w_target(2);

% 7) Identifica il mese per ciascun giorno
%    Per ribilanciare all'inizio di ogni mese
monthVec = month(retDates);
yearVec  = year(retDates);
% Crea un indicatore (annomese) che useremo per vedere quando cambia il mese
yearMonth = yearVec*100 + monthVec; % es. 202001 per gennaio 2020

%% 8) Ciclo su tutti i giorni, aggiornando il valore di portafoglio e ribilanciando se cambia il mese
for i = 2:N
    
    % --- Aggiorna il valore delle componenti:
    % Il portafoglio di ieri era portVal(i-1).
    % I pesi di ieri (weightSPY, weightAGG) ci dicono quale % di capitale era in SPY e AGG.
    
    % Calcoliamo i fattori di crescita giornaliera per SPY e AGG (log-return -> return semplice)
    spyFactor = exp(spyRet(i));  % da log-ret a fattore di crescita (e^r)
    aggFactor = exp(aggRet(i));
    
    % Capitale in SPY ieri:
    capSPY_yesterday = portVal(i-1) * weightSPY(i-1);
    % Capitale in AGG ieri:
    capAGG_yesterday = portVal(i-1) * weightAGG(i-1);
    
    % Capitale di oggi (prima del ribilanciamento) = crescita per i fattori di ieri->oggi
    capSPY_today = capSPY_yesterday * spyFactor;
    capAGG_today = capAGG_yesterday * aggFactor;
    
    % Valore totale del portafoglio oggi (prima del ribilanciamento)
    portVal_today = capSPY_today + capAGG_today;
    
    % --- Verifichiamo se oggi iniziamo un nuovo mese rispetto a ieri:
    if yearMonth(i) ~= yearMonth(i-1)
        % Siamo passati a un nuovo mese → Ribilanciamento
        capSPY_today = portVal_today * w_target(1);
        capAGG_today = portVal_today * w_target(2);
        portVal_today = capSPY_today + capAGG_today; % (ridondante ma chiaro)
    end
    
    % Salviamo i risultati
    portVal(i)   = portVal_today;
    weightSPY(i) = capSPY_today / portVal_today;
    weightAGG(i) = capAGG_today / portVal_today;
end

%% 9) Calcoliamo i rendimenti logaritmici effettivi del portafoglio con ribilanciamento
%    portVal(i) è il valore del portafoglio al giorno i
%    Il log-return tra i-1 e i: log( portVal(i) ) - log( portVal(i-1) )
portRet_rebal = diff(log(portVal)); % dimensione N-1

% Creiamo una tabella con date (dalla 2^ alla N^, perché la 1^ non ha un "precedente")
PortfolioRebal = table(retDates(2:end), portRet_rebal, ...
    'VariableNames', {'Date','Port_LogRet'});

%% Statistiche
meanLogRet = mean(portRet_rebal);
stdLogRet  = std(portRet_rebal);

meanLogRetAnn = meanLogRet * 252;
stdLogRetAnn  = stdLogRet * sqrt(252);
sharpeRatio   = meanLogRetAnn / stdLogRetAnn;

fprintf('\n Portafoglio 60/40 con Ribilanciamento Mensile \n');
fprintf('Media log-return giornaliera:    %.6f\n', meanLogRet);
fprintf('Deviazione standard giornaliera: %.6f\n', stdLogRet);
fprintf('Media log-return annualizzata:   %.4f\n', meanLogRetAnn);
fprintf('Volatilita annualizzata:         %.4f\n', stdLogRetAnn);
fprintf('Sharpe Ratio:                    %.3f\n', sharpeRatio);

%% Grafico della performance cumulata (con ribilanciamento mensile)
portValCumulative = portVal;   % portVal(i) is already the cumulative value
figure;
plot(retDates, portValCumulative, 'LineWidth', 1.2);
xtickformat('yyyy');
title('Cumulative Performance – 60/40 Portfolio (Monthly Rebalancing)');
xlabel('Date');
ylabel('Cumulative Value (Base = 1)');
grid on;

%% Drawdown Analysis
cumReturn = portVal;  % already cumulative
peak = cummax(cumReturn);
drawdown = (cumReturn - peak) ./ peak;
maxDrawdown = min(drawdown);

fprintf('Max Drawdown: %.2f%%\n', maxDrawdown * 100);

figure;
area(retDates, drawdown * 100, 'FaceColor', [0.85 0.33 0.10]);
title('Drawdown – 60/40 Portfolio');
xlabel('Date');
ylabel('Drawdown (%)');
grid on;

%% Rolling Sharpe Ratio
% 1) Il vettore di date per i rendimenti è retDates(2:end), lungo N-1
datesRet = retDates(2:end);   % dimensione = N-1

% 2) Rolling Sharpe su portRet_rebal (lunghezza N-1)
window = 252;
rollingSharpe = movmean(portRet_rebal, window) ./ movstd(portRet_rebal, window) * sqrt(252);

% 3) Ora definisci le date corrispondenti alla finestra
plotDates = datesRet(window:end);
plotSharpe = rollingSharpe(window:end);

figure;
plot(plotDates, plotSharpe, 'LineWidth', 1.3);
title('Sharpe Ratio Rolling (1-Year Window)');
xlabel('Date');
ylabel('Sharpe Ratio');
grid on;

%% Analisi del VaR Mensile (5%)

% Step 1: Calcolo dei rendimenti log mensili
TT_port = timetable(retDates, log(portVal));  % log dei valori cumulati
TT_port_monthly = retime(TT_port, 'monthly', 'lastvalue');
monthlyLogRet = diff(TT_port_monthly.Var1);  % rendimento log mensile

% Step 2: VaR 5%
VaR_5 = prctile(monthlyLogRet, 5);  
VaR_5_pct = (exp(VaR_5) - 1) * 100;

% Step 3: Output
fprintf('Value at Risk (VaR) mensile a 5%%: %.2f%%\n', VaR_5_pct);

% Step 4: Grafico
bar(TT_port_monthly.Properties.RowTimes(2:end), monthlyLogRet * 100, 'FaceColor', [0.2 0.6 0.8]);
hold on;
yline(VaR_5 * 100, '--r', 'VaR 5%', 'LineWidth', 1.5);
xlabel('Date');
ylabel('Monthly Log-Return (%)');
title('Distribution of Monthly Log Returns with 5% VaR');
grid on;
xtickformat('yyyy');
hold off;

%% Boxplot of Monthly Log Returns with 5% VaR
figure;
boxchart(monthlyLogRet * 100, 'BoxFaceColor', [0.2 0.6 0.8], 'LineWidth', 1.2);
yline(VaR_5 * 100, '--r', '5% VaR', 'LabelHorizontalAlignment', 'left', 'LineWidth', 1.5);
title('Boxplot of Monthly Log Returns with 5% VaR');
ylabel('Monthly Log Return (%)');
grid on;

%% Portafogli 100% SPY e 100% AGG

% Calcolo del valore cumulato a partire dai log-return già disponibili
spyVal = [1; exp(cumsum(spyRet))];        % valore cumulato SPY
aggVal = [1; exp(cumsum(aggRet))];        % valore cumulato AGG

% Costruzione delle date complete
spyDates_full = [retDates(1); retDates];
aggDates_full = [retDates(1); retDates];

% Costruzione dei timetables
TT_spy = timetable(spyDates_full, log(spyVal));
TT_agg = timetable(aggDates_full, log(aggVal));

%% === SPY: Statistiche ===
spyLogRet = diff(log(spyVal));
meanSpy = mean(spyLogRet);
stdSpy = std(spyLogRet);
meanSpyAnn = meanSpy * 252;
stdSpyAnn  = stdSpy * sqrt(252);
sharpeSpy  = meanSpyAnn / stdSpyAnn;

% Max Drawdown
peakSPY = cummax(spyVal);
ddSPY = (spyVal - peakSPY) ./ peakSPY;
maxDD_SPY = min(ddSPY);

% VaR mensile SPY
TT_spy_monthly = retime(TT_spy, 'monthly', 'lastvalue');
monthlyLogRet_SPY = diff(TT_spy_monthly.Var1);
VaR_SPY = prctile(monthlyLogRet_SPY, 5);
VaR_SPY_pct = (exp(VaR_SPY) - 1) * 100;

%% === AGG: Statistiche ===
aggLogRet = diff(log(aggVal));
meanAgg = mean(aggLogRet);
stdAgg = std(aggLogRet);
meanAggAnn = meanAgg * 252;
stdAggAnn  = stdAgg * sqrt(252);
sharpeAgg  = meanAggAnn / stdAggAnn;

% Max Drawdown
peakAGG = cummax(aggVal);
ddAGG = (aggVal - peakAGG) ./ peakAGG;
maxDD_AGG = min(ddAGG);

% VaR mensile AGG
TT_agg_monthly = retime(TT_agg, 'monthly', 'lastvalue');
monthlyLogRet_AGG = diff(TT_agg_monthly.Var1);
VaR_AGG = prctile(monthlyLogRet_AGG, 5);
VaR_AGG_pct = (exp(VaR_AGG) - 1) * 100;

%% Stampa delle Statistiche
fprintf('\n==== Portafoglio 100%% Equity (SPY) ====\n');
fprintf('Rendimento medio annuo: %.2f%%\n', meanSpyAnn * 100);
fprintf('Volatilità annua:       %.2f%%\n', stdSpyAnn * 100);
fprintf('Sharpe Ratio:           %.3f\n', sharpeSpy);
fprintf('Max Drawdown:           %.2f%%\n', maxDD_SPY * 100);
fprintf('VaR mensile 5%%:         %.2f%%\n', VaR_SPY_pct);

fprintf('\n==== Portafoglio 100%% Bond (AGG) ====\n');
fprintf('Rendimento medio annuo: %.2f%%\n', meanAggAnn * 100);
fprintf('Volatilità annua:       %.2f%%\n', stdAggAnn * 100);
fprintf('Sharpe Ratio:           %.3f\n', sharpeAgg);
fprintf('Max Drawdown:           %.2f%%\n', maxDD_AGG * 100);
fprintf('VaR mensile 5%%:         %.2f%%\n', VaR_AGG_pct);
%% Plot: Cumulative Returns SPY vs AGG 
figure;
plot(spyDates_full, spyVal, 'LineWidth', 1.5); hold on;
plot(aggDates_full, aggVal, 'LineWidth', 1.5);
legend('100% Equity (SPY)', '100% Bonds (AGG)', 'Location', 'NorthWest');
title('Cumulative Returns – SPY vs AGG Portfolios');
xlabel('Date'); ylabel('Cumulative Value (Base = 1)');
grid on; xtickformat('yyyy');

%% Importazione dei fattori Fama-French
opts_FF = detectImportOptions('F-F_Research_Data_Factors_daily.csv', 'VariableNamingRule', 'preserve');
opts_FF.DataLines = [6, Inf];  % I dati iniziano dalla riga 6
FF3 = readtable('F-F_Research_Data_Factors_daily.csv', opts_FF);
head(FF3)

%% Importazione del fattore Momentum
opts_MOM = detectImportOptions('F-F_Momentum_Factor_daily.csv', 'VariableNamingRule', 'preserve');
opts_MOM.DataLines = [15, Inf];  % I dati iniziano dalla riga 6
FFMOM = readtable('F-F_Momentum_Factor_daily.csv', opts_MOM);
head(FFMOM)

%% 1) Rinomina la colonna Var1 in "Date"
FF3.Properties.VariableNames{'Var1'} = 'Date';
FF3.Properties.VariableNames{'Mkt-RF'} = 'Mkt_RF';
% 2) Converte la nuova colonna "Date" da formato numerico a datetime (yyyyMMdd)
FF3.Date = datetime(num2str(FF3.Date), 'InputFormat','yyyyMMdd');

% 3) Riordina le colonne: vogliamo che "Date" sia la prima
%    Adatta i nomi delle variabili (Mkt-RF, SMB, HML, RF, MOM) a quelli effettivi
FF3 = FF3(:, ["Date","Mkt_RF","SMB","HML","RF"]);

% 4) Trasforma la tabella in timetable, usando la colonna Date come indice temporale
FF3 = table2timetable(FF3, 'RowTimes','Date');

% Verifica il risultato
head(FF3)


%% 1) Rinomina la seconda colonna in "Mom"
FFMOM.Properties.VariableNames{2} = 'Mom';

% 2) Rimuovi il carattere ";" e converti in valori numerici
FFMOM.Mom = str2double(erase(FFMOM.Mom, ';'));

% 3) Rinomina la colonna Var1 in "Date" e convertila in datetime
FFMOM.Properties.VariableNames{'Var1'} = 'Date';
FFMOM.Date = datetime(num2str(FFMOM.Date), 'InputFormat','yyyyMMdd');

% 4) Riordina le colonne in modo che "Date" sia la prima
FFMOM = FFMOM(:, ["Date","Mom"]);

% 5) Converti la tabella in timetable
FFMOM = table2timetable(FFMOM, 'RowTimes','Date');

% Verifica il risultato
head(FFMOM)

%% Unione delle tabelle in base alla colonna Date
% Esegui un inner join per ottenere solo le date comuni
FFall = innerjoin(FF3, FFMOM, 'Keys', 'Date');
head(FFall)

%% Converti la tabella dei rendimenti del portafoglio in timetable
% La tabella PortfolioRebal ha le colonne 'Date' e 'Port_LogRet'
Port60_40_TT = table2timetable(PortfolioRebal, 'RowTimes', 'Date');

% Allineamento dei dati con i fattori
combinedTT = synchronize(Port60_40_TT, FFall, 'intersection');

% Calcolo del rendimento in eccesso del portafoglio
combinedTT.Port_Excess = combinedTT.Port_LogRet - combinedTT.RF/100;

%% Costruzione della matrice dei regressori e del vettore di risposta
% Convertiamo anche i fattori da percentuale a decimale
X = [ones(height(combinedTT), 1), combinedTT.Mkt_RF/100, combinedTT.SMB/100, combinedTT.HML/100, combinedTT.Mom/100];
Y = combinedTT.Port_Excess;

%% Esecuzione della regressione multifattoriale
[b, bint, r_resid, rint, stats] = regress(Y, X);

% Visualizza i coefficienti e le statistiche
fprintf('Alpha: %.5f\n', b(1));
fprintf('Beta_Mkt: %.5f\n', b(2));
fprintf('Beta_SMB: %.5f\n', b(3));
fprintf('Beta_HML: %.5f\n', b(4));
fprintf('Beta_MOM: %.5f\n', b(5));
fprintf('R^2: %.4f\n', stats(1));
fprintf('F-statistic: %.4f (p-value: %.4f)\n', stats(2), stats(3));

%% 1. Test di stabilità dei parametri - Chow Test
% Definizione della data di rottura (COVID)
break_date = datetime('2020-03-11');

% Creazione degli indici per i due periodi in combinedTT
% combinedTT è la timetable risultante dall'allineamento dei dati del portafoglio e dei fattori
idx1 = combinedTT.Date < break_date;
idx2 = combinedTT.Date >= break_date;

%% Regresione sul campione completo
[~,~,r_full] = regress(Y, X);
SSE_full = sum(r_full.^2);
n_full = length(Y);

% Regresione sul primo sotto-campione (pre-COVID)
[~,~,r1] = regress(Y(idx1), X(idx1,:));
SSE_1 = sum(r1.^2);
n1 = sum(idx1);

% Regresione sul secondo sotto-campione (post-COVID)
[~,~,r2] = regress(Y(idx2), X(idx2,:));
SSE_2 = sum(r2.^2);
n2 = sum(idx2);

k = size(X,2);  % numero di parametri stimati

%% Calcolo della statistica F del Chow Test
F_chow = ((SSE_full - (SSE_1 + SSE_2)) / k) / ((SSE_1 + SSE_2) / (n_full - 2*k));
p_chow = 1 - fcdf(F_chow, k, n_full - 2*k);

fprintf('\nChow Test (break date = %s):\n', char(break_date));
fprintf('F-statistic = %.4f, p-value = %.4f\n', F_chow, p_chow);

%% Rolling Regression per i coefficienti (finestra di 252 osservazioni)
window = 252;  % circa 1 anno
n = height(combinedTT);  % numero totale di osservazioni
k = size(X,2);  % numero di parametri (qui 5: intercetta, beta_Mkt, beta_SMB, beta_HML, beta_MOM)
rollingCoeffs = nan(n - window + 1, k);  % matrice per memorizzare i coefficienti

for i = 1:(n - window + 1)
    idx = i:(i+window-1);
    % Esegui la regressione sui dati della finestra corrente
    b_temp = regress(Y(idx), X(idx,:));
    rollingCoeffs(i,:) = b_temp';
end

% Crea un vettore di date corrispondenti al centro della finestra o all'ultimo giorno della finestra
rollingDates = combinedTT.Properties.RowTimes(window:end);

% Plot dei coefficienti rolling
% Plot of Rolling Regression Coefficients
figure;
plot(rollingDates, rollingCoeffs, 'LineWidth', 1.3);
legend('Alpha', 'Beta_{Mkt}', 'Beta_{SMB}', 'Beta_{HML}', 'Beta_{MOM}', 'Location', 'Best');
title('Rolling Regression Coefficients (1-Year Window)');
xlabel('Date');
ylabel('Coefficient Value');
grid on;
xtickformat('yyyy');

%% Test di Eteroschedasticità: Breusch-Pagan

% Calcola il quadrato dei residui
Y_resid2 = r_full.^2;

% Esegui la regressione dei residui al quadrato sulle variabili indipendenti originali (X)
% Nota: X include già l'intercetta come prima colonna.
[b_bp, ~, r_bp, ~, stats_bp] = regress(Y_resid2, X);

% Ottieni l'R^2 dalla regressione White (o, in questo caso, BP)
R2_bp = stats_bp(1);

% Calcola la statistica BP: BP_stat = n_full * R2
BP_stat = R2_bp * n_full;

% I gradi di libertà per il test sono pari al numero di regressori in X meno 1 (per l'intercetta)
df_bp = size(X,2) - 1;

% Calcola il p-value utilizzando la distribuzione chi-quadrato
p_bp = 1 - chi2cdf(BP_stat, df_bp);

% Stampa i risultati
fprintf('\nBreusch-Pagan Test:\n');
fprintf('BP Statistic = %.4f, p-value = %.4f\n', BP_stat, p_bp);

% Creazione di una tabella con le variabili indipendenti e dipendente
tbl = table(...
    combinedTT.Mkt_RF/100, ...
    combinedTT.SMB/100, ...
    combinedTT.HML/100, ...
    combinedTT.Mom/100, ...
    combinedTT.Port_Excess, ...
    'VariableNames', {'Mkt_RF', 'SMB', 'HML', 'Mom', 'Port_Excess'});

%% Stima del modello con OLS e robust standard errors (White-robust)
mdl_robust = fitlm(tbl, 'Port_Excess ~ Mkt_RF + SMB + HML + Mom', ...
                   'RobustOpts', 'on');

% Visualizza il riepilogo completo
disp(mdl_robust);

% Per stampare solo i coefficienti e i p-value:
disp(mdl_robust.Coefficients)

%% Hausmann-wu test
% Z1 = lagged Mkt_RF = combinedTT.Mkt_RF(t-1) strumento 
% Elimina la prima osservazione per costruire il lag
Mkt_RF_lag = [NaN; combinedTT.Mkt_RF(1:end-1)];
validIdx = ~isnan(Mkt_RF_lag);

% Variabili indipendenti originali
X_ols = [combinedTT.Mkt_RF/100, combinedTT.SMB/100, ...
         combinedTT.HML/100, combinedTT.Mom/100];
Y = combinedTT.Port_Excess;

% Riduci i dati alle osservazioni valide (dopo lag)
X_ols = X_ols(validIdx,:);
Y = Y(validIdx);
Z = [Mkt_RF_lag(validIdx)/100, X_ols(:,2:4)];  % Strumenti: Mkt_RF laggato + altre variabili
% FASE 1: Predizione della variabile sospetta (Mkt_RF) usando gli strumenti
Mkt_RF_hat = Z * ((Z' * Z) \ (Z' * X_ols(:,1)));  % Proiezione strumentale di Mkt_RF

% Ricostruzione X con Mkt_RF_hat al posto del Mkt_RF originale
X_iv = [Mkt_RF_hat, X_ols(:,2:4)];

% FASE 2: Stima IV
beta_iv = (X_iv' * X_iv) \ (X_iv' * Y);
beta_ols = (X_ols' * X_ols) \ (X_ols' * Y);
% Differenza tra le due stime
diff_beta = beta_iv - beta_ols;

% Varianze robuste (approssimate, versione semplice per confronto)
resid_iv = Y - X_iv * beta_iv;
resid_ols = Y - X_ols * beta_ols;
sigma_iv = (resid_iv' * resid_iv) / (length(Y) - size(X_iv,2));
sigma_ols = (resid_ols' * resid_ols) / (length(Y) - size(X_ols,2));

% Approssimazione della varianza della differenza (solo prima componente)
V_diff = sigma_iv * ((X_iv' * X_iv) \ eye(size(X_iv,2))) + sigma_ols * ((X_ols' * X_ols) \ eye(size(X_ols,2)));
% Statistica Hausman: H = (b_iv - b_ols)' * inv(V) * (b_iv - b_ols)
H_stat = diff_beta' * (inv(V_diff)) * diff_beta;
df = size(X_ols,2);  % gradi di libertà = numero regressori
p_val = 1 - chi2cdf(H_stat, df);

fprintf('\nHausman Test:\n');
fprintf('H = %.4f | p-value = %.4f\n', H_stat, p_val);

%% 2. Test per autocorrelazione

% a) Durbin–Watson Test
dw = sum(diff(r_full).^2) / sum(r_full.^2);
fprintf('\nDurbin-Watson statistic: %.4f\n', dw);

% b) Ljung–Box Test
% Usa la funzione lbqtest (default lag = 20)
[h_lbq, p_lbq] = lbqtest(r_full);
fprintf('Ljung-Box test: p-value = %.4f\n', p_lbq);

%% 3. Analisi della volatilità rolling
% Calcola la volatilità rolling (finestra di 252 giorni) sui log-return del portafoglio.
% portRet_rebal è il vettore dei log-return calcolati precedentemente (dimensione N-1)
window = 252;
rollingVol = movstd(portRet_rebal, window) * sqrt(252);  % annualizza la volatilità

% Per l'asse temporale, usiamo le date corrispondenti ai log-return (retDates(2:end))
% (eventualmente, si può usare un subset a partire da indice 'window' per avere una finestra "piena")
rollingDates = retDates(2:end);

% Rimuovi i NaN (i primi window-1 valori sono NaN)
validIdx = ~isnan(rollingVol);
rollingVol_valid = rollingVol(validIdx);
rollingDates_valid = rollingDates(validIdx);

% Se vuoi visualizzare la volatilità in percentuale, moltiplica per 100:
rollingVol_percent = 100 * rollingVol_valid;

figure;
plot(rollingDates, rollingVol, 'LineWidth', 1.2);
title('Annualized Rolling Volatility (1-Year Window)');
xlabel('Date');
ylabel('Volatility (%)');
grid on;
xtickformat('yyyy');
%% Statistiche rolling volatility
volMean = mean(rollingVol_percent);
volMax = max(rollingVol_percent);
volMin = min(rollingVol_percent);

fprintf('Media della volatilità rolling: %.2f%%\n', volMean);
fprintf('Volatilità rolling massima: %.2f%%\n', volMax);
fprintf('Volatilità rolling minima: %.2f%%\n', volMin);

%% CRYPTO
%% Download Crypto List: filter stablecoins and sort by market capitalization

% API key is intentionally not hard-coded for security reasons.
% Set your CryptoCompare API key as an environment variable named:
% CRYPTOCOMPARE_API_KEY
%
% Example:
% macOS/Linux terminal:
%   export CRYPTOCOMPARE_API_KEY="your_api_key_here"
%
% Windows PowerShell:
%   setx CRYPTOCOMPARE_API_KEY "your_api_key_here"

apiKey = getenv('CRYPTOCOMPARE_API_KEY');

if isempty(apiKey)
    error(['Missing CryptoCompare API key. ', ...
           'Set the CRYPTOCOMPARE_API_KEY environment variable before running the script.']);
end

limitDays = 2000;                    % Maximum number of historical daily observations
startDate = datetime(2019,1,1);      % Earliest date used for the crypto dataset

% Lista simboli (da file CSV già selezionata e validata)
cryptoSymbols = { ...
    'BTC','ETH','BNB','SOL','XRP','TON','DOGE','ADA','TRX','LEO','LINK','XLM','AVAX','LTC','DOT', ...
    'BCH','XMR','ETC','FIL','ATOM','HBAR','VET','ICP','CRO','NEAR','OP','AR','MKR','XTZ','QNT', ...
    'AAVE','EGLD','SAND','FLOW','THETA','RPL','KAS','CHZ','XDC','CSPR','ZEC','GRT','ENS','LDO', ...
    'KSM','BAT','ZRX','ENJ','ZEN','WAVES','QTUM','ANKR','ZIL','RSR','NEO','BEAM', ...
    'DASH','GLM','DCR','SC','DGB','RVN','TEL','BDX','XEM','ONT','XNO','BAND','LRC','MASK','SUSHI', ...
    'COTI','HIVE','KDA','GT','ALGO','STX','FET'};
% Preallocazione celle per i dati
dailyPriceData = cell(length(cryptoSymbols), 1);
dailyCapData   = cell(length(cryptoSymbols), 1);

%% Scarica dati giornalieri per ciascuna crypto
for i = 1:length(cryptoSymbols)
    symbol = cryptoSymbols{i};

    % URL API histoday
    urlHist = sprintf('https://min-api.cryptocompare.com/data/v2/histoday?fsym=%s&tsym=USD&limit=%d&api_key=%s', ...
                      symbol, limitDays, apiKey);
    try
        dataHist = webread(urlHist);
        if isfield(dataHist, 'Data') && isfield(dataHist.Data, 'Data')
            dataArray = dataHist.Data.Data;

            % Estrai dati validi
            dates = datetime([dataArray.time], 'ConvertFrom', 'posixtime');
            closePrices = [dataArray.close]';
            marketCaps = [dataArray.volumeto]'; % proxy market cap

            % Filtro date
            idx = dates >= startDate;
            TT_close = timetable(dates(idx)', closePrices(idx), 'VariableNames', {symbol});
            TT_cap   = timetable(dates(idx)', marketCaps(idx), 'VariableNames', {symbol});

            dailyPriceData{i} = TT_close;
            dailyCapData{i}   = TT_cap;

            fprintf('Dati scaricati per %s (%d giorni)\n', symbol, sum(idx));
        else
            fprintf('Dati mancanti per %s\n', symbol);
        end
    catch ME
        fprintf('Errore con %s: %s\n', symbol, ME.message);
    end
end

%% Calcolo dei rendimenti giornalieri (log-return) da timetable di prezzi 
% Preallocazione per i rendimenti giornalieri
dailyReturns = cell(length(dailyPriceData), 1);

for i = 1:length(dailyPriceData)
    TT = dailyPriceData{i};
    if isempty(TT)
        continue
    end
    % Estrai il nome della crypto dalla timetable
    symbol = TT.Properties.VariableNames{1};
    
    % Estrai i prezzi di chiusura dalla colonna della timetable
    prices = TT{:,1};
    
    % Calcola i log-return: diff(log(prezzo))
    logReturns = diff(log(prices));
    
    % Le date dei log-return sono le date a partire dal secondo giorno
    returnDates = TT.Time(2:end);
    
    % Crea una timetable per i rendimenti giornalieri
    TT_returns = timetable(returnDates, logReturns, 'VariableNames', {symbol});
    
    % Salva il risultato nella cell array dailyReturns
    dailyReturns{i} = TT_returns;
    
    fprintf('✓ Calcolati rendimenti per %s (%d giorni)\n', symbol, length(returnDates));
end

%% Pulizia dei NaN e Inf nei dailyReturns: sostituisci NaN e Inf con 0
for i = 1:length(dailyReturns)
    TT = dailyReturns{i};
    if isempty(TT), continue; end
    symbol = TT.Properties.VariableNames{1};
    data = TT{:,1};
    data(isnan(data) | isinf(data)) = 0;
    TT{:,1} = data;
    dailyReturns{i} = TT;
    fprintf('Pulizia completata per %s\n', symbol);
end

%%  Calcolo dei segnali RA-MOM su 1, 2 e 4 settimane dai log-return giornalieri
% Input: dailyReturns, cell array di timetables contenenti i log-return giornalieri
% Output: RA_MOM_signals, cell array (nCrypto x nWindows) di timetables dei segnali RA-MOM

windowSizes = [7, 14, 28];  % 7, 14 e 28 giorni corrispondono a 1, 2 e 4 settimane
nCrypto = length(dailyReturns);
nWindows = length(windowSizes);
RA_MOM_signals = cell(nCrypto, nWindows);

for i = 1:nCrypto
    TT_ret = dailyReturns{i};
    if isempty(TT_ret)
        continue;
    end
    % Estrai il nome della crypto dalla timetable
    symbol = TT_ret.Properties.VariableNames{1};
    % Usa le RowTimes della timetable (assumiamo che siano giornaliere)
    datesRet = TT_ret.Properties.RowTimes;
    returns  = TT_ret.(symbol);
    
    for wIndex = 1:nWindows
        w = windowSizes(wIndex);
        % Calcola il rendimento cumulato e la volatilità sulla finestra w
        cumReturn = movsum(returns, w, 'Endpoints', 'discard');
        vol       = movstd(returns, w, 'Endpoints', 'discard');
        % Evita divisioni per zero
        RA_MOM = zeros(size(cumReturn));
        idxNonZero = (vol ~= 0);
        RA_MOM(idxNonZero) = cumReturn(idxNonZero) ./ vol(idxNonZero);
        % Le date associate sono quelle a partire dal giorno w
        signalDates = datesRet(w:end);
        % Crea la timetable del segnale
        TT_RA_MOM = timetable(signalDates, RA_MOM, 'VariableNames', {symbol});
        RA_MOM_signals{i, wIndex} = TT_RA_MOM;
    end
    
    fprintf('✓ RA-MOM calcolato per %s (finestre 1,2,4 settimane)\n', symbol);
end

%% Conversione dei dailyReturns in weeklyReturns
% Sommiamo i log-return giornalieri per ottenere il log-return settimanale
weeklyReturns = cell(size(dailyReturns));
for i = 1:length(dailyReturns)
    TT_daily = dailyReturns{i};
    if isempty(TT_daily)
        continue;
    end
    TT_weekly = retime(TT_daily, 'weekly', @sum);
    weeklyReturns{i} = TT_weekly;
    fprintf('✓ Weekly returns computed for %s (%d weeks)\n', TT_daily.Properties.VariableNames{1}, height(TT_weekly));
end

%% Retima i segnali RA-MOM (finestra 1 settimana) a frequenza settimanale
% Usiamo la colonna 1 di RA_MOM_signals (finestra di 1 settimana) e retimiamo a 'weekly'
RA_MOM_signals_weekly = cell(size(RA_MOM_signals,1), 1);
for i = 1:nCrypto
    TT_RA = RA_MOM_signals{i, 1};  % segnali per finestra di 1 settimana
    if isempty(TT_RA)
        continue;
    end
    % Retime: scegli l'ultimo valore della settimana
    TT_RA_weekly = retime(TT_RA, 'weekly', 'lastvalue');
    RA_MOM_signals_weekly{i} = TT_RA_weekly;
    fprintf('✓ RA-MOM settimanale retimato per %s\n', TT_RA.Properties.VariableNames{1});
end


%% Calcolo del segnale Size settimanale
% Input: dailyCapData, cell array di timetables contenenti i dati giornalieri di market cap 
% (utilizziamo "volumeto" come proxy per la market cap) per ciascuna crypto.
%
% Output: Size_signals, cell array di timetables con il segnale Size settimanale per ciascuna crypto.

epsilon = 1e-8;  % piccolo valore per stabilizzare il log
nCrypto = length(dailyCapData);
Size_signals = cell(nCrypto, 1);

for i = 1:nCrypto
    TT_cap_daily = dailyCapData{i};
    if isempty(TT_cap_daily)
        continue;
    end
    % Con retime, calcoliamo la media settimanale dei dati di market cap
    TT_cap_weekly = retime(TT_cap_daily, 'weekly', @mean);
    
    % Supponiamo che la colonna si chiami come il simbolo della crypto
    symbol = TT_cap_weekly.Properties.VariableNames{1};
    weeklyCap = TT_cap_weekly{:,1};
    
    % Calcola il segnale Size: applica -log per ottenere un segnale inverso (small cap -> punteggio alto)
    sizeScore = -log(weeklyCap + epsilon);
    
    % Crea una timetable per il segnale Size
    TT_size = timetable(TT_cap_weekly.Properties.RowTimes, sizeScore, 'VariableNames', {symbol});
    Size_signals{i} = TT_size;
    
    fprintf('✓ Size signal calcolato per %s (%d settimane)\n', symbol, height(TT_size));
end

%% Combinazione dei 4 segnali: Size, RA-MOM1, RA-MOM2, RA-MOM4
nCrypto = length(Size_signals);
nRebal = height(Size_signals{1});  % assumiamo stessa timeline
commonDates = Size_signals{1}.Properties.RowTimes;

% Preallocazione delle matrici per i segnali allineati
Z_Size   = nan(nRebal, nCrypto);
Z_RMOM1  = nan(nRebal, nCrypto);
Z_RMOM2  = nan(nRebal, nCrypto);
Z_RMOM4  = nan(nRebal, nCrypto);

for i = 1:nCrypto
    % SIZE
    if ~isempty(Size_signals{i})
        TT_size = retime(Size_signals{i}, commonDates, 'previous');
        Z_Size(:,i) = TT_size{:,1};
    end
    
    % RA-MOM 1 settimana
    if ~isempty(RA_MOM_signals{i,1})
        TT_rmom1 = retime(RA_MOM_signals{i,1}, commonDates, 'previous');
        Z_RMOM1(:,i) = TT_rmom1{:,1};
    end
    
    % RA-MOM 2 settimane
    if ~isempty(RA_MOM_signals{i,2})
        TT_rmom2 = retime(RA_MOM_signals{i,2}, commonDates, 'previous');
        Z_RMOM2(:,i) = TT_rmom2{:,1};
    end

    % RA-MOM 4 settimane
    if ~isempty(RA_MOM_signals{i,3})
        TT_rmom4 = retime(RA_MOM_signals{i,3}, commonDates, 'previous');
        Z_RMOM4(:,i) = TT_rmom4{:,1};
    end
end

% Standardizzazione (z-score row-wise)
zSize = (Z_Size   - mean(Z_Size,   2, 'omitnan')) ./ std(Z_Size,   0, 2, 'omitnan');
z1    = (Z_RMOM1  - mean(Z_RMOM1,  2, 'omitnan')) ./ std(Z_RMOM1,  0, 2, 'omitnan');
z2    = (Z_RMOM2  - mean(Z_RMOM2,  2, 'omitnan')) ./ std(Z_RMOM2,  0, 2, 'omitnan');
z4    = (Z_RMOM4  - mean(Z_RMOM4,  2, 'omitnan')) ./ std(Z_RMOM4,  0, 2, 'omitnan');

% Calcolo del Mispricing Score (media semplice dei 4 segnali standardizzati)
MispricingScore = (zSize + z1 + z2 + z4) / 4;

% Ricostruisci la timetable laggata
MispricingTT = array2timetable(MispricingScore, ...
    'RowTimes', commonDates, ...
    'VariableNames', cryptoSymbols);

fprintf('✓ Mispricing score (media di 4 segnali) calcolato per %d settimane e %d crypto.\n', nRebal, nCrypto);

%% Costruzione del portafoglio long-short basato su MispricingTT con costi di transazione
% Input: 
%   - MispricingTT: timetable con segnali di mispricing standardizzati (287 x 91)
%   - weeklyReturns: cell array (nCrypto x 1) con i rendimenti settimanali per ciascuna crypto

% Setup
commonDates = MispricingTT.Properties.RowTimes;
nRebal = height(MispricingTT);
nCrypto = width(MispricingTT);

% Parametro costo fisso di transazione (es. 0.1% = 10 bps)
costo_tx = 0.001;

% Prealloca vettori
longReturns = nan(nRebal, 1);
shortReturns = nan(nRebal, 1);
turnoverVec = nan(nRebal, 1);
LS_returns = nan(nRebal, 1);

% Crea matrice dei rendimenti settimanali
weeklyReturnMatrix = nan(nRebal, nCrypto);
for i = 1:nCrypto
    if isempty(weeklyReturns{i})
        continue;
    end
    TT_ret = retime(weeklyReturns{i}, commonDates, 'previous');
    weeklyReturnMatrix(:,i) = TT_ret{:,1};
end

% Prealloca matrice pesi per turnover
prevWeights = zeros(1, nCrypto);  % inizializzazione pesi t−1

% Loop sul backtest
for t = 1:nRebal
    scores_t = MispricingTT{t, :};
    returns_t = weeklyReturnMatrix(t, :);
    
    % Filtra validi
    validIdx = ~isnan(scores_t) & ~isnan(returns_t);
    scores_valid = scores_t(validIdx);
    returns_valid = returns_t(validIdx);
    
    % Ranking
    [~, sortedIdx] = sort(scores_valid, 'descend');
    nValid = sum(validIdx);
    top30 = round(0.3 * nValid);
    bottom30 = round(0.3 * nValid);
    
    % Crea nuovi pesi: +1/N per long, -1/N per short
    weights = zeros(1, nCrypto);
    validCryptoIdx = find(validIdx);  % posizione globale delle valid crypto
    
    % Assegna pesi
    weights(validCryptoIdx(sortedIdx(1:top30))) = 1 / top30;
    weights(validCryptoIdx(sortedIdx(end-bottom30+1:end))) = -1 / bottom30;

    % Rendimento netto
    grossReturn = sum(weights .* returns_t, 'omitnan');
    turnover = sum(abs(weights - prevWeights), 'omitnan');
    netReturn = grossReturn - costo_tx * turnover;

    % Salva
    longReturns(t) = mean(returns_valid(sortedIdx(1:top30)));
    shortReturns(t) = mean(returns_valid(sortedIdx(end-bottom30+1:end)));
    LS_returns(t) = netReturn;
    turnoverVec(t) = turnover;

    % Aggiorna pesi precedenti
    prevWeights = weights;
end

% Timetable finale
Portfolio_Mispricing = timetable(commonDates, LS_returns, ...
    'VariableNames', {'LongShort_Mispricing_Ret'});

fprintf('✓ Portafoglio long-short basato su Mispricing costruito con costi (%.1f bps) per %d periodi.\n', costo_tx * 10000, nRebal);


%% Analisi rigorosa delle performance del portafoglio Mispricing

% Estrai rendimenti validi (escludi i NaN iniziali)
ret_misp = Portfolio_Mispricing.LongShort_Mispricing_Ret;
dates_misp = Portfolio_Mispricing.commonDates;
validIdx = ~isnan(ret_misp);
ret_misp_valid = ret_misp(validIdx);
dates_misp_valid = dates_misp(validIdx);

% Statistiche settimanali
meanRetWeek = mean(ret_misp_valid);
stdRetWeek  = std(ret_misp_valid);

% Annualizzazione corretta (52 settimane)
meanRetAnn = meanRetWeek * 52;
stdRetAnn  = stdRetWeek * sqrt(52);
sharpeRatio = meanRetAnn / stdRetAnn;

% Sortino Ratio annualizzato (calcolato da rendimenti negativi settimanali)
downsideWeekly = ret_misp_valid(ret_misp_valid < 0);
sortinoRatio = meanRetAnn / (std(downsideWeekly) * sqrt(52));

% Equity curve (base = 1)
cumulativePerf = cumprod(1 + ret_misp_valid);
portVal = cumulativePerf;
retDates = dates_misp_valid;

% Calcolo del Drawdown
peak_misp = cummax(portVal);
drawdown_misp = (portVal - peak_misp) ./ peak_misp;
maxDrawdown_misp = min(drawdown_misp);

% Stampa statistiche rigorose (annualizzate direttamente da dati settimanali)
fprintf('\nPortafoglio Mispricing - Performance settimanale annualizzata\n');
fprintf('Media rendimento settimanale:            %.6f\n', meanRetWeek);
fprintf('Deviazione standard settimanale:         %.6f\n', stdRetWeek);
fprintf('Media rendimento annualizzata:           %.4f\n', meanRetAnn);
fprintf('Volatilità annualizzata:                 %.4f\n', stdRetAnn);
fprintf('Sharpe Ratio annualizzato:               %.3f\n', sharpeRatio);
fprintf('Sortino Ratio annualizzato:              %.3f\n', sortinoRatio);
fprintf('Max Drawdown - Portafoglio Mispricing:   %.2f%%\n', maxDrawdown_misp * 100);

%% Cumulative Performance – Mispricing Portfolio
figure;
plot(retDates, portVal, 'LineWidth', 1.4);
title('Cumulative Performance – Mispricing Portfolio');
xlabel('Date');
ylabel('Cumulative Value (Base = 1)');
grid on;
xtickformat('yyyy');

%% Drawdown – Mispricing Portfolio
figure;
area(retDates, drawdown_misp * 100, 'FaceColor', [0.85 0.33 0.10]);
title('Drawdown – Mispricing Portfolio');
xlabel('Date');
ylabel('Drawdown (%)');
grid on;
xtickformat('yyyy');

%% Rolling Sharpe Ratio – Mispricing Portfolio (1-Year Window)
window = 52;
ret_weekly = ret_misp_valid;
rollingSharpe = movmean(ret_weekly, window) ./ movstd(ret_weekly, window) * sqrt(52);
rollingDates = retDates(window:end);

figure;
plot(rollingDates, rollingSharpe(window:end), 'LineWidth', 1.4);
title('Rolling Sharpe Ratio – Mispricing Portfolio (1-Year Window)');
xlabel('Date');
ylabel('Sharpe Ratio');
grid on;
xtickformat('yyyy');

%% Simulazione Out-of-Sample (OOS)
% STEP 1: Definisci la data di split
splitDate = datetime('2022-12-31');

%% STEP 2: Filtra dati in-sample per costruire la strategia
% MispricingTT contiene gli score standardizzati
% weeklyReturnMatrix contiene i rendimenti settimanali (crypto)

idxInSample = MispricingTT.Time <= splitDate;
Mispricing_InSample = MispricingTT(idxInSample, :);
weeklyReturns_InSample = weeklyReturnMatrix(idxInSample, :);

% Allinea date
commonDates_in = Mispricing_InSample.Properties.RowTimes;
nRebal_in = height(Mispricing_InSample);
% nCrypto = width(Mispricing_InSample);  % per uso successivo
%% STEP 3: Costruzione del portafoglio long-short in-sample
longReturns_in = nan(nRebal_in, 1);
shortReturns_in = nan(nRebal_in, 1);

for t = 1:nRebal_in
    scores = Mispricing_InSample{t, :};
    rets = weeklyReturns_InSample(t, :);
    
    valid = ~isnan(scores) & ~isnan(rets);
    [~, idxSort] = sort(scores(valid), 'descend');
    
    top30 = round(0.3 * sum(valid));
    bottom30 = round(0.3 * sum(valid));
    
    sortedReturns = rets(valid);
    
    % Controlla che ci siano abbastanza osservazioni per il calcolo
    if length(sortedReturns) >= max(top30, bottom30)
        longReturns_in(t) = mean(sortedReturns(idxSort(1:top30)));
        shortReturns_in(t) = mean(sortedReturns(idxSort(end-bottom30+1:end)));
    end
end

ret_mispricing_in = longReturns_in - shortReturns_in;

% Filtra valori validi (senza NaN)
ret_mispricing_in_valid = ret_mispricing_in(~isnan(ret_mispricing_in));

% Stima media/volatilità annualizzata con 'omitnan' per sicurezza
mu_in     = mean(ret_mispricing_in_valid);
sigma_in = std(ret_mispricing_in_valid);
sharpe_in = mu_in / sigma_in;

mu_in_ann     = mu_in * 52;
sigma_in_ann  = sigma_in * sqrt(52);
sharpe_in_ann = sharpe_in;

fprintf('\n Strategia costruita In-Sample (fino a %s):\n', string(splitDate));
fprintf('Mean return: %.4f | Vol: %.4f | Sharpe: %.3f\n', mu_in_ann, sigma_in_ann, sharpe_in_ann);


%% STEP 4: Test Out-of-Sample
% Filtra i dati post split
idxOOS = MispricingTT.Time > splitDate;
Mispricing_OOS = MispricingTT(idxOOS, :);
weeklyReturns_OOS = weeklyReturnMatrix(idxOOS, :);
commonDates_oos = Mispricing_OOS.Time;
nRebal_oos = height(Mispricing_OOS);

longReturns_oos = nan(nRebal_oos, 1);
shortReturns_oos = nan(nRebal_oos, 1);

for t = 1:nRebal_oos
    scores = Mispricing_OOS{t, :};
    rets = weeklyReturns_OOS(t, :);
    
    valid = ~isnan(scores) & ~isnan(rets);
    [~, idxSort] = sort(scores(valid), 'descend');
    
    top30 = round(0.3 * sum(valid));
    bottom30 = round(0.3 * sum(valid));
    
    sortedReturns = rets(valid);
    longReturns_oos(t) = mean(sortedReturns(idxSort(1:top30)));
    shortReturns_oos(t) = mean(sortedReturns(idxSort(end-bottom30+1:end)));
end

ret_mispricing_oos = longReturns_oos - shortReturns_oos;

% Performance OOS
mu_oos = mean(ret_mispricing_oos) * 52;
sigma_oos = std(ret_mispricing_oos) * sqrt(52);
sharpe_oos = mu_oos / sigma_oos;

fprintf('\n Performance Out-of-Sample (dal %s):\n', string(splitDate + caldays(1)));
fprintf('Mean return: %.4f | Vol: %.4f | Sharpe: %.3f\n', mu_oos, sigma_oos, sharpe_oos);

%% STEP 5: Out-of-Sample Cumulative Performance – Mispricing Strategy
cumul_perf_oos = cumprod(1 + ret_mispricing_oos, 'omitnan');
figure;
plot(commonDates_oos, cumul_perf_oos, 'LineWidth', 1.4);
title('Out-of-Sample Cumulative Performance – Mispricing Strategy');
xlabel('Date');
ylabel('Equity Curve');
grid on;
xtickformat('yyyy');


%% Allineamento Settimanale dei Portafogli 60/40 e Crypto per Analisi Combinata 
% Step 1: Retime il portafoglio 60/40 da giornaliero a settimanale
Port60_40_TT = table2timetable(PortfolioRebal, 'RowTimes', 'Date');
Port60_40_TT_weekly = retime(Port60_40_TT, 'weekly', @sum);

% Step 2: Allinea il formato delle date della crypto (se non l'hai già fatto)
Crypto_TT = Portfolio_Mispricing;
Crypto_TT.Properties.RowTimes = dateshift(Crypto_TT.Properties.RowTimes, 'start', 'day');

% Step 3: Allinea i due portafogli su date settimanali comuni
CombinedTT_crypto = synchronize(Port60_40_TT_weekly, Crypto_TT, 'intersection');

% Step 4: Controllo
fprintf("CombinedTT ha %d osservazioni settimanali.\n", height(CombinedTT_crypto));

%% 1. Calcolo dei rendimenti logaritmici giornalieri da prezzi SPY e AGG
spyPrices = T.SPY_Close;
aggPrices = T.AGG_Close;

spyRet = diff(log(spyPrices));
aggRet = diff(log(aggPrices));
retDates = T.Date(2:end);  % Allineamento alle date corrette

% 2. Crea la timetable giornaliera
TT_daily = timetable(retDates, spyRet, aggRet, 'VariableNames', {'SPY', 'AGG'});

% 3. Aggregazione settimanale dei rendimenti
TT_weekly = retime(TT_daily, 'weekly', 'sum');  % somma dei log-return = log-return settimanale

% 4. Estrai i rendimenti settimanali e la strategia crypto
rSPY_weekly = TT_weekly.SPY;
rAGG_weekly = TT_weekly.AGG;
rCrypto     = CombinedTT_crypto.LongShort_Mispricing_Ret;

% 5. Allineamento: taglia tutte le serie alla stessa lunghezza
minLen = min([length(rSPY_weekly), length(rAGG_weekly), length(rCrypto)]);
rSPY_weekly = rSPY_weekly(end - minLen + 1:end);
rAGG_weekly = rAGG_weekly(end - minLen + 1:end);
rCrypto     = rCrypto(end     - minLen + 1:end);
alignedDates = CombinedTT_crypto.Date(end - minLen + 1:end);

%% 6. Costruzione dei portafogli con diversi pesi in Crypto (1%–20%)
weights = 0.01:0.01:0.20;
nW = length(weights);
returnsMatrix = nan(minLen, nW);  % matrice risultati

for j = 1:nW
    wCrypto = weights(j);
    wRemaining = 1 - wCrypto;

    % 60/40 sul capitale rimanente
    wSPY = 0.60 * wRemaining;
    wAGG = 0.40 * wRemaining;

    % Ritorno settimanale del portafoglio
    returnsMatrix(:, j) = wSPY * rSPY_weekly + wAGG * rAGG_weekly + wCrypto * rCrypto;
end

% 7. Crea la timetable dei portafogli
colNames = compose("Ret_%dpc_Crypto", round(weights * 100));  % es. Ret_1pc_Crypto
Portfolios_CryptoMix = array2timetable(returnsMatrix, ...
    'RowTimes', alignedDates, ...
    'VariableNames', colNames);

% 8. Mostra anteprima
disp(head(Portfolios_CryptoMix));


%% Performance Statistiche sui Portafogli Misti con Cripto

annualFactor = 52;  % Dati settimanali
weights = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.2];
nW = length(weights);
dates = Portfolios_CryptoMix.Properties.RowTimes;

% Prealloca matrici per le statistiche
meanAnn   = zeros(nW,1);
volAnn    = zeros(nW,1);
sharpe    = zeros(nW,1);
sortino   = zeros(nW,1);
maxDD     = zeros(nW,1);

figure; hold on
for j = 1:nW
    ret = Portfolios_CryptoMix{:,j};
    
    % Base statistics
    meanW  = mean(ret, 'omitnan');
    stdW   = std(ret, 'omitnan');
    meanAnn(j) = meanW * annualFactor;
    volAnn(j)  = stdW * sqrt(annualFactor);
    sharpe(j)  = meanAnn(j) / volAnn(j);
    
    % Sortino Ratio
    downside = ret(ret < 0);
    if isempty(downside)
        sortino(j) = NaN;
    else
        stdDown = std(downside, 'omitnan') * sqrt(annualFactor);
        sortino(j) = meanAnn(j) / stdDown;
    end

    % Drawdown
    cumRet = cumprod(1 + ret, 'omitnan');
    peak = cummax(cumRet);
    drawdown = (cumRet - peak) ./ peak;
    maxDD(j) = min(drawdown);
    
    % Plot cumulative performance
    plot(dates, cumRet, 'DisplayName', sprintf('%.0f%% Crypto', weights(j)*100));
end
hold off
title('Cumulative Performance – Crypto-Mixed Portfolios');
xlabel('Date'); ylabel('Cumulative Growth');
grid on;
legend('Location','northwest');
xtickformat('yyyy');

%% Plot drawdown
% DRAWNOWN CURVES – Selected Portfolios (0%, 4%, 10%, 20%)
selectedIdx = [0, 4, 10, 20];  % corrisponde a 0% (pure 60/40), 4%, 10%, 20%
selectedLabels = {'60/40', '4% Crypto', '10% Crypto', '20% Crypto'};

figure; hold on

for i = 1:length(selectedIdx)
    if selectedIdx(i) == 0
        % 60/40 puro
        ret = CombinedTT_crypto.Port_LogRet;
    else
        j = selectedIdx(i);
        ret = Portfolios_CryptoMix{:, j};
    end
    
    cumRet = cumprod(1 + ret, 'omitnan');
    peak = cummax(cumRet);
    drawdown = (cumRet - peak) ./ peak;

    plot(dates, drawdown, 'LineWidth', 1.5, 'DisplayName', selectedLabels{i});
end

title('Drawdown Comparison – 60/40 and Crypto-Enhanced Portfolios');
xlabel('Date'); ylabel('Drawdown (%)');
legend('Location','southwest');
grid on;
xtickformat('yyyy');
ylim([-0.25 0]);  % più leggibile


%% Tabella riepilogativa
T_perf = table(weights'*100, meanAnn*100, volAnn*100, sharpe, sortino, maxDD*100, ...
    'VariableNames', {'Crypto_%','AnnReturn_%','AnnVol_%','Sharpe','Sortino','MaxDrawdown_%'});
disp(T_perf);

window = 52;  % 1 year
figure; hold on
for j = 1:nW
    r = Portfolios_CryptoMix{:,j};
    rs = movmean(r, window, 'omitnan') ./ movstd(r, window, 'omitnan') * sqrt(annualFactor);
    plot(dates(window:end), rs(window:end), 'DisplayName', sprintf('%.0f%% Crypto', weights(j)*100));
end
hold off
title('Rolling Sharpe Ratio – Crypto-Mixed Portfolios (1-Year Window)');
xlabel('Date'); ylabel('Sharpe Ratio');
grid on;
legend('Location','southwest');
xtickformat('yyyy');


%% Importa i fattori Fama-French + MOM già come timetable in FFall settimanale
% Converti i rendimenti dei portafogli crypto in timetable se non lo sono
PortCryptoMix_TT = Portfolios_CryptoMix;
% Converti FFall (giornaliero) in settimanale sommando i rendimenti
FFall_weekly = retime(FFall, 'weekly', @sum);

for j = 1:width(PortCryptoMix_TT)
    portName = PortCryptoMix_TT.Properties.VariableNames{j};
    tempTT = synchronize(PortCryptoMix_TT(:, j), FFall_weekly, 'intersection');
    tempTT.Excess = tempTT.(portName) - tempTT.RF/100;

    % Regressione multifattoriale
    X = [ones(height(tempTT),1), tempTT.Mkt_RF/100, tempTT.SMB/100, tempTT.HML/100, tempTT.Mom/100];
    Y = tempTT.Excess;
     % Regressione multifattoriale con p-value
    [b, bint, r, rint, stats] = regress(Y, X);
    
    % Calcolo stima std error e p-value
    yhat = X * b;
    residuals = Y - yhat;
    sigma2 = sum(residuals.^2) / (length(Y) - size(X,2));
    covB = sigma2 * ((X' * X) \ eye(size(X,2)));

    se = sqrt(diag(covB));
    tstat = b ./ se;
    pval = 2 * (1 - tcdf(abs(tstat), length(Y) - size(X,2)));

       % Output
    fprintf('\nRegressione %s\n', portName);
    fprintf('Alpha: %.5f (p=%.4f)\n', b(1), pval(1));
    fprintf('Beta Mkt: %.5f (p=%.4f)\n', b(2), pval(2));
    fprintf('SMB: %.5f (p=%.4f) | HML: %.5f (p=%.4f) | MOM: %.5f (p=%.4f)\n', ...
            b(3), pval(3), b(4), pval(4), b(5), pval(5));
    fprintf('R-squared: %.4f\n', stats(1));

end

%% GARCH(1,1) Estimation and Conditional Volatility Analysis for Crypto-Mixed Portfolios
% Initialize vectors for the results table
nPorts = width(Portfolios_CryptoMix);
portNames = Portfolios_CryptoMix.Properties.VariableNames;

convergenceStatus = strings(nPorts,1);
constVec = nan(nPorts,1);
garchVec = nan(nPorts,1);
archVec  = nan(nPorts,1);
logLVec = nan(nPorts,1);
stderr_ConstVec = nan(nPorts,1);

for j = 1:nPorts
    portName = portNames{j};
    ret = Portfolios_CryptoMix.(portName);
    ret = ret(~isnan(ret));  % Remove NaN values
    
    fprintf('\nAnalysis for %s\n', portName);
    
    model = garch(1,1);
    
    try
        [EstModel, EstParamCov, logL, info] = estimate(model, ret, 'Display', 'off');
        
        % Save estimated parameters
        constVec(j) = EstModel.Constant;
        garchVec(j) = EstModel.GARCH{1};
        archVec(j)  = EstModel.ARCH{1};
        logLVec(j)  = logL;
        stderr_ConstVec(j) = sqrt(EstParamCov(1,1));
        
        % Check convergence
        if isfield(info, 'Converged') && info.Converged
            convergenceStatus(j) = "Convergent";
            disp('Model is convergent.');
        else
            convergenceStatus(j) = "Not Convergent";
            disp('Model is not convergent.');
        end
        
        % Estimate conditional volatility
        vHat = infer(EstModel, ret);
        sigmaHat = sqrt(vHat);
        
        % Dates for plotting (using valid dates for current portafoglio)
        dates = Portfolios_CryptoMix.Properties.RowTimes(~isnan(Portfolios_CryptoMix.(portName)));
        
        % Plot conditional volatility
        figure;
        plot(dates, sigmaHat, 'LineWidth', 1.3);
        title(sprintf('Conditional Volatility - %s (GARCH)', portName), 'Interpreter', 'none');
        xlabel('Date'); 
        ylabel('Conditional Volatility');
        grid on;
        xtickformat('yyyy');
        
    catch ME
    convergenceStatus(j) = "Error";
    disp(['Error in estimating model for ' portName ': ' ME.message]);
    end
end

% Create final results table with plain text headers
GARCH_Results = table(portNames', convergenceStatus, constVec, garchVec, archVec, logLVec, stderr_ConstVec, ...
    'VariableNames', {'Portfolio', 'Convergence', 'Constant', 'GARCH_1', 'ARCH_1', 'LogLikelihood', 'StdErr_Constant'});

disp('GARCH(1,1) Results Summary:');
disp(GARCH_Results);

%%
% Subplot GARCH conditional volatility for selected portfolios
selectedIdx = [4, 10, 20];  % 4% - 10% - 20% crypto
figure;

for k = 1:length(selectedIdx)
    j = selectedIdx(k);
    portName = portNames{j};
    ret = Portfolios_CryptoMix.(portName);
    ret = ret(~isnan(ret));

    model = garch(1,1);
    
    try
        EstModel = estimate(model, ret, 'Display', 'off');
        sigmaHat = sqrt(infer(EstModel, ret));
        datesPlot = Portfolios_CryptoMix.Properties.RowTimes(~isnan(Portfolios_CryptoMix.(portName)));

        subplot(3,1,k);
        plot(datesPlot, sigmaHat, 'LineWidth', 1.2);
        title(sprintf('Conditional Volatility – %s', portName), 'Interpreter', 'none');
        ylabel('Volatility'); grid on;
        xtickformat('yyyy');
    catch
        subplot(3,1,k);
        text(0.5, 0.5, sprintf('Estimation failed for %s', portName), ...
            'HorizontalAlignment', 'center', 'FontSize', 10);
        axis off;
    end
end

xlabel('Date');
sgtitle('Conditional Volatility – Selected Crypto-Mixed Portfolios (GARCH)');

%% VaR – Boxplot per 3 Portafogli Selezionati (4%, 10%, 20%)

% Portafogli selezionati
selectedIdx = [4, 10, 20];  % 4%, 10%, 20%
portNames = Portfolios_CryptoMix.Properties.VariableNames;

% Ritorni mensili
monthlyTT = retime(Portfolios_CryptoMix(:, selectedIdx), 'monthly', @sum);
datesMonthly = monthlyTT.Properties.RowTimes;

% Crea figura
figure;
t1 = tiledlayout(1,3, 'Padding','compact', 'TileSpacing','compact');
sgtitle('Monthly Return Distributions with 5% VaR Threshold');

for i = 1:3
    nexttile;

    % Estrae i ritorni mensili
    returns = monthlyTT{:,i};
    returns = returns(~isnan(returns));

    % Nome del portafoglio (es. Ret_4pc_Crypto)
    portName = portNames{selectedIdx(i)};
    
    % Boxplot
    boxplot(returns, 'Notch','on', ...
        'Colors', [0 0.45 0.74], ...
        'Widths', 0.3, ...
        'Symbol','r+');
    
    hold on;

    % Calcolo VaR 5%
    VaR5 = quantile(returns, 0.05);
    yline(VaR5, 'r--', ...
        'Label', sprintf('VaR_{5%%} = %.1f%%', VaR5*100), ...
        'LabelHorizontalAlignment', 'left', ...
        'LabelVerticalAlignment', 'middle', ...
        'FontSize', 8, ...
        'Color', 'r');

    title(strrep(portName, '_', '\_'), 'Interpreter','tex');
    ylabel('Monthly Return');
    grid on;
end

%% Diebold–Mariano Test: 60/40 puro vs. 60/40 + n% Crypto
r60_40 = CombinedTT_crypto.Port_LogRet;
DM_stat_vec = zeros(nW,1);
p_val_vec   = zeros(nW,1);

for j = 1:nW
    % Costruisci il nome della colonna con formato intero (senza decimali)
    portName = sprintf('Ret_%dpc_Crypto', round(weights(j)*100));
    
    % Estrai i rendimenti del portafoglio con cripto
    r_crypto = Portfolios_CryptoMix.(portName);

    % Differenza della funzione di perdita (loss = -return)
    d = -r60_40 + r_crypto;

    % Statistica DM
    d_bar = mean(d, 'omitnan');
    var_d = var(d, 'omitnan');
    T_DM = sum(~isnan(d));

    DM_stat = d_bar / sqrt(var_d / T_DM);
    p_val   = 2 * (1 - normcdf(abs(DM_stat)));  % test bilaterale

    DM_stat_vec(j) = DM_stat;
    p_val_vec(j) = p_val;
end

%% Final Results Table
DM_results = table((weights'*100), DM_stat_vec, p_val_vec, ...
    'VariableNames', {'Crypto_%','DM_Statistic','p_value'});

disp('Diebold–Mariano Test: 60/40 vs. 60/40 + Crypto');
disp(DM_results);

% Extract data from DM_results table
crypto_pct = DM_results.("Crypto_%");
dm_stat    = DM_results.DM_Statistic;
p_val      = DM_results.p_value;

% Dual-axis plot
figure;

yyaxis left
plot(crypto_pct, dm_stat, '-o', 'LineWidth', 1.8, 'Color', [0.1 0.4 0.8]);
ylabel('Diebold-Mariano Statistic');
ylim([min(dm_stat)-1, max(dm_stat)+1]);

yyaxis right
plot(crypto_pct, p_val, '--s', 'LineWidth', 1.8, 'Color', [0.85 0.33 0.1]);
ylabel('p-value');
ylim([0 1]);

% Significance threshold
yline(0.05, 'r--', 'LineWidth', 1.3, 'DisplayName', 'p = 0.05');

% Improve plot
xlabel('% Crypto in the Portfolio');
title('Diebold–Mariano Test: 60/40 vs. 60/40 + Crypto');
legend({'DM Statistic','p-value','p = 0.05'}, 'Location','northwest');
grid on;
xticks(crypto_pct);

%% Analisi di Correlazione, Varianza-Covarianza e Beta

% Estrai i rendimenti settimanali dei due portafogli
r60_40 = CombinedTT_crypto.Port_LogRet;
rCrypto = CombinedTT_crypto.LongShort_Mispricing_Ret;

% Allinea le due serie ed escludi NaN
validIdx = ~isnan(r60_40) & ~isnan(rCrypto);
returnsMatrix = [r60_40(validIdx), rCrypto(validIdx)];

%% 1. Matrice di Correlazione
corrMatrix = corr(returnsMatrix);
disp('Matrice di correlazione (60/40 vs. Strategia Crypto):');
disp(array2table(corrMatrix, 'VariableNames', {'60_40', 'Crypto'}, 'RowNames', {'60_40', 'Crypto'}));

%% 2. Matrice di Varianza-Covarianza
covMatrix = cov(returnsMatrix);
disp('Matrice di varianza-covarianza:');
disp(array2table(covMatrix, 'VariableNames', {'60_40', 'Crypto'}, 'RowNames', {'60_40', 'Crypto'}));

%% 3. Regressione per stimare Beta della Strategia Crypto rispetto al 60/40
X = r60_40(validIdx);  % indipendente
Y = rCrypto(validIdx); % dipendente
mdl = fitlm(X, Y);
disp('Beta della strategia Crypto rispetto al 60/40:');
disp(mdl.Coefficients);

% Stampa solo beta
fprintf('Beta = %.4f | Intercetta = %.4f | R^2 = %.4f\n', ...
    mdl.Coefficients.Estimate(2), mdl.Coefficients.Estimate(1), mdl.Rsquared.Ordinary);

%% Calcolo Correlazione e Beta rispetto al 60/40 per ciascun portafoglio CryptoMix
corrVec = zeros(nW, 1);
betaVec = zeros(nW, 1);

for j = 1:nW
    r_mix = Portfolios_CryptoMix{:, j};  % portafoglio con % crypto
    validIdx = ~isnan(r60_40) & ~isnan(r_mix);

    % Correlazione
    corrMat = corr([r60_40(validIdx), r_mix(validIdx)]);
    corrVec(j) = corrMat(1,2);

    % Beta (regressione)
    mdl = fitlm(r60_40(validIdx), r_mix(validIdx));
    betaVec(j) = mdl.Coefficients.Estimate(2);  % coefficiente angolare
end

%% Dual Plot: Correlation and Beta as a Function of % Crypto
figure;

% --- Subplot 1: Correlation vs % Crypto
subplot(1,2,1);
plot(weights*100, corrVec, 'o-', 'LineWidth', 1.5, 'Color', [0.9 0.4 0]);
yline(0, '--k');
title('Correlation vs % Crypto');
xlabel('% Crypto in Portfolio');
ylabel('Correlation with 60/40');
grid on;

% --- Subplot 2: Beta vs % Crypto
subplot(1,2,2);
plot(weights*100, betaVec, 's-', 'LineWidth', 1.5, 'Color', [0 0.6 1]);
yline(0, '--k');
title('Beta vs % Crypto');
xlabel('% Crypto in Portfolio');
ylabel('Beta Relative to 60/40');
grid on;

%% Bootstrap dei rendimenti settimanali out-of-sample
rng(0);  % per riproducibilità
nBoot = 1000;
nObs = sum(~isnan(ret_mispricing_oos));  % numero osservazioni valide

boot_mean = zeros(nBoot,1);
boot_vol  = zeros(nBoot,1);
boot_sharpe = zeros(nBoot,1);

validRet = ret_mispricing_oos(~isnan(ret_mispricing_oos));

for b = 1:nBoot
    sample = datasample(validRet, nObs);  % sampling con replacement
    boot_mean(b) = mean(sample);
    boot_vol(b)  = std(sample);
    boot_sharpe(b) = boot_mean(b) / boot_vol(b);
end

% Intervalli di confidenza 95%
ci_mean = prctile(boot_mean, [2.5, 97.5]);
ci_vol  = prctile(boot_vol, [2.5, 97.5]);
ci_sharpe = prctile(boot_sharpe, [2.5, 97.5]);

fprintf('\nIntervallo di confidenza 95%% - Rendimento medio: [%.4f, %.4f]\n', ci_mean);
fprintf('Intervallo di confidenza 95%% - Volatilità:       [%.4f, %.4f]\n', ci_vol);
fprintf('Intervallo di confidenza 95%% - Sharpe Ratio:     [%.4f, %.4f]\n', ci_sharpe);

%% 1. Pulizia e allineamento dei dati out-of-sample
validIdx = ~isnan(ret_mispricing_oos);  % osservazioni valide
rMispricing = ret_mispricing_oos(validIdx);
r6040 = r60_40(validIdx);

%% 2. Bootstrap con replacement per confronto statistico
rng(0);              % per riproducibilità
nBoot = 1000;        % numero di bootstrap
nObs = length(rMispricing);

mean_diff = zeros(nBoot,1);     % differenze di rendimento medio
sharpe_diff = zeros(nBoot,1);   % differenze di Sharpe Ratio

for b = 1:nBoot
    idx = randi(nObs, nObs, 1);   % campionamento con replacement
    
    % Campioni bootstrap
    s_misp = rMispricing(idx);
    s_6040 = r6040(idx);
    
    % Rendimento medio
    mean_diff(b) = mean(s_misp) - mean(s_6040);
    
    % Sharpe Ratio
    sharpe_misp = mean(s_misp)/std(s_misp);
    sharpe_6040 = mean(s_6040)/std(s_6040);
    sharpe_diff(b) = sharpe_misp - sharpe_6040;
end

%% 3. Calcolo Intervalli di Confidenza Bootstrap (percentili)
ci_mean   = quantile(mean_diff, [0.025 0.975]);
ci_sharpe = quantile(sharpe_diff, [0.025 0.975]);

% Output Risultati
fprintf('Intervallo di confidenza 95%% – Differenza rendimento medio: [%.4f, %.4f]\n', ci_mean);
fprintf('Intervallo di confidenza 95%% – Differenza Sharpe Ratio:    [%.4f, %.4f]\n', ci_sharpe);


%% Bootstrap: 60/40 puro vs. 60/40 + n% Crypto (nomi distinti)
rng(1);  % per riproducibilità indipendente
nBoot_cm = 1000;
r6040_cm = CombinedTT_crypto.Port_LogRet;

mean_diff_all_cm = zeros(nBoot_cm, nW);
sharpe_diff_all_cm = zeros(nBoot_cm, nW);

for j = 1:nW
    r_mix_cm = Portfolios_CryptoMix{:, j};
    
    % Escludi osservazioni NaN (entrambe le serie devono essere valide)
    validIdx_cm = ~isnan(r6040_cm) & ~isnan(r_mix_cm);
    r6040_valid_cm = r6040_cm(validIdx_cm);
    rMix_valid_cm = r_mix_cm(validIdx_cm);
    nObs_cm = length(r6040_valid_cm);
    
    % Preallocazione
    mean_diff_cm = zeros(nBoot_cm,1);
    sharpe_diff_cm = zeros(nBoot_cm,1);
    
    % Bootstrap
    for b = 1:nBoot_cm
        idx_cm = randi(nObs_cm, nObs_cm, 1);  % sampling con replacement
        s_6040_cm = r6040_valid_cm(idx_cm);
        s_mix_cm = rMix_valid_cm(idx_cm);

        % Differenze statistiche
        mean_diff_cm(b) = mean(s_mix_cm) - mean(s_6040_cm);
        sharpe_diff_cm(b) = (mean(s_mix_cm)/std(s_mix_cm)) - (mean(s_6040_cm)/std(s_6040_cm));
    end
    
    % Salva
    mean_diff_all_cm(:, j) = mean_diff_cm;
    sharpe_diff_all_cm(:, j) = sharpe_diff_cm;
end

%% Calcolo intervalli di confidenza (percentili bootstrap)
ci_mean_cm = quantile(mean_diff_all_cm, [0.025 0.975]);
ci_sharpe_cm = quantile(sharpe_diff_all_cm, [0.025 0.975]);

% Visualizza risultati
fprintf('\n=== Bootstrap 95%% CI – Differenza 60/40 + Crypto vs 60/40 puro ===\n');
for j = 1:nW
    fprintf('Peso Crypto: %2d%% | Rend [%.4f, %.4f] | Sharpe [%.4f, %.4f]\n', ...
        round(weights(j)*100), ci_mean_cm(1,j), ci_mean_cm(2,j), ci_sharpe_cm(1,j), ci_sharpe_cm(2,j));
end

%% Confidence Intervals Plot – Return and Sharpe Ratio Differentials
figure('Position', [100, 100, 1200, 500]);  % aumenta la larghezza

t = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
title(t, '95% Confidence Intervals: Crypto-Enhanced vs 60/40');

% === Left: Return Differential ===
nexttile;
x = weights * 100;
errorbar(x, mean(mean_diff_all_cm), ...
    mean(mean_diff_all_cm) - ci_mean_cm(1,:), ...
    ci_mean_cm(2,:) - mean(mean_diff_all_cm), ...
    'o-', 'LineWidth', 1.5, 'Color', [0.1 0.5 0.8]);
yline(0, '--k');
xlabel('% Crypto in Portfolio');
ylabel('Return Differential');
title('Return Differential (CryptoMix – 60/40)');
grid on;

% === Right: Sharpe Ratio Differential ===
nexttile;
errorbar(x, mean(sharpe_diff_all_cm), ...
    mean(sharpe_diff_all_cm) - ci_sharpe_cm(1,:), ...
    ci_sharpe_cm(2,:) - mean(sharpe_diff_all_cm), ...
    's-', 'LineWidth', 1.5, 'Color', [0.8 0.4 0.1]);
yline(0, '--k');
xlabel('% Crypto in Portfolio');
ylabel('Sharpe Ratio Differential');
title('Sharpe Differential (CryptoMix – 60/40)');
grid on;

%% Stress Test: Simulazione shock -30% Crypto in una settimana

% 1. Parametri dello shock
shock_pct = -0.30;                            % Intensità dello shock
shock_week = datetime('2023-06-04');         % Data da shockare (verificata su CombinedTT_crypto.Date)

% 2. Estrai le serie originali
r60_40 = CombinedTT_crypto.Port_LogRet;                  % Rendimento portafoglio 60/40
rCrypto = CombinedTT_crypto.LongShort_Mispricing_Ret;    % Strategia crypto

% 3. Applica lo shock
rCrypto_stressed = rCrypto;                              % Copia originale
idx_shock = find(CombinedTT_crypto.Date == shock_week);  % Cerca la data esatta

if ~isempty(idx_shock)
    rCrypto_stressed(idx_shock) = shock_pct;             % Applica shock
else
    warning('Data shock non trovata nella serie temporale.');
end

% 4. Ricostruisci il portafoglio combinato stressed (es. allocazione 10% in crypto)
wCrypto = 0.10;
wRemaining = 1 - wCrypto;
wSPY = 0.60 * wRemaining;
wAGG = 0.40 * wRemaining;

rStressed = wSPY * rSPY_weekly + wAGG * rAGG_weekly + wCrypto * rCrypto_stressed;

%% Valutazione impatto: Drawdown e confronto con portafoglio normale

% 1. Calcolo rendimento cumulato (normale vs. con shock)
cumNormal = cumprod(1 + (wSPY * r60_40 + wCrypto * rCrypto), 'omitnan');
cumStressed = cumprod(1 + rStressed, 'omitnan');

% 2. Funzione drawdown
computeDrawdown = @(cumR) max(1 - cumR ./ cummax(cumR));

% 3. Calcolo drawdown massimo
maxDD_normal = computeDrawdown(cumNormal);
maxDD_stressed = computeDrawdown(cumStressed);

% 4. Output
fprintf('Drawdown normale (0.1 crypto):  %.2f%%\n', maxDD_normal * 100);
fprintf('Drawdown con shock(0.1 crypto): %.2f%%\n', maxDD_stressed * 100);

%% Analisi Diversificazione Effettiva (correlazione e beta post-shock)

% 5. Selezione osservazioni valide
validIdx = ~isnan(r60_40) & ~isnan(rStressed);

% 6. Correlazione post-shock
corr_post = corr(r60_40(validIdx), rStressed(validIdx));

% 7. Regressione per beta
mdl_post = fitlm(r60_40(validIdx), rStressed(validIdx));
beta_post = mdl_post.Coefficients.Estimate(2);

% 8. Output
fprintf('Correlazione post-shock: %.4f\n', corr_post);
fprintf('Beta post-shock: %.4f\n', beta_post);

% 9. Plot
plot(cumNormal, 'b'); hold on;
plot(cumStressed, 'r');
legend('Normal', 'With Shock');
title('Equity Curve – Stress Test');
xlabel('Weeks');  % X-axis: time (weeks)
ylabel('Cumulative Portfolio Value');  % Y-axis: cumulative growth
grid on;

%% Stress Test: Sensibilità a diversi livelli di allocazione Crypto

% Parametri
shock_pct = -0.30;                          % shock del -30%
shock_date = datetime('2023-06-04');       % settimana dello shock
alloc_levels = [0.05, 0.10, 0.20];          % % crypto da testare

% Serie originali (settimanali)
rSPY = rSPY_weekly;
rAGG = rAGG_weekly;
rCrypto = CombinedTT_crypto.LongShort_Mispricing_Ret;

% Verifica indice dello shock
shockIdx = find(CombinedTT_crypto.Date == shock_date);
if isempty(shockIdx)
    error('La data dello shock non è presente nella serie temporale.');
end

% Allinea tutte le serie (taglio in coda)
minLen = min([length(rSPY), length(rAGG), length(rCrypto)]);
rSPY    = rSPY(end - minLen + 1:end);
rAGG    = rAGG(end - minLen + 1:end);
rCrypto = rCrypto(end - minLen + 1:end);
shockIdx = shockIdx - (length(rCrypto) - minLen);  % aggiorna l’indice shock in base al taglio

% Preallocazione
nA = length(alloc_levels);
cumResults = zeros(minLen, nA);

% Costruzione portafogli con diversi pesi crypto
for a = 1:nA
    wC = alloc_levels(a);
    wSPY = 0.60 * (1 - wC);
    wAGG = 0.40 * (1 - wC);

    % Serie stressata
    rCrypto_stressed = rCrypto;
    rCrypto_stressed(shockIdx) = shock_pct;

    % Ritorno portafoglio misto
    r_mix = wSPY * rSPY + wAGG * rAGG + wC * rCrypto_stressed;

    % Equity curve cumulata
    cumResults(:, a) = cumprod(1 + r_mix, 'omitnan');
end

%% Plot Equity Curve for Different Crypto Allocations (Time-Aligned)
figure;
plot(CombinedTT_crypto.Date(end - minLen + 1:end), cumResults, 'LineWidth', 1.5);
legend({'5% Crypto', '10% Crypto', '20% Crypto'}, 'Location', 'northwest');
title('Stress Test: Different Crypto Allocations under -30% Weekly Shock');
xlabel('Date');
ylabel('Equity Curve');
grid on;

%% Analisi Drawdown: confronto pre/post shock su livelli di allocazione crypto

% Inizializza array per salvare i drawdown massimi
dd_normali = zeros(nA,1);
dd_shockati = zeros(nA,1);

for i = 1:nA
    pctCrypto = alloc_levels(i);
    pctEquity = 0.60 * (1 - pctCrypto);
    pctBond   = 0.40 * (1 - pctCrypto);

    % Ritorni senza shock
    r_clean = pctEquity * rSPY + pctBond * rAGG + pctCrypto * rCrypto;
    equity_clean = cumprod(1 + r_clean, 'omitnan');

    % Ritorni con shock (già salvati in cumResults)
    equity_stress = cumResults(:, i);

    % Calcolo drawdown
    dd_norm = 1 - equity_clean ./ cummax(equity_clean);
    dd_stress = 1 - equity_stress ./ cummax(equity_stress);

    dd_normali(i) = max(dd_norm);
    dd_shockati(i) = max(dd_stress);
end

% Esporta tabella comparativa
Tab_Drawdown = table(alloc_levels'*100, dd_normali*100, dd_shockati*100, ...
    'VariableNames', {'Alloc_Crypto_%','MaxDD_Normal_%','MaxDD_Shock_%'});

disp(Tab_Drawdown);

%% Analisi Diversificazione: correlazione e beta post-shock per allocazioni % Crypto

% Calcola la lunghezza minima tra tutte le serie
minLen = min([length(rSPY), length(rAGG), length(rCrypto), length(r6040)]);

% Allinea tutte le serie alla coda comune
rSPY     = rSPY(end - minLen + 1:end);
rAGG     = rAGG(end - minLen + 1:end);
rCrypto  = rCrypto(end - minLen + 1:end);
r6040    = r6040(end - minLen + 1:end);
shockIdx = find(CombinedTT_crypto.Date(end - minLen + 1:end) == shock_date);  % ricalcola shockIdx

% Prealloca
nA = length(alloc_levels);
correlazioni_post = zeros(nA,1);
beta_postshock    = zeros(nA,1);

for i = 1:nA
    % Pesi allocazione i-esima
    alloc    = alloc_levels(i);
    wEquity  = 0.60 * (1 - alloc);
    wBond    = 0.40 * (1 - alloc);

    % Applica shock
    rCrypto_mod = rCrypto;
    if ~isempty(shockIdx)
        rCrypto_mod(shockIdx) = shock_pct;
    end

    % Costruisci portafoglio stressato
    rStressMix = wEquity * rSPY + wBond * rAGG + alloc * rCrypto_mod;

    % Seleziona osservazioni valide
    valid = ~isnan(r6040) & ~isnan(rStressMix);

    % Calcolo correlazione
    correlazioni_post(i) = corr(r6040(valid), rStressMix(valid));

    % Calcolo beta via regressione
    mdl = fitlm(r6040(valid), rStressMix(valid));
    beta_postshock(i) = mdl.Coefficients.Estimate(2);
end

% Tabella risultati
T_corr_beta = table(alloc_levels'*100, correlazioni_post, beta_postshock, ...
    'VariableNames', {'Crypto_%','Corr_PostShock','Beta_PostShock'});

disp(T_corr_beta);

%% Stress Test Prolungato: 3 settimane di shock sulla strategia Crypto

% 1. Parametri shock e allocazione
shock_dates  = datetime({'2023-06-04', '2023-06-11', '2023-06-18'});
shock_values = [-0.15, -0.10, -0.05];  % shock progressivi settimanali
wCrypto = 0.10;
wSPY = 0.60 * (1 - wCrypto);
wAGG = 0.40 * (1 - wCrypto);

% 2. Serie originali (assumendo già coerenti e settimanali)
rSPY    = rSPY_weekly;
rAGG    = rAGG_weekly;
rCrypto = CombinedTT_crypto.LongShort_Mispricing_Ret;

% 3. Allinea le serie (coda uguale)
minLen = min([length(rSPY), length(rAGG), length(rCrypto)]);
rSPY    = rSPY(end - minLen + 1:end);
rAGG    = rAGG(end - minLen + 1:end);
rCrypto = rCrypto(end - minLen + 1:end);
dates   = CombinedTT_crypto.Date(end - minLen + 1:end);

% 4. Applica lo shock prolungato
rCrypto_stressed = rCrypto;
for k = 1:length(shock_dates)
    idx_k = find(dates == shock_dates(k));
    if ~isempty(idx_k)
        rCrypto_stressed(idx_k) = shock_values(k);
    else
        warning('Data shock non trovata: %s', string(shock_dates(k)));
    end
end

% 5. Ricostruisci portafogli normale e stressato
rNormal   = wSPY * rSPY + wAGG * rAGG + wCrypto * rCrypto;
rStressed = wSPY * rSPY + wAGG * rAGG + wCrypto * rCrypto_stressed;

% === Stress Test Prolungato: 5% Crypto ===

wCrypto = 0.05;
wSPY = 0.60 * (1 - wCrypto);
wAGG = 0.40 * (1 - wCrypto);

rNormal_5   = wSPY * rSPY + wAGG * rAGG + wCrypto * rCrypto;
rStressed_5 = wSPY * rSPY + wAGG * rAGG + wCrypto * rCrypto_stressed;

cumNormal_5   = cumprod(1 + rNormal_5, 'omitnan');
cumStressed_5 = cumprod(1 + rStressed_5, 'omitnan');

computeDrawdown = @(cumR) max(1 - cumR ./ cummax(cumR));
maxDD_normal_5   = computeDrawdown(cumNormal_5);
maxDD_stressed_5 = computeDrawdown(cumStressed_5);

fprintf('\n DRAWDOWN - 5%% Crypto \n');
fprintf('Drawdown normale:           %.2f%%\n', maxDD_normal_5 * 100);
fprintf('Drawdown con shock lungo:   %.2f%%\n', maxDD_stressed_5 * 100);

validIdx_5 = ~isnan(rNormal_5) & ~isnan(rStressed_5);
corr_post_5 = corr(rNormal_5(validIdx_5), rStressed_5(validIdx_5));
mdl_post_5 = fitlm(rNormal_5(validIdx_5), rStressed_5(validIdx_5));
beta_post_5 = mdl_post_5.Coefficients.Estimate(2);

fprintf('\n DIVERSIFICAZIONE POST-SHOCK - 5%% Crypto \n');
fprintf('Correlazione post-shock prolungato: %.4f\n', corr_post_5);
fprintf('Beta post-shock prolungato:        %.4f\n', beta_post_5);


% === Stress Test Prolungato: 20% Crypto ===

wCrypto = 0.20;
wSPY = 0.60 * (1 - wCrypto);
wAGG = 0.40 * (1 - wCrypto);

rNormal_20   = wSPY * rSPY + wAGG * rAGG + wCrypto * rCrypto;
rStressed_20 = wSPY * rSPY + wAGG * rAGG + wCrypto * rCrypto_stressed;

cumNormal_20   = cumprod(1 + rNormal_20, 'omitnan');
cumStressed_20 = cumprod(1 + rStressed_20, 'omitnan');

maxDD_normal_20   = computeDrawdown(cumNormal_20);
maxDD_stressed_20 = computeDrawdown(cumStressed_20);

fprintf('\n DRAWDOWN - 20%% Crypto \n');
fprintf('Drawdown normale:           %.2f%%\n', maxDD_normal_20 * 100);
fprintf('Drawdown con shock lungo:   %.2f%%\n', maxDD_stressed_20 * 100);

validIdx_20 = ~isnan(rNormal_20) & ~isnan(rStressed_20);
corr_post_20 = corr(rNormal_20(validIdx_20), rStressed_20(validIdx_20));
mdl_post_20 = fitlm(rNormal_20(validIdx_20), rStressed_20(validIdx_20));
beta_post_20 = mdl_post_20.Coefficients.Estimate(2);

fprintf('\n DIVERSIFICAZIONE POST-SHOCK - 20%% Crypto \n');
fprintf('Correlazione post-shock prolungato: %.4f\n', corr_post_20);
fprintf('Beta post-shock prolungato:        %.4f\n', beta_post_20);


%% Equity Curve – Normal vs Stressed
cumNormal   = cumprod(1 + rNormal, 'omitnan');
cumStressed = cumprod(1 + rStressed, 'omitnan');

figure;
plot(dates, cumNormal, 'b', 'LineWidth', 1.5, 'DisplayName', 'Normal'); hold on;
plot(dates, cumStressed, 'r', 'LineWidth', 1.5, 'DisplayName', 'With Shock');
title('Equity Curve – Extended Stress Test');
xlabel('Date');
ylabel('Cumulative Portfolio Value');
legend('Location','best');
grid on;

%% Drawdown Analysis
computeDrawdown = @(cumR) max(1 - cumR ./ cummax(cumR));
maxDD_normal   = computeDrawdown(cumNormal);
maxDD_stressed = computeDrawdown(cumStressed);

fprintf('\n DRAWDOWN \n');
fprintf('Drawdown normale:           %.2f%%\n', maxDD_normal * 100);
fprintf('Drawdown con shock lungo:   %.2f%%\n', maxDD_stressed * 100);

%% Diversificazione post-shock (Correlazione e Beta)
validIdx = ~isnan(rNormal) & ~isnan(rStressed);
corr_post = corr(rNormal(validIdx), rStressed(validIdx));
mdl_post = fitlm(rNormal(validIdx), rStressed(validIdx));
beta_post = mdl_post.Coefficients.Estimate(2);

fprintf('\n DIVERSIFICAZIONE POST-SHOCK \n');
fprintf('Correlazione post-shock prolungato: %.4f\n', corr_post);
fprintf('Beta post-shock prolungato:        %.4f\n', beta_post);

%% Equity Curve – Extended Stress Test (5%)
cumNormal_5   = cumprod(1 + rNormal_5, 'omitnan');
cumStressed_5 = cumprod(1 + rStressed_5, 'omitnan');

figure;
plot(dates, cumNormal_5, 'b', 'LineWidth', 1.5, 'DisplayName', 'Normal'); hold on;
plot(dates, cumStressed_5, 'r', 'LineWidth', 1.5, 'DisplayName', 'With Shock');
title('Equity Curve – Extended Stress Test (5% Crypto)');
xlabel('Date');
ylabel('Cumulative Portfolio Value');
legend('Location','best');
grid on;

%% Drawdown Analysis – 5%
computeDrawdown = @(cumR) max(1 - cumR ./ cummax(cumR));
maxDD_normal_5   = computeDrawdown(cumNormal_5);
maxDD_stressed_5 = computeDrawdown(cumStressed_5);

fprintf('\n DRAWDOWN – 5%% Crypto \n');
fprintf('Drawdown normale:           %.2f%%\n', maxDD_normal_5 * 100);
fprintf('Drawdown con shock lungo:   %.2f%%\n', maxDD_stressed_5 * 100);

%% Diversificazione post-shock – 5%
validIdx_5 = ~isnan(rNormal_5) & ~isnan(rStressed_5);
corr_post_5 = corr(rNormal_5(validIdx_5), rStressed_5(validIdx_5));
mdl_post_5 = fitlm(rNormal_5(validIdx_5), rStressed_5(validIdx_5));
beta_post_5 = mdl_post_5.Coefficients.Estimate(2);

fprintf('\n DIVERSIFICAZIONE POST-SHOCK – 5%% Crypto \n');
fprintf('Correlazione post-shock prolungato: %.4f\n', corr_post_5);
fprintf('Beta post-shock prolungato:        %.4f\n', beta_post_5);

%% Equity Curve – Extended Stress Test (20%)
cumNormal_20   = cumprod(1 + rNormal_20, 'omitnan');
cumStressed_20 = cumprod(1 + rStressed_20, 'omitnan');

figure;
plot(dates, cumNormal_20, 'b', 'LineWidth', 1.5, 'DisplayName', 'Normal'); hold on;
plot(dates, cumStressed_20, 'r', 'LineWidth', 1.5, 'DisplayName', 'With Shock');
title('Equity Curve – Extended Stress Test (20% Crypto)');
xlabel('Date');
ylabel('Cumulative Portfolio Value');
legend('Location','best');
grid on;

%% Drawdown Analysis – 20%
maxDD_normal_20   = computeDrawdown(cumNormal_20);
maxDD_stressed_20 = computeDrawdown(cumStressed_20);

fprintf('\n DRAWDOWN – 20%% Crypto \n');
fprintf('Drawdown normale:           %.2f%%\n', maxDD_normal_20 * 100);
fprintf('Drawdown con shock lungo:   %.2f%%\n', maxDD_stressed_20 * 100);

%% Diversificazione post-shock – 20%
validIdx_20 = ~isnan(rNormal_20) & ~isnan(rStressed_20);
corr_post_20 = corr(rNormal_20(validIdx_20), rStressed_20(validIdx_20));
mdl_post_20 = fitlm(rNormal_20(validIdx_20), rStressed_20(validIdx_20));
beta_post_20 = mdl_post_20.Coefficients.Estimate(2);

fprintf('\n DIVERSIFICAZIONE POST-SHOCK – 20%% Crypto \n');
fprintf('Correlazione post-shock prolungato: %.4f\n', corr_post_20);
fprintf('Beta post-shock prolungato:        %.4f\n', beta_post_20);

%% Fama–MacBeth Risk Premium
% Step 1 – Time-Series Regressions per ciascun portafoglio
nPort = width(Portfolios_CryptoMix);  % 20 portafogli
beta_FM = nan(nPort, 1);              % salva i beta stimati

% Usa FFall settimanale per ottenere Mkt-RF e RF
FF_week = retime(FFall, 'weekly', @sum);

for p = 1:nPort
    portName = Portfolios_CryptoMix.Properties.VariableNames{p};
    TT_sync = synchronize(Portfolios_CryptoMix(:, p), FF_week, 'intersection');
    
    % Calcola il rendimento in eccesso
    portRet  = TT_sync.(portName);
    mktPrem  = TT_sync.Mkt_RF / 100;
    rfWeek   = TT_sync.RF / 100;
    r_excess = portRet - rfWeek;

    % Regressione time-series: rendimento in eccesso ~ market premium
    mdl_reg = fitlm(mktPrem, r_excess);
    beta_FM(p) = mdl_reg.Coefficients.Estimate(2);
end

%% Step 2 – Regressioni Cross-Sectionali (una per settimana)
nObs = height(Portfolios_CryptoMix);
gamma0_vec = nan(nObs, 1);  % intercetta per ogni settimana
gamma1_vec = nan(nObs, 1);  % risk premium stimato settimanalmente

for t = 1:nObs
    % Estrai rendimenti settimanali dei portafogli a tempo t
    Ri_t = Portfolios_CryptoMix{t, :};  % 1 x nPort
    if any(isnan(Ri_t))
        continue;
    end
    
    % Regressione cross-sectionale settimanale: Ri,t = γ0,t + γ1,t * beta_i
    Z_gamma = [ones(nPort,1), beta_FM];
    coeffs_t = Z_gamma \ Ri_t';
    
    gamma0_vec(t) = coeffs_t(1);
    gamma1_vec(t) = coeffs_t(2);
end

%% Step 3 – Test di significatività del premio al rischio medio (γ₁)

gamma1_mean = mean(gamma1_vec, 'omitnan');
gamma1_std  = std(gamma1_vec, 'omitnan');
t_gamma1    = gamma1_mean / (gamma1_std / sqrt(length(gamma1_vec)));

% p-value (bilaterale)
p_val_gamma1 = 2 * (1 - tcdf(abs(t_gamma1), length(gamma1_vec) - 1));

% Intervallo di confidenza al 95%
alpha_conf = 0.05;
t_crit = tinv(1 - alpha_conf/2, length(gamma1_vec) - 1);
ci_lower = gamma1_mean - t_crit * (gamma1_std / sqrt(length(gamma1_vec)));
ci_upper = gamma1_mean + t_crit * (gamma1_std / sqrt(length(gamma1_vec)));

% Stampa
fprintf('\n=== Fama–MacBeth Risk Premium ===\n');
fprintf('Media γ1 (Risk Premium): %.5f\n', gamma1_mean);
fprintf('Dev.Std γ1: %.5f\n', gamma1_std);
fprintf('t-statistica: %.2f\n', t_gamma1);
fprintf('p-value: %.4f\n', p_val_gamma1);
fprintf('CI 95%%: [%.5f, %.5f]\n', ci_lower, ci_upper);

%% 1. Costruisci Y e X stacked
portNames_sur = Portfolios_CryptoMix.Properties.VariableNames;
nPorts_sur = numel(portNames_sur);
bigTT = synchronize(Portfolios_CryptoMix, FFall_weekly, 'intersection');
N = height(bigTT);

% Matrice Y: N x nPorts
Y_mat = zeros(N, nPorts_sur);
for j = 1:nPorts_sur
    Y_mat(:, j) = bigTT.(portNames_sur{j}) - bigTT.RF / 100;
end

% Matrice X: costante + Mkt_RF
X_mat = [ones(N,1), bigTT.Mkt_RF / 100];

% Rimuovi righe con NaN
valid = all(~isnan([X_mat, Y_mat]), 2);
Y_mat = Y_mat(valid, :);
X_mat = X_mat(valid, :);
N = size(Y_mat,1);

%% 2. OLS su ogni portafoglio
B_ols = zeros(2, nPorts_sur);
U_hat = zeros(N, nPorts_sur);

for j = 1:nPorts_sur
    yj = Y_mat(:, j);
    bj = X_mat \ yj;
    B_ols(:, j) = bj;
    U_hat(:, j) = yj - X_mat * bj;
end

%% 3. Stima matrice di var-cov degli errori
Sigma_u = (U_hat' * U_hat) / N;

%% 4. FGLS: stima SUR finale
% Costruiamo il sistema stacked: Y_stack = (I ⊗ X) * beta_vec
Y_stack = reshape(Y_mat, [], 1);              % (N * nPorts) x 1
X_block = kron(eye(nPorts_sur), X_mat);       % (N * nPorts) x (2 * nPorts)
lambda = 1e-6;  % puoi aumentare se serve
Sigma_u_reg = Sigma_u + lambda * eye(size(Sigma_u));
Sigma_inv = kron(inv(Sigma_u_reg), eye(N));      % (N * nPorts) x (N * nPorts)

% Stima FGLS
beta_fgls = (X_block' * Sigma_inv * X_block) \ (X_block' * Sigma_inv * Y_stack);

%% 5. Estrai alpha/beta e stampa
fprintf('\n=== Stima SUR manuale (FGLS) ===\n');
for j = 1:nPorts_sur
    alpha_j = beta_fgls((j-1)*2 + 1);
    beta_j  = beta_fgls((j-1)*2 + 2);
    fprintf('Portafoglio %2d → Alpha: %.4f | Beta: %.4f\n', j, alpha_j, beta_j);
end

%% Plot Alpha vs % Crypto
alphas = beta_fgls(1:2:end);  % extract alpha coefficients
plot(1:nPorts_sur, alphas, '-o');
xlabel('% Crypto');
ylabel('Estimated Alpha (SUR)');
title('Alpha vs % Crypto');
grid on;

%% Regressione cross-section
alpha_vals = beta_fgls(1:2:end);
pct_crypto = (1:nPorts_sur)' / 100;  % da 1% a 20%

Xcs = [ones(nPorts_sur,1), pct_crypto];
beta_cs = Xcs \ alpha_vals;

fprintf('\nRegressione cross-section α_j = a + b * pct_crypto:\n');
fprintf('a = %.4f | b = %.4f\n', beta_cs(1), beta_cs(2));


%% Plot Alpha vs % Crypto (with Linear Fit)
figure;
plot((1:nPorts_sur), alpha_vals, 'bo-', 'LineWidth', 1.5); hold on;
plot((1:nPorts_sur), Xcs * beta_cs, 'r--', 'LineWidth', 1.5);
xlabel('% Crypto');
ylabel('Estimated Alpha (SUR)');
title('Alpha vs % Crypto');
legend('Estimated Alphas', 'Linear Regression', 'Location', 'NorthWest');
grid on;

%% Wald Test sugli alpha
alpha_vec = beta_fgls(1:2:end);
wald_stat = (alpha_vec' * alpha_vec) / var(alpha_vec);  % semplificato
df_wald = length(alpha_vec);
pval_wald = 1 - chi2cdf(wald_stat, df_wald);

fprintf('\n=== Test di Wald su alpha_j = 0 ===\n');
fprintf('Wald statistic: %.4f | df: %d | p-value: %.4f\n', wald_stat, df_wald, pval_wald);

%% Costruzione del Portafoglio Equal-Weighted Weekly

nCrypto = length(weeklyReturns);
% Trova la prima timetable valida per usare le date
idxValid = find(~cellfun(@isempty, weeklyReturns), 1);
commonDates = weeklyReturns{idxValid}.Properties.RowTimes;
nWeeks = height(weeklyReturns{idxValid});

% Matrice dei rendimenti settimanali (nWeeks x nCrypto)
retMatrix = nan(nWeeks, nCrypto);

for i = 1:nCrypto
    if isempty(weeklyReturns{i})
        continue;
    end
    tempTT = weeklyReturns{i};
    % Allinea alla timeline comune
    tempTT = retime(tempTT, commonDates, 'previous');
    retMatrix(:,i) = tempTT{:,1};
end

% Rendimento medio equal-weighted settimanale
equalRet = mean(retMatrix, 2, 'omitnan');

% Crea la timetable finale
Portfolio_EqualWeighted = timetable(commonDates, equalRet, ...
    'VariableNames', {'EqualWeighted_Ret'});

fprintf('✓ Portafoglio Equal-Weighted costruito correttamente su %d crypto.\n', nCrypto);

%% Analisi rigorosa delle performance del portafoglio Equal-Weighted

% Estrai rendimenti validi (escludi i NaN iniziali)
ret_eqw = Portfolio_EqualWeighted.EqualWeighted_Ret;
dates_eqw = Portfolio_EqualWeighted.commonDates;
validEqIdx = ~isnan(ret_eqw);
ret_eqw_valid = ret_eqw(validEqIdx);
dates_eqw_valid = dates_eqw(validEqIdx);

% Statistiche settimanali
meanRetWeek_eqw = mean(ret_eqw_valid);
stdRetWeek_eqw  = std(ret_eqw_valid);

% Annualizzazione
meanRetAnn_eqw = meanRetWeek_eqw * 52;
stdRetAnn_eqw  = stdRetWeek_eqw * sqrt(52);
sharpe_eqw     = meanRetAnn_eqw / stdRetAnn_eqw;

% Sortino annualizzato (usando solo downside)
downside_eqw = ret_eqw_valid(ret_eqw_valid < 0);
sortino_eqw  = meanRetAnn_eqw / (std(downside_eqw) * sqrt(52));

% Equity curve
cumulative_eqw = cumprod(1 + ret_eqw_valid);
portVal_eqw = cumulative_eqw;
peak_eqw = cummax(portVal_eqw);
drawdown_eqw = (portVal_eqw - peak_eqw) ./ peak_eqw;
maxDrawdown_eqw = min(drawdown_eqw);

% Stampa
fprintf('\nPortafoglio Equal-Weighted - Performance settimanale annualizzata\n');
fprintf('Media rendimento settimanale:            %.6f\n', meanRetWeek_eqw);
fprintf('Deviazione standard settimanale:         %.6f\n', stdRetWeek_eqw);
fprintf('Media rendimento annualizzata:           %.4f\n', meanRetAnn_eqw);
fprintf('Volatilità annualizzata:                 %.4f\n', stdRetAnn_eqw);
fprintf('Sharpe Ratio annualizzato:               %.3f\n', sharpe_eqw);
fprintf('Sortino Ratio annualizzato:              %.3f\n', sortino_eqw);
fprintf('Max Drawdown - Portafoglio EqualWeighted: %.2f%%\n', maxDrawdown_eqw * 100);

%% F-test: alpha Mispricing vs EqualWeighted

% Estrai le serie
ret_mispr = Portfolio_Mispricing.LongShort_Mispricing_Ret;
ret_eqw   = Portfolio_EqualWeighted.EqualWeighted_Ret;

% Aggiunta delle date per costruire le timetable
tt_mispr = timetable(Portfolio_Mispricing.commonDates, ret_mispr, 'VariableNames', {'ret_mispr'});
tt_eqw   = timetable(Portfolio_EqualWeighted.commonDates, ret_eqw, 'VariableNames', {'ret_eqw'});

% Sincronizzazione con i fattori Fama-French
tempTT_mispr = synchronize(tt_mispr, FFall_weekly, 'intersection');
tempTT_eqw   = synchronize(tt_eqw,   FFall_weekly, 'intersection');

% Excess returns
rex_mispr = tempTT_mispr.ret_mispr - tempTT_mispr.RF;
rex_eqw   = tempTT_eqw.ret_eqw     - tempTT_eqw.RF;

% Market factor
X_mkt_mispr = [ones(length(tempTT_mispr.Mkt_RF),1), tempTT_mispr.Mkt_RF];
X_mkt_eqw   = [ones(length(tempTT_eqw.Mkt_RF),1),   tempTT_eqw.Mkt_RF];

% Regressioni CAPM separate
[b_mispr,~,~,~,~] = regress(rex_mispr, X_mkt_mispr);
[b_eqw,  ~,~,~,~] = regress(rex_eqw,   X_mkt_eqw);

alpha1 = b_mispr(1);
alpha2 = b_eqw(1);

% Residui separati
resid_mispr = rex_mispr - X_mkt_mispr * b_mispr;
resid_eqw   = rex_eqw   - X_mkt_eqw   * b_eqw;

SSR_unrestr = sum(resid_mispr.^2) + sum(resid_eqw.^2);

% Modello con vincolo: alpha_mispr = alpha_eqw
rex_stack = [rex_mispr; rex_eqw];
X_stack = [X_mkt_mispr; X_mkt_eqw];

group = [ones(size(rex_mispr)); zeros(size(rex_eqw))];  % Dummy 1 per mispr, 0 per eqw

% Specificazione: intercetta comune + dummy * market + interaction
Z = [ones(size(rex_stack)), group, X_stack(:,2), group .* X_stack(:,2)];

% Regressione vincolata
[b_restr,~,~,~,~] = regress(rex_stack, Z);
resid_restr = rex_stack - Z * b_restr;
SSR_restr = sum(resid_restr.^2);

% F-test
k = 1;  % vincoli (solo differenza negli alpha)
n = length(rex_stack);
F_stat = ((SSR_restr - SSR_unrestr) / k) / (SSR_unrestr / (n - 4));
p_val_alpha = 1 - fcdf(F_stat, k, n - 4);

% Output
fprintf('\n F-test on Alpha Equality (CAPM) \n');
fprintf('Alpha Mispricing:      %.5f\n', alpha1);
fprintf('Alpha Equal-Weighted:  %.5f\n', alpha2);
fprintf('F-statistica:          %.4f\n', F_stat);
fprintf('p-value:               %.4f\n', p_val_alpha);

%% Sincronizzazione e regressione multifattoriale (FF3+MOM)
% Mispricing
tempTT_mispr = synchronize(Portfolio_Mispricing, FFall_weekly, 'intersection');
tempTT_mispr.Excess = tempTT_mispr.LongShort_Mispricing_Ret - tempTT_mispr.RF/100;

X_mispr = [ones(height(tempTT_mispr),1), tempTT_mispr.Mkt_RF/100, tempTT_mispr.SMB/100, tempTT_mispr.HML/100, tempTT_mispr.Mom/100];
Y_mispr = tempTT_mispr.Excess;

[b_mispr, ~, ~, ~, stats_mispr] = regress(Y_mispr, X_mispr);

% Equal-Weighted
tempTT_eqw = synchronize(Portfolio_EqualWeighted, FFall_weekly, 'intersection');
tempTT_eqw.Excess = tempTT_eqw.EqualWeighted_Ret - tempTT_eqw.RF/100;

X_eqw = [ones(height(tempTT_eqw),1), tempTT_eqw.Mkt_RF/100, tempTT_eqw.SMB/100, tempTT_eqw.HML/100, tempTT_eqw.Mom/100];
Y_eqw = tempTT_eqw.Excess;

[b_eqw, ~, ~, ~, stats_eqw] = regress(Y_eqw, X_eqw);

%% F-Test per confrontare alpha
% Differenza tra alpha
alpha_diff = b_mispr(1) - b_eqw(1);

% Errori standard di alpha
sigma2_mispr = var(Y_mispr - X_mispr*b_mispr);
sigma2_eqw   = var(Y_eqw   - X_eqw*b_eqw);

XTX_mispr = inv(X_mispr' * X_mispr);
XTX_eqw   = inv(X_eqw' * X_eqw);

se_alpha1 = sqrt(sigma2_mispr * XTX_mispr(1,1));
se_alpha2 = sqrt(sigma2_eqw   * XTX_eqw(1,1));

% Varianza combinata della differenza
var_diff = se_alpha1^2 + se_alpha2^2;
F_stat = (alpha_diff)^2 / var_diff;

% Gradi di libertà approssimati (puoi prendere min dei due)
df = min(length(Y_mispr) - 5, length(Y_eqw) - 5);
p_val_f = 1 - fcdf(F_stat, 1, df);

fprintf('\n F-test: confronto tra Alpha Mispricing e Equal-Weighted \n');
fprintf('Alpha Mispricing: %.5f | Alpha Equal-Weighted: %.5f\n', b_mispr(1), b_eqw(1));
fprintf('F-statistica: %.4f | p-value: %.4f\n', F_stat, p_val_f);

