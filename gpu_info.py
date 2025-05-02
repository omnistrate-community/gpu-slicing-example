from flask import Flask
import subprocess
import platform
from datetime import datetime

app = Flask(__name__)

def get_gpu_info():
    if platform.system() == 'Darwin':
        return {
            'status': 'info',
            'message': """
╔════════════════════════════════════════════════════════╗
║                   System Information                    ║
╠════════════════════════════════════════════════════════╣
║  • Operating System: macOS                             ║
║  • GPU Status: Not Available                           ║
║  • Reason: GPU monitoring is not supported on macOS    ║
║                                                        ║
║  The application is running in compatibility mode.      ║
║  For GPU monitoring, please use a Linux system with    ║
║  NVIDIA GPU and proper drivers installed.              ║
╚════════════════════════════════════════════════════════╝""",
            'gpu_count': 0,
            'gpus': []
        }
        
    try:
        # Run nvidia-smi to get GPU information
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
        return {'status': 'success', 'gpu_count': len(gpus), 'gpus': gpus}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}

def generate_html(gpu_data):
    ascii_art = """
    ╔══════════════════════════════════════════════════════════════════════════╗
    ║                              GPU MONITOR                                 ║
    ║                                                                          ║
    ║     ░░░░░░  ░░░░░░  ░░    ░░      ░░░░░░  ░░░░░░  ░░░░░░  ░░░░░░         ║
    ║    ▒▒      ▒▒    ▒▒ ▒▒    ▒▒     ▒▒      ▒▒    ▒▒   ▒▒    ▒▒    ▒▒       ║
    ║    ▒▒  ▒▒▒ ▒▒▒▒▒▒   ▒▒    ▒▒     ▒▒▒▒▒▒  ▒▒▒▒▒▒    ▒▒    ▒▒▒▒▒▒          ║
    ║    ▓▓    ▓ ▓▓       ▓▓    ▓▓     ▓▓      ▓▓  ▓▓    ▓▓    ▓▓  ▓▓          ║
    ║     █████   █████    ██████       ██████  ██    ██  ██    ██    ██       ║
    ║                                                                          ║
    ║                          [ SYSTEM STATUS ]                               ║
    ║                                                                          ║
    ║     ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗          ║
    ║     ║███║ ║███║ ║███║ ║███║ ║███║ ║███║ ║███║ ║███║ ║███║ ║███║          ║
    ║     ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝          ║
    ║                                                                          ║
    ╚══════════════════════════════════════════════════════════════════════════╝
    """
    
    css = """
        <style>
            body {
                background-color: #000;
                color: #0f0;
                font-family: 'Courier New', monospace;
                margin: 20px;
                padding: 20px;
                border: 2px solid #0f0;
            }
            h1 {
                text-align: center;
                text-shadow: 0 0 5px #0f0;
                animation: glow 1s ease-in-out infinite alternate;
            }
            .gpu-box {
                border: 1px solid #0f0;
                margin: 10px 0;
                padding: 15px;
                background-color: #001100;
                animation: pulse 2s infinite;
            }
            .stat-line {
                margin: 5px 0;
            }
            @keyframes glow {
                from { text-shadow: 0 0 5px #0f0; }
                to { text-shadow: 0 0 20px #0f0; }
            }
            @keyframes pulse {
                0% { border-color: #0f0; }
                50% { border-color: #040; }
                100% { border-color: #0f0; }
            }
            .ascii-art {
                white-space: pre;
                font-size: 12px;
                color: #0f0;
                text-align: center;
                margin: 20px 0;
                text-shadow: 0 0 5px #0f0;
            }
            .last-update {
                text-align: center;
                font-size: 0.8em;
                margin-top: 20px;
                color: #0a0;
                border-top: 1px solid #030;
                padding-top: 10px;
            }
        </style>
    """
    
    html_content = f"""
    <html>
        <head>
            <title>Retro GPU Monitor</title>
            <meta http-equiv="refresh" content="5">
            {css}
        </head>
        <body>
            <div class="ascii-art">{ascii_art}</div>
    """
    
    if gpu_data['status'] == 'success':
        html_content += f"<h1>Found {gpu_data['gpu_count']} GPU(s)</h1>"
        for i, gpu in enumerate(gpu_data['gpus'], 1):
            html_content += f"""
            <div class="gpu-box">
                <div class="stat-line">╔═ GPU #{i}: {gpu['name']}</div>
                <div class="stat-line">╠══ Total Memory: {gpu['memory']['total']} MB</div>
                <div class="stat-line">╠══ Used Memory: {gpu['memory']['used']} MB</div>
                <div class="stat-line">╠══ Free Memory: {gpu['memory']['free']} MB</div>
                <div class="stat-line">╚══ Temperature: {gpu['temperature']}°C</div>
            </div>
            """
    elif gpu_data['status'] == 'info':
        html_content += f"""
        <div class="gpu-box">
            <div class="stat-line">{gpu_data['message']}</div>
        </div>
        """
    else:
        html_content += f"""
        <div class="gpu-box">
            <div class="stat-line">Error: {gpu_data['message']}</div>
        </div>
        """
    
    # Add last update timestamp
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    html_content += f"""
            <div class="last-update">Last Updated: {current_time}</div>
        </body>
    </html>
    """
    return html_content

@app.route('/')
def home():
    gpu_data = get_gpu_info()
    return generate_html(gpu_data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)