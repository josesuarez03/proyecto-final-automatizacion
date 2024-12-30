#Test task model
import pytest
from unittest.mock import Mock, patch
from src.models.task import Task

@pytest.fixture
def mock_db_connection():
    with patch('src.models.task.get_connection') as mock:
        connection = Mock()
        cursor = Mock()
        connection.cursor.return_value = cursor
        mock.return_value = connection
        yield mock

def test_create_task(mock_db_connection):
    # Arrange
    cursor = mock_db_connection.return_value.cursor.return_value
    cursor.lastrowid = 1
    
    # Act
    result = Task.create_task("Test Task", "Test Description")
    
    # Assert
    assert result == {"id": 1, "message": "Tarea creada exitosamente"}
    cursor.execute.assert_called_once()

def test_get_tasks(mock_db_connection):
    # Arrange
    cursor = mock_db_connection.return_value.cursor.return_value
    expected_tasks = [
        {"id": 1, "title": "Task 1", "description": "Desc 1", "completed": False},
        {"id": 2, "title": "Task 2", "description": "Desc 2", "completed": True}
    ]
    cursor.fetchall.return_value = expected_tasks
    
    # Act
    result = Task.get_tasks()
    
    # Assert
    assert result == expected_tasks