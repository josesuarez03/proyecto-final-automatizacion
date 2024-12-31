import pytest
import json
from src.app import create_app
from src.models.task import Task
from src.database.database import get_connection
import logging

# Configurar logging para los tests
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

@pytest.fixture(scope="module")
def test_client():
    """Fixture que proporciona un cliente de prueba Flask"""
    app = create_app()
    app.config['TESTING'] = True
    app.config['DEBUG'] = False
    
    # Crear el cliente de prueba
    with app.test_client() as testing_client:
        with app.app_context():
            # Crear la tabla de tareas para las pruebas
            Task.create_table()
        yield testing_client

@pytest.fixture(autouse=True)
def cleanup():
    """Fixture para limpiar la base de datos después de cada test"""
    yield
    try:
        connection = get_connection()
        cursor = connection.cursor()
        cursor.execute("DELETE FROM tasks")
        connection.commit()
        cursor.close()
        connection.close()
    except Exception as e:
        logger.error(f"Error cleaning up database: {e}")

def test_complete_task_workflow(test_client):
    """Test del flujo completo de trabajo con tareas"""
    try:
        # 1. Crear una tarea
        logger.info("Iniciando prueba de creación de tarea")
        create_response = test_client.post('/api/tasks',
                                    json={
                                        "title": "Workflow Test Task",
                                        "description": "Testing complete workflow"
                                    })
        assert create_response.status_code == 200, "Error creating task"
        task_data = json.loads(create_response.data)
        task_id = task_data["id"]
        
        # 2. Verificar que la tarea existe
        logger.info(f"Verificando existencia de tarea {task_id}")
        get_response = test_client.get('/api/tasks')
        assert get_response.status_code == 200, "Error getting tasks"
        tasks = json.loads(get_response.data)
        task_exists = any(task["id"] == task_id for task in tasks)
        assert task_exists, f"Task {task_id} not found in tasks list"
        
        # 3. Actualizar la tarea
        logger.info(f"Actualizando tarea {task_id}")
        update_response = test_client.put(f'/api/tasks/{task_id}',
                                   json={
                                       "title": "Updated Task",
                                       "description": "Updated description"
                                   })
        assert update_response.status_code == 200, "Error updating task"
        
        # Verificar que la actualización fue exitosa
        get_updated = test_client.get('/api/tasks')
        updated_tasks = json.loads(get_updated.data)
        updated_task = next((task for task in updated_tasks if task["id"] == task_id), None)
        assert updated_task["title"] == "Updated Task", "Task title not updated"
        assert updated_task["description"] == "Updated description", "Task description not updated"
        
        # 4. Marcar como completada
        logger.info(f"Marcando tarea {task_id} como completada")
        toggle_response = test_client.patch(f'/api/tasks/{task_id}/toggle',
                                     json={"completed": True})
        assert toggle_response.status_code == 200, "Error toggling task"
        
        # Verificar que el estado cambió
        get_toggled = test_client.get('/api/tasks')
        toggled_tasks = json.loads(get_toggled.data)
        toggled_task = next((task for task in toggled_tasks if task["id"] == task_id), None)
        assert toggled_task["completed"] is True, "Task not marked as completed"
        
        # 5. Eliminar la tarea
        logger.info(f"Eliminando tarea {task_id}")
        delete_response = test_client.delete(f'/api/tasks/{task_id}')
        assert delete_response.status_code == 200, "Error deleting task"
        
        # Verificar que la tarea fue eliminada
        get_after_delete = test_client.get('/api/tasks')
        remaining_tasks = json.loads(get_after_delete.data)
        task_still_exists = any(task["id"] == task_id for task in remaining_tasks)
        assert not task_still_exists, "Task not properly deleted"
        
    except Exception as e:
        logger.error(f"Test failed: {str(e)}")
        raise

    logger.info("Test de flujo completo finalizado exitosamente")