from flask import Blueprint, request, jsonify
from backend.src.models.task import Task

task_bp = Blueprint('task', __name__)

@task_bp.route("/api/tasks", methods=["GET", "POST"])
def tasks():
    if request.method == "POST":
        data = request.get_json()
        title = data.get("title")
        description = data.get("description")

        if not title:
            return jsonify({"error": "El título es obligatorio"}), 400

        response = Task.create_task(title, description)
        return jsonify(response)

    # GET method
    tasks = Task.get_tasks()
    return jsonify(tasks)

@task_bp.route("/api/tasks/<int:task_id>", methods=["PUT", "DELETE"])
def task_operations(task_id):
    if request.method == "PUT":
        data = request.get_json()
        title = data.get("title")
        description = data.get("description")

        if not title:
            return jsonify({"error": "El título es obligatorio"}), 400

        response = Task.update_task(task_id, title, description)
        return jsonify(response)

    # DELETE method
    response = Task.delete_task(task_id)
    return jsonify(response)

@task_bp.route("/api/tasks/<int:task_id>/toggle", methods=["PATCH"])
def toggle_task(task_id):
    data = request.get_json()
    completed = data.get("completed")
    
    if completed is None:
        return jsonify({"error": "El estado 'completed' es requerido"}), 400

    response = Task.toggle_task(task_id, completed)
    return jsonify(response)