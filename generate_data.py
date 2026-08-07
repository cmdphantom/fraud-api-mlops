#!/usr/bin/env python3
"""Generate synthetic credit card fraud detection dataset mimicking the Kaggle dataset structure."""

import numpy as np
import pandas as pd
from pathlib import Path

np.random.seed(42)

# Generate synthetic data mimicking the creditcard.csv structure
# 30 features: Time, V1-V28 (PCA components), Amount, Class (target)
n_samples = 100000
fraud_ratio = 0.0017  # ~0.17% fraud rate like original dataset

n_fraud = int(n_samples * fraud_ratio)
n_normal = n_samples - n_fraud

# Time feature (seconds elapsed between transactions)
time_normal = np.cumsum(np.random.exponential(scale=60, size=n_normal))
time_fraud = np.cumsum(np.random.exponential(scale=30, size=n_fraud))

# Amount feature (transaction amount)
amount_normal = np.random.lognormal(mean=3.0, sigma=1.5, size=n_normal)
amount_fraud = np.random.lognormal(mean=4.5, sigma=1.8, size=n_fraud)

# V1-V28 features (PCA components) - normally distributed for normal, shifted for fraud
v_features_normal = np.random.randn(n_normal, 28)
v_features_fraud = np.random.randn(n_fraud, 28) + np.random.randn(28) * 2  # shifted distribution

# Combine
time = np.concatenate([time_normal, time_fraud])
amount = np.concatenate([amount_normal, amount_fraud])
v_features = np.concatenate([v_features_normal, v_features_fraud])
labels = np.concatenate([np.zeros(n_normal), np.ones(n_fraud)])

# Shuffle
indices = np.random.permutation(n_samples)
time = time[indices]
amount = amount[indices]
v_features = v_features[indices]
labels = labels[indices]

# Create DataFrame
columns = ['Time'] + [f'V{i}' for i in range(1, 29)] + ['Amount', 'Class']
data = np.column_stack([time, v_features, amount, labels])
df = pd.DataFrame(data, columns=columns)

# Save
output_path = Path(__file__).parent / "data" / "creditcard.csv"
df.to_csv(output_path, index=False)
print(f"Generated {len(df)} transactions with {labels.sum():.0f} frauds ({labels.mean():.3%})")
print(f"Saved to {output_path}")
print(f"Columns: {list(df.columns)}")
print(f"Shape: {df.shape}")