FROM nvidia/cuda:12.3.1-base-ubuntu22.04

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
COPY gpu_info.py .

RUN pip3 install -r requirements.txt

EXPOSE 5000
CMD ["python3", "gpu_info.py"]