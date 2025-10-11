# Modified app.py with Prometheus metrics support

from flask import Flask, jsonify, render_template, request, g
from datetime import datetime
import socket
import os
import json
import psycopg2
import time

# ============================================================================
# Prometheus Metrics Setup
# ============================================================================
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY, CONTENT_TYPE_LATEST

# Custom Metrics
http_requests_total = Counter(
    'catalogue_http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'catalogue_http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    buckets=(0.01, 0.05, 0.1, 0.5, 1, 2, 5)
)

db_connection_status = Gauge(
    'catalogue_db_connection_status',
    'Database connection status (1 = connected, 0 = disconnected)'
)

products_total = Gauge(
    'catalogue_products_total',
    'Total number of products in catalogue'
)

# ============================================================================
# App Setup
# ============================================================================
app = Flask(__name__)

# Load product data from JSON file
with open('products.json', 'r') as f:
    products = json.load(f)

products_total.set(len(products))

# Load configuration with environment variable support
def load_config():
    # Load base config from file
    with open("config.json", "r") as config_file:
        config_data = json.load(config_file)

    # Override with environment variables if they exist
    config_data["app_version"] = os.getenv("APP_VERSION", config_data.get("app_version", "1.0.0"))
    config_data["data_source"] = os.getenv("DATA_SOURCE", config_data.get("data_source", "json"))

    # Load database configuration
    # First try environment variables, then mounted db-config file, then config.json as fallback
    if os.path.exists('/app/db-config/db-config.properties'):
        db_config = {}
        with open('/app/db-config/db-config.properties', 'r') as f:
            for line in f:
                if '=' in line:
                    key, value = line.strip().split('=', 1)
                    db_config[key] = value

        config_data["db_host"] = db_config.get("db_host")
        config_data["db_name"] = db_config.get("db_name")

    # Check for secrets mounted by init container
    if os.path.exists('/app/secrets/db_user'):
        with open('/app/secrets/db_user', 'r') as f:
            config_data["db_user"] = f.read().strip()

    if os.path.exists('/app/secrets/db_password'):
        with open('/app/secrets/db_password', 'r') as f:
            config_data["db_password"] = f.read().strip()

    if os.path.exists('/app/secrets/db_host'):
        with open('/app/secrets/db_host', 'r') as f:
            config_data["db_host"] = f.read().strip()

    # Environment variables take precedence over all
    config_data["db_host"] = os.getenv("DB_HOST", config_data.get("db_host", "localhost"))
    config_data["db_name"] = os.getenv("DB_NAME", config_data.get("db_name", "catalogue"))
    config_data["db_user"] = os.getenv("DB_USER", config_data.get("db_user", "devops"))
    config_data["db_password"] = os.getenv("DB_PASSWORD", config_data.get("db_password", "devops"))

    return config_data

config_data = load_config()

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host=config_data.get("db_host"),
            database=config_data.get("db_name"),
            user=config_data.get("db_user"),
            password=config_data.get("db_password")
        )
        db_connection_status.set(1)
        return conn
    except Exception as e:
        db_connection_status.set(0)
        raise e

# ============================================================================
# Metrics Middleware
# ============================================================================
@app.before_request
def before_request():
    # Store start time
    g.start_time = time.time()

@app.after_request
def after_request(response):
    # Calculate duration
    if hasattr(g, 'start_time'):
        duration = time.time() - g.start_time

        # Get endpoint
        endpoint = request.endpoint or 'unknown'

        # Record metrics
        http_requests_total.labels(
            method=request.method,
            endpoint=endpoint,
            status=response.status_code
        ).inc()

        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=endpoint
        ).observe(duration)

    return response

# ============================================================================
# Metrics Endpoint
# ============================================================================
@app.route('/metrics')
def metrics():
    return generate_latest(REGISTRY), 200, {'Content-Type': CONTENT_TYPE_LATEST}

# ============================================================================
# Health Endpoint
# ============================================================================
@app.route('/health')
def health():
    return jsonify({'status': 'healthy'}), 200

# ============================================================================
# Application Routes
# ============================================================================
@app.route('/')
def home():
    system_info = get_system_info()
    app_version = config_data.get("app_version", "N/A")
    return render_template('index.html', current_year=datetime.now().year, system_info=system_info, version=app_version)

@app.route('/api/products', methods=['GET'])
def get_products():
    if (config_data.get("data_source") == "db"):
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute('SELECT * FROM products;')
            db_products = cur.fetchall()
            products_dict = [{'id': curr_product[0], 'description': curr_product[1], 'image_url': curr_product[2], 'name': curr_product[3]} for curr_product in db_products]
            products_total.set(len(products_dict))
            cur.close()
            conn.close()
            return jsonify(products_dict), 200
        except Exception as e:
            app.logger.error(f"Database error: {str(e)}")
            # Fallback to JSON in case of DB errors
            app.logger.info("Falling back to JSON data source")
            return jsonify(products), 200
    else:
        return jsonify(products), 200

@app.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    product = next((product for product in products if product['id'] == product_id), None)
    if product is not None:
        return jsonify(product)
    else:
        return jsonify({'message': 'Product not found'}), 404

def get_system_info():
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)

    # Additional logic for container and Kubernetes check
    is_container = os.path.exists('/.dockerenv')
    is_kubernetes = os.path.exists('/var/run/secrets/kubernetes.io/serviceaccount')

    return {
        "hostname": hostname,
        "ip_address": ip_address,
        "is_container": is_container,
        "is_kubernetes": is_kubernetes,
        "data_source": config_data.get("data_source", "json"),
        "db_host": config_data.get("db_host", "N/A") if config_data.get("data_source") == "db" else "N/A"
    }

if __name__ == "__main__":
    app.run(debug=True)
