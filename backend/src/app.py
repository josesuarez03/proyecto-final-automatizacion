from flask import Flask, request
from prometheus_client import make_wsgi_app, Counter, Histogram
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from src.models.task import Task
from src.routes.routes import task_bp
import time
import logging
from logging.handlers import RotatingFileHandler
import os
from flask_cors import CORS

# Métricas personalizadas
REQUEST_COUNT = Counter(
    'app_requests_total', 
    'Total de solicitudes por endpoint', 
    ['method', 'endpoint', 'http_status']
)

REQUEST_LATENCY = Histogram(
    'app_request_latency_seconds', 
    'Latencia de las solicitudes por endpoint',
    ['method', 'endpoint']
)

def configure_logging(app):
    # Ensure log directory exists
    log_dir = '/var/log/flask'
    os.makedirs(log_dir, exist_ok=True)

    # Configure file handler
    file_handler = RotatingFileHandler(
        os.path.join(log_dir, 'app.log'), 
        maxBytes=10 * 1024 * 1024,  # 10 MB
        backupCount=5
    )

    # Log format with additional context
    formatter = logging.Formatter(
        '%(asctime)s [%(levelname)s] in %(module)s (%(pathname)s:%(lineno)d): %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    file_handler.setFormatter(formatter)

    # Set log level
    file_handler.setLevel(logging.INFO)

    # Add handlers to app logger
    app.logger.addHandler(file_handler)
    app.logger.setLevel(logging.INFO)

    # Optional: Add console handler for local development
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    console_handler.setLevel(logging.DEBUG)
    app.logger.addHandler(console_handler)

def setup_error_handlers(app):
    @app.errorhandler(Exception)
    def handle_exception(e):
        app.logger.error(f"Unhandled Exception: {str(e)}", exc_info=True)
        return 'Internal Server Error', 500

def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = 'your_secret_key'

    CORS(app)

    # Crear tablas a través de los modelos
    Task.create_table()

    # Registrar rutas
    app.register_blueprint(task_bp)

    # Middleware de Prometheus
    app.wsgi_app = DispatcherMiddleware(app.wsgi_app, {
        '/metrics': make_wsgi_app()
    })

    # Middleware para rastrear métricas
    @app.before_request
    def before_request():
        request.start_time = time.time()
        app.logger.info(f"Request started: {request.method} {request.path}")

    @app.after_request
    def after_request(response):
        latency = time.time() - request.start_time

         # Logging de la solicitud
        app.logger.info(
            f"Request completed: {request.method} {request.path} - "
            f"Status {response.status_code} - Latency {latency:.4f}s"
        )

        REQUEST_COUNT.labels(
            method=request.method, 
            endpoint=request.path, 
            http_status=response.status_code
        ).inc()
        REQUEST_LATENCY.labels(
            method=request.method, 
            endpoint=request.path
        ).observe(latency)
        return response

    return app