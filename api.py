# /// script
# requires-python = ">=3.10"
# dependencies = ["fastapi", "uvicorn", "pandas", "scikit-learn", "joblib"]
# ///
"""FastAPI service that serves the fraud detection model.

Run with:  uv run api.py     then open http://127.0.0.1:8000/docs
"""

from contextlib import asynccontextmanager
from pathlib import Path

import joblib
import pandas as pd
import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel

MODEL_PATH = Path(__file__).parent / "model.pkl"

model = None  # filled in at startup by lifespan()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # The model is loaded ONLY ONCE, when the API starts up.
    # Loading it inside /predict would reload the .pkl on every request (~1s): way too slow.
    # NB: a .pkl can execute code when opened, so only load files you trust.
    # Here it is the one produced by our own train.py.
    global model
    model = joblib.load(MODEL_PATH)
    print(f"Model loaded: {len(model.feature_names_in_)} features expected")
    yield
    # After the yield = code run when the API shuts down (nothing to clean up here).


app = FastAPI(title="Fraud Detection API", lifespan=lifespan)


class Transaction(BaseModel):
    """The 30 dataset columns, without the Class column which is what we predict."""

    Time: float
    V1: float
    V2: float
    V3: float
    V4: float
    V5: float
    V6: float
    V7: float
    V8: float
    V9: float
    V10: float
    V11: float
    V12: float
    V13: float
    V14: float
    V15: float
    V16: float
    V17: float
    V18: float
    V19: float
    V20: float
    V21: float
    V22: float
    V23: float
    V24: float
    V25: float
    V26: float
    V27: float
    V28: float
    Amount: float

    # Example pre-filled in /docs: a real fraud from the dataset.
    # Just click "Try it out" then "Execute" to test the API.
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "Time": 406.0, "V1": -2.3122, "V2": 1.952, "V3": -1.6099,
                    "V4": 3.9979, "V5": -0.5222, "V6": -1.4265, "V7": -2.5374,
                    "V8": 1.3917, "V9": -2.7701, "V10": -2.7723, "V11": 3.202,
                    "V12": -2.8999, "V13": -0.5952, "V14": -4.2893, "V15": 0.3897,
                    "V16": -1.1407, "V17": -2.8301, "V18": -0.0168, "V19": 0.417,
                    "V20": 0.1269, "V21": 0.5172, "V22": -0.035, "V23": -0.4652,
                    "V24": 0.3202, "V25": 0.0445, "V26": 0.1778, "V27": 0.2611,
                    "V28": -0.1433, "Amount": 0.0,
                }
            ]
        }
    }


class Prediction(BaseModel):
    fraud: bool
    fraud_probability: float


@app.get("/")
def home() -> dict:
    """Checks that the API is running and that the model is properly loaded."""
    return {"status": "ok", "model_loaded": model is not None}


@app.get("/features")
def features() -> list[str]:
    """The columns expected by the model, in order. Useful for debugging."""
    return list(model.feature_names_in_)


@app.post("/predict")
def predict(transaction: Transaction) -> Prediction:
    """Predicts whether a transaction is fraudulent."""
    # The part that always trips people up: scikit-learn wants the same columns, in the
    # SAME ORDER as during training. So we build a single-row DataFrame, then reorder
    # its columns using model.feature_names_in_ (the list stored in the .pkl) instead
    # of relying on getting the order right by hand.
    X = pd.DataFrame([transaction.model_dump()])[model.feature_names_in_]

    predicted_class = int(model.predict(X)[0])
    # predict_proba returns [proba_class_0, proba_class_1]: we want column 1 (fraud).
    proba = float(model.predict_proba(X)[0][1])

    return Prediction(fraud=bool(predicted_class), fraud_probability=round(proba, 4))


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
