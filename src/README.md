# Source Code

This folder contains the full MATLAB script used for the empirical analysis of the project.

## File

- `crypto_mispricing_full_analysis.m`: full analysis script including 60/40 benchmark construction, CryptoCompare data collection, Size and Risk-Adjusted Momentum signal construction, long-short portfolio backtesting, hybrid portfolio integration, CAPM/Fama-French regressions, GARCH estimation, bootstrap simulations, stress testing, Fama-MacBeth regressions and equal-weighted benchmark comparison.

## Required Input Files

The script requires the following input files:

- `spy_agg_data.csv`
- `F-F_Research_Data_Factors_daily.csv`
- `F-F_Momentum_Factor_daily.csv`

These files should be placed in the working directory or in the path specified by the user.

## API Key

CryptoCompare data are retrieved through the CryptoCompare API. For security reasons, no API key is included in this repository.

To run the script, users must set their own API key as an environment variable named:

```text
CRYPTOCOMPARE_API_KEY
```

Example for macOS/Linux:

```bash
export CRYPTOCOMPARE_API_KEY="your_api_key_here"
```

Example for Windows PowerShell:

```powershell
setx CRYPTOCOMPARE_API_KEY "your_api_key_here"
```

## Notes

This script is published as a cleaned academic version of the original project code.

The code is intentionally kept as a single full workflow to preserve the structure of the empirical analysis, from data collection and signal construction to portfolio backtesting, econometric testing and stress analysis.
