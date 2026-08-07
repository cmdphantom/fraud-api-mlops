# /// script
# requires-python = ">=3.10"
# dependencies = ["pandas", "scikit-learn", "joblib", "mlflow"]
# ///
"""Load existing model.pkl and log it to MLflow."""

from pathlib import Path

import joblib
import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split

BASE_DIR = Path(__file__).parent
MODEL_PATH = BASE_DIR / "model.pkl"
DATA_PATH = BASE_DIR / "data" / "creditcard.csv"

TARGET = "Class"


def main() -> None:
    # Set MLflow tracking URI
    mlflow.set_tracking_uri("http://mlflow:5000")
    mlflow.set_experiment("fraud-detection")

    # Load existing model
    model = joblib.load(MODEL_PATH)
    print(f"Model loaded: {len(model.feature_names_in_)} features expected")

    # Try to load data for evaluation (optional)
    if DATA_PATH.exists():
        df = pd.read_csv(DATA_PATH)
        X = df.drop(columns=[TARGET])
        y = df[TARGET]

        print(f"{len(df)} transactions, including {y.sum()} frauds ({y.mean():.3%})")

        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, stratify=y, random_state=42
        )

        print("\n=== Evaluation on the test set (20%) ===")
        report = classification_report(y_test, model.predict(X_test), target_names=["normal", "fraud"], output_dict=True)
        print(classification_report(y_test, model.predict(X_test), target_names=["normal", "fraud"]))

        # Log to MLflow
        with mlflow.start_run() as run:
            # Log parameters from the model
            params = {
                "n_estimators": model.n_estimators,
                "class_weight": model.class_weight,
                "random_state": model.random_state,
            }
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
    else:
        print("Data file not found, logging model without evaluation metrics")
        # Log to MLflow without metrics
        with mlflow.start_run() as run:
            params = {
                "n_estimators": model.n_estimators,
                "class_weight": model.class_weight,
                "random_state": model.random_state,
            }
            mlflow.log_params(params)
            
            # Log model
            mlflow.sklearn.log_model(
                sk_model=model,
                artifact_path="model",
                registered_model_name="fraud-detection-model"
            )
            
            print(f"\nMLflow run ID: {run.info.run_id}")
            print(f"Model logged to MLflow (without evaluation metrics)")


if __name__ == "__main__":
    main()