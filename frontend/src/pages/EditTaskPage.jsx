import { useNavigate, useParams } from 'react-router-dom'
import { TaskForm } from '../components/TaskForm'
import { useGetTask, useUpdateTask } from '../hooks/useTaskApi'
import React from 'react'

export const EditTaskPage = () => {
  const { id } = useParams()
  const navigate = useNavigate()
  const { data: task } = useGetTask(id)
  const mutation = useUpdateTask()
  
  const handleSubmit = (data) => {
    mutation.mutate({ ...task, ...data }, {
      onSuccess: () => navigate('/')
    })
  }
  
  if (!task) return null
  
  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Editar Tarea</h1>
      <TaskForm
        initialData={task}
        onSubmit={handleSubmit}
        buttonText="Actualizar Tarea"
      />
    </div>
  )
}