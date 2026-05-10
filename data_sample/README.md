# Data Sample

This folder contains the input files required to run or inspect the main empirical workflow.

## Files

- `spy_agg_data.csv`: historical SPY and AGG price data used to construct the traditional 60/40 equity-bond benchmark.
- `F-F_Research_Data_Factors_daily.csv`: daily Fama-French factor returns, including market, size, value and risk-free rate factors.
- `F-F_Momentum_Factor_daily.csv`: daily momentum factor returns.

## Notes

The MATLAB script converts daily benchmark and factor data into weekly frequency when required.

Cryptocurrency data are not stored directly in this repository. They are collected through the CryptoCompare API using the MATLAB script in `src/`.

For security reasons, no API keys are included. Users must set their own CryptoCompare API key as an environment variable named `CRYPTOCOMPARE_API_KEY`.
