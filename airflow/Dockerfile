ARG AIRFLOW_VERSION=2.10.5
ARG PYTHON_VERSION=3.12

FROM apache/airflow:${AIRFLOW_VERSION}-python${PYTHON_VERSION}

ARG AIRFLOW_VERSION
ARG CONSTRAINTS_PYTHON_VERSION=3.12

COPY requirements.txt /requirements.txt

RUN curl --fail --silent --show-error \
      "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${CONSTRAINTS_PYTHON_VERSION}.txt" \
      --output /tmp/airflow-constraints.txt \
    && grep -v '^isodate==' /tmp/airflow-constraints.txt > /tmp/project-constraints.txt \
    && echo 'isodate==0.6.1' >> /tmp/project-constraints.txt \
    && pip install --no-cache-dir \
    --constraint /tmp/project-constraints.txt \
    "apache-airflow==${AIRFLOW_VERSION}" \
    -r /requirements.txt
