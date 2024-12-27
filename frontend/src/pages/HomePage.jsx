import { Link } from 'react-router-dom'
import { Plus } from 'lucide-react'
import { TaskCard } from '../components/TaskCard'
import { useGetTasks, useDeleteTask, useToggleTask } from '../hooks/useTaskApi'

export const HomePage = () => {
  const { data: tasks = [] } = useGetTasks()
  const deleteMutation = useDeleteTask()
  const toggleMutation = useToggleTask()
  
  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">Mis Tareas</h1>
        <Link
          to="/create"
          className="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
        >
          <Plus size={20} className="mr-2" />
          Nueva Tarea
        </Link>
      </div>
      
      <div className="space-y-4">
        {tasks.map(task => (
          <TaskCard
            key={task.id}
            task={task}
            onDelete={() => deleteMutation.mutate(task.id)}
            onToggle={toggleMutation.mutate}
          />
        ))}
        {tasks.length === 0 && (
          <p className="text-center text-gray-500 py-8">No hay tareas pendientes</p>
        )}
      </div>
    </div>
  )
}