import pytest
from src.app import create_app

@pytest.fixture
def client():
    app = create_app()
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_sql_injection_prevention(client):
    # Test SQL injection attempt in task creation
    malicious_title = "'; DROP TABLE tasks; --"
    response = client.post('/api/tasks',
                         json={
                             "title": malicious_title,
                             "description": "Test description"
                         })
    assert response.status_code != 500  # No debe causar error del servidor

def test_xss_prevention(client):
    # Test XSS attempt
    xss_payload = "<script>alert('xss')</script>"
    response = client.post('/api/tasks',
                         json={
                             "title": xss_payload,
                             "description": "Test description"
                         })
    
    # Verificar que el payload se guardó como texto plano
    tasks_response = client.get('/api/tasks')
    tasks = tasks_response.get_json()
    for task in tasks:
        assert "<script>" not in task["title"]