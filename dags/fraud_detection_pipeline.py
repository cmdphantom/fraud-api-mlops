"""
Fraud Detection Pipeline DAG

This DAG orchestrates the fraud detection ML pipeline:
1. Generate synthetic data (if needed)
2. Train the model
3. Log model and metrics to MLflow
4. Deploy model (build Docker image)
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.docker.operators.docker import DockerOperator
from docker.types import Mount

default_args = {
    'owner': 'ml-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'fraud_detection_pipeline',
    default_args=default_args,
    description='Fraud detection ML pipeline with MLflow tracking',
    schedule_interval='@daily',
    catchup=False,
    tags=['ml', 'fraud-detection', 'mlflow'],
)

# Task 1: Generate synthetic data
generate_data = BashOperator(
    task_id='generate_data',
    bash_command='cd /opt/airflow && python generate_data.py',
    dag=dag,
)

# Task 2: Train model and log to MLflow
train_model = BashOperator(
    task_id='train_model',
    bash_command='cd /opt/airflow && python train.py',
    dag=dag,
)

# Task 3: Build Docker image for API
build_docker_image = DockerOperator(
    task_id='build_docker_image',
    image='docker:24.0.5-dind',
    api_version='auto',
    auto_remove=True,
    command='build -t fraud-api:{{ ds }} /opt/airflow',
    docker_url='unix:///var/run/docker.sock',
    network_mode='bridge',
    mounts=[
        Mount(source='/var/run/docker.sock', target='/var/run/docker.sock', type='bind'),
    ],
    dag=dag,
)

# Task 4: Test API endpoint
test_api = BashOperator(
    task_id='test_api',
    bash_command='''
    sleep 10 && \
    curl -X POST http://api:8000/predict \
    -H "Content-Type: application/json" \
    -d '{"features": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 100.0]}'
    ''',
    dag=dag,
)

# Task 5: Push to registry (for production deployment)
push_to_registry = BashOperator(
    task_id='push_to_registry',
    bash_command='''
    echo "Tagging and pushing image to registry..."
    # docker tag fraud-api:{{ ds }} your-registry/fraud-api:{{ ds }}
    # docker push your-registry/fraud-api:{{ ds }}
    echo "Image ready for deployment to Render or other platform"
    ''',
    dag=dag,
)

# Define task dependencies
generate_data >> train_model >> build_docker_image >> test_api >> push_to_registry