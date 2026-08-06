# /// script
# requires-python = ">=3.10"
# dependencies = ["pandas", "scikit-learn", "joblib"]
# ///
"""Trains the fraud detection model and saves it to model.pkl.

Run with:  uv run train.py
"""

from pathlib import Path

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split

BASE_DIR = Path(__file__).parent
DATA_PATH = BASE_DIR / "data" / "creditcard.csv"
MODEL_PATH = BASE_DIR / "model.pkl"

TARGET = "Class"  # 0 = normal transaction, 1 = fraud


def main() -> None:
    df = pd.read_csv(DATA_PATH)
    X = df.drop(columns=[TARGET])  # the 30 features
    y = df[TARGET]

    print(f"{len(df)} transactions, including {y.sum()} frauds ({y.mean():.3%})")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=42
    )

    model = RandomForestClassifier(
        n_estimators=100,
        class_weight="balanced",  # the dataset is very imbalanced: 0.17% frauds
        n_jobs=-1,
        random_state=42,
    )

    # IMPORTANT: we train on a DataFrame (not on a numpy array).
    # scikit-learn then remembers the name and order of the columns in
    # model.feature_names_in_, and that info goes into the .pkl.
    # This is what lets the API rebuild the input without getting it wrong.
    model.fit(X_train, y_train)

    print("\n=== Evaluation on the test set (20%) ===")
    print(classification_report(y_test, model.predict(X_test), target_names=["normal", "fraud"]))

    joblib.dump(model, MODEL_PATH, compress=3)
    print(f"Model saved: {MODEL_PATH.name} ({MODEL_PATH.stat().st_size / 1e6:.1f} MB)")
    print(f"Expected features ({len(model.feature_names_in_)}): {list(model.feature_names_in_)}")


if __name__ == "__main__":
    main()
