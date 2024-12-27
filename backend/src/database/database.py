import mysql.connector
from mysql.connector import Error
import time
import logging
from src.config import Config

def get_connection(max_retries=5):

    db_config = {
        'host': Config.DB_HOST,
        'user': Config.DB_USER,
        'password': Config.DB_PASSWORD,
        'database': Config.DB_NAME,
        'port': int(Config.DB_PORT)
    }
    
    for retry in range(max_retries):
        try:
            connection = mysql.connector.connect(**db_config)
            logging.info(f"Database connection successful on attempt {retry + 1}")
            return connection
        except Error as e:
            logging.error(f"Database connection error (attempt {retry + 1}/{max_retries}): {e}")
            if retry < max_retries - 1:
                time.sleep(5)  # Wait 5 seconds between retries
            else:
                logging.error("Failed to connect to the database")
                raise