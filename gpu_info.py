from flask import Flask, jsonify
import subprocess
import platform
from datetime import datetime

app = Flask(__name__)

def get_gpu_info():
    if platform.system() == 'Darwin':
        return {
            'status': 'info',
            'timestamp': datetime.now().isoformat(),
            'message': 'GPU monitoring is not supported on macOS',
            'system': {
                'os': 'macOS',
                'gpu_support': False
            },
            'gpu_count': 0,
            'gpus': []
        }
        
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=name,memory.total,memory.used,memory.free,temperature.gpu', 
                               '--format=csv,noheader,nounits'], capture_output=True, text=True)
        
        if result.returncode != 0:
            raise Exception("Failed to get GPU information")

        gpus = []
        for line in result.stdout.strip().split('\n'):
            if line.strip():
                name, total, used, free, temp = [x.strip() for x in line.split(',')]
                gpus.append({
                    'name': name,
                    'memory': {
                        'total': int(total),
                        'used': int(used),
                        'free': int(free)
                    },
                    'temperature': int(temp)
                })
        return {
            'status': 'success',
            'timestamp': datetime.now().isoformat(),
            'system': {
                'os': platform.system(),
                'gpu_support': True
            },
            'gpu_count': len(gpus),
            'gpus': gpus
        }
    except Exception as e:
        return {
            'status': 'error',
            'timestamp': datetime.now().isoformat(),
            'message': str(e),
            'system': {
                'os': platform.system(),
                'gpu_support': False
            },
            'gpu_count': 0,
            'gpus': []
        }

@app.route('/')
def home():
    return jsonify(get_gpu_info())

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)