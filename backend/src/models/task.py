from src.database.database import get_connection
from datetime import datetime

class Task:
    @staticmethod
    def create_table():
        """Crea la tabla tasks si no existe."""
        try:
            connection = get_connection()
            cursor = connection.cursor()
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS tasks (
                id INT AUTO_INCREMENT PRIMARY KEY,
                title VARCHAR(100) NOT NULL,
                description TEXT,
                completed BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """)
            connection.commit()
            cursor.close()
            connection.close()
            print("Tabla 'tasks' creada o ya existe.")
        except Exception as e:
            print(f"Error al crear la tabla 'tasks': {e}")

    @staticmethod
    def create_task(title, description):
        """Inserta una nueva tarea en la tabla."""
        try:
            connection = get_connection()
            cursor = connection.cursor()
            query = """
            INSERT INTO tasks (title, description)
            VALUES (%s, %s)
            """
            cursor.execute(query, (title, description))
            connection.commit()
            task_id = cursor.lastrowid
            cursor.close()
            connection.close()
            return {"id": task_id, "message": "Tarea creada exitosamente"}
        except Exception as e:
            return {"error": f"Error al insertar tarea: {e}"}

    @staticmethod
    def get_tasks():
        """Obtiene todas las tareas."""
        try:
            connection = get_connection()
            cursor = connection.cursor(dictionary=True)
            cursor.execute("SELECT * FROM tasks ORDER BY created_at DESC")
            tasks = cursor.fetchall()
            cursor.close()
            connection.close()
            return tasks
        except Exception as e:
            return {"error": f"Error al obtener tareas: {e}"}

    @staticmethod
    def update_task(task_id, title, description):
        """Actualiza una tarea existente."""
        try:
            connection = get_connection()
            cursor = connection.cursor()
            query = """
            UPDATE tasks 
            SET title = %s, description = %s
            WHERE id = %s
            """
            cursor.execute(query, (title, description, task_id))
            connection.commit()
            cursor.close()
            connection.close()
            return {"message": "Tarea actualizada exitosamente"}
        except Exception as e:
            return {"error": f"Error al actualizar tarea: {e}"}

    @staticmethod
    def delete_task(task_id):
        """Elimina una tarea."""
        try:
            connection = get_connection()
            cursor = connection.cursor()
            cursor.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
            connection.commit()
            cursor.close()
            connection.close()
            return {"message": "Tarea eliminada exitosamente"}
        except Exception as e:
            return {"error": f"Error al eliminar tarea: {e}"}

    @staticmethod
    def toggle_task(task_id, completed):
        """Cambia el estado de completado de una tarea."""
        try:
            connection = get_connection()
            cursor = connection.cursor()
            query = """
            UPDATE tasks 
            SET completed = %s
            WHERE id = %s
            """
            cursor.execute(query, (completed, task_id))
            connection.commit()
            cursor.close()
            connection.close()
            return {"message": "Estado de tarea actualizado exitosamente"}
        except Exception as e:
            return {"error": f"Error al actualizar estado de tarea: {e}"}