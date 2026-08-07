# /// script
# requires-python = ">=3.10"
# dependencies = ["pandas", "scikit-learn", "joblib", "mlflow"]
# ///
"""Trains the fraud detection model and saves it to model.pkl.

Run with:  uv run train.py
"""

from pathlib import Path

import joblib
import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split

BASE_DIR = Path(__file__).parent
DATA_PATH = BASE_DIR / "data" / "creditcard.csv"
MODEL_PATH = BASE_DIR / "model.pkl"

TARGET = "Class"  # 0 = normal transaction, 1 = fraud


def main() -> None:
    # Set MLflow tracking URI - use service name when running in Docker network
    mlflow.set_tracking_uri("http://mlflow:5000")
    mlflow.set_experiment("fraud-detection")

    df = pd.read_csv(DATA_PATH)
    X = df.drop(columns=[TARGET])  # the 30 features
    y = df[TARGET]

    print(f"{len(df)} transactions, including {y.sum()} frauds ({y.mean():.3%})")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=42
    )

    # Model parameters
    params = {
        "n_estimators": 100,
        "class_weight": "balanced",
        "n_jobs": -1,
        "random_state": 42,
    }

    model = RandomForestClassifier(**params)

    # IMPORTANT: we train on a DataFrame (not on a numpy array).
    # scikit-learn then remembers the name and order of the columns in
    # model.feature_names_in_, and that info goes into the .pkl.
    # This is what lets the API rebuild the input without getting it wrong.
    model.fit(X_train, y_train)

    print("\n=== Evaluation on the test set (20%) ===")
    report = classification_report(y_test, model.predict(X_test), target_names=["normal", "fraud"], output_dict=True)
    print(classification_report(y_test, model.predict(X_test), target_names=["normal", "fraud"]))

    # Log to MLflow
    with mlflow.start_run() as run:
        # Log parameters
        mlflow.log_params(params)
        
        # Log metrics
        mlflow.log_metric("accuracy", report["accuracy"])
        mlflow.log_metric("fraud_precision", report["fraud"]["precision"])
        mlflow.log_metric("fraud_recall", report["fraud"]["recall"])
        mlflow.log_metric("fraud_f1", report["fraud"]["f1-score"])
        mlflow.log_metric("normal_precision", report["normal"]["precision"])
        mlflow.log_metric("normal_recall", report["normal"]["recall"])
        mlflow.log_metric("normal_f1", report["normal"]["f1-score"])
        
        # Log model
        mlflow.sklearn.log_model(
            sk_model=model,
            artifact_path="model",
            registered_model_name="fraud-detection-model"
        )
        
        print(f"\nMLflow run ID: {run.info.run_id}")
        print(f"Model logged to MLflow")

    joblib.dump(model, MODEL_PATH, compress=3)
    print(f"Model saved: {MODEL_PATH.name} ({MODEL_PATH.stat().st_size / 1e6:.1f} MB)")
    print(f"Expected features ({len(model.feature_names_in_)}): {list(model.feature_names_in_)}")


if __name__ == "__main__":
    main()
