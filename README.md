# Crypto Mispricing and Portfolio Diversification

This repository contains the research project **Crypto Mispricing and Portfolio Diversification: Evidence from a Long-Short Strategy**, developed in 2025 for the **Econometric Theory** course at **LUISS Guido Carli**.

The project evaluates whether a systematic long-short cryptocurrency strategy can improve the performance and risk profile of a traditional 60/40 equity-bond portfolio.

## Project Information

- **Course:** Econometric Theory
- **Institution:** LUISS Guido Carli
- **Academic Year:** 2024–2025
- **Project Date:** 2025
- **Authors:** Gabriele Achia, Giannandrea De Stefano, Paolo Gaudenzi

## Research Question

Are cryptocurrencies purely speculative assets, or can a systematic crypto strategy provide diversification benefits within traditional portfolio allocation?

## Methodology

The strategy is based on a composite mispricing factor combining:

- **Size:** inverse logarithm of a market capitalization proxy
- **Risk-Adjusted Momentum:** cumulative returns over 1-, 2- and 4-week horizons scaled by realized volatility

Signals are standardized cross-sectionally using z-scores and combined into a weekly mispricing score. The strategy ranks cryptoassets weekly and builds a market-neutral long-short portfolio by going long the top-ranked assets and short the bottom-ranked assets.

## Data

- Cryptocurrency universe: 79 liquid cryptocurrencies
- Stablecoins and low-quality assets excluded
- Sample period: October 2019 – March 2025
- Benchmark: 60/40 portfolio using SPY and AGG ETFs
- Frequency: weekly
- Main data sources: CryptoCompare API, Yahoo Finance, Fama-French Data Library

## Empirical Framework

The analysis includes:

- Portfolio backtesting
- CAPM and Fama-French/Carhart regressions
- Fama-MacBeth tests
- GARCH(1,1) volatility modelling
- Bootstrap simulations
- Stress testing
- Diebold-Mariano tests
- Drawdown and risk-adjusted performance analysis

## Key Findings

Across tested crypto-enhanced allocations, the strategy improved risk-adjusted performance and reduced downside risk.

In the tested allocation range, maximum drawdown decreased from **-21.9%** to **-10.96%**, while the Sharpe ratio increased from **0.71** to **2.29**.

These results should be interpreted as backtest evidence, subject to limitations such as survivorship bias, shorting constraints, simplified transaction costs, liquidity frictions and the evolving structure of crypto markets.

## Repository Structure

```text
paper/        Research paper
src/          MATLAB analysis script
figures/      Output charts and visual diagnostics
results/      Tables and empirical outputs
data_sample/  Small sample data or documentation only
```

## Disclaimer

This repository is intended for academic and research purposes only. It does not constitute investment advice.
