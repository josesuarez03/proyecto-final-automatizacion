from locust import HttpUser, task, between

class TaskAPIUser(HttpUser):
    wait_time = between(1, 3)
    
    @task(2)
    def get_tasks(self):
        self.client.get("/api/tasks")
    
    @task(1)
    def create_task(self):
        self.client.post("/api/tasks", 
            json={
                "title": "Load Test Task",
                "description": "Created during load testing"
            }
        )