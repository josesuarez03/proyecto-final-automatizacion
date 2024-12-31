import { useNavigate } from 'react-router-dom'
import { TaskForm } from '../components/TaskForm'
import { useCreateTask } from '../hooks/useTaskApi'
import React from 'react'

export const CreateTaskPage = () => {
  const navigate = useNavigate()
  const mutation = useCreateTask()
  
  const handleSubmit = (data) => {
    mutation.mutate({ ...data, completed: false }, {
      onSuccess: () => navigate('/')
    })
  }
  
  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Nueva Tarea</h1>
      <TaskForm
        onSubmit={handleSubmit}
        buttonText="Crear Tarea"
      />
    </div>
  )
}