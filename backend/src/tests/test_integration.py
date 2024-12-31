import pytest
from src.app import create_app
import json

@pytest.fixture
def client():
    app = create_app()
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_create_task_integration(client):
    # Arrange
    task_data = {
        "title": "Integration Test Task",
        "description": "Testing task creation"
    }
    
    # Act
    response = client.post('/api/tasks', 
                         data=json.dumps(task_data),
                         content_type='application/json')
    
    # Assert
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "id" in data
    assert data["message"] == "Tarea creada exitosamente"

