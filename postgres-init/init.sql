-- Initialize databases for both MLflow and Airflow
-- This script runs when the postgres container starts for the first time

-- Create MLflow database and user (already done by POSTGRES_DB/POSTGRES_USER env vars)
-- But we'll ensure it exists
SELECT 'CREATE DATABASE mlflow' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mlflow')\gexec

-- Create Airflow database and user
SELECT 'CREATE DATABASE airflow' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'airflow')\gexec

-- Create airflow user if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'airflow') THEN
        CREATE ROLE airflow WITH LOGIN PASSWORD 'airflow';
    END IF;
END
$$;

-- Grant privileges to airflow user on airflow database
GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;

-- Grant privileges to mlflow user on mlflow database (should already have it)
GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;