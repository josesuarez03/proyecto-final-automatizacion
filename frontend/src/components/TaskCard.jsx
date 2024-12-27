import { Link } from 'react-router-dom'
import { Trash2, Edit } from 'lucide-react'
import PropTypes from 'prop-types'

export const TaskCard = ({ task, onDelete, onToggle }) => {
  const timestamp = new Date(task.timestamp).toLocaleString()
  
  return (
    <div className="bg-white p-4 rounded-lg shadow-md">
      <div className="flex items-center gap-4">
        <input
          type="checkbox"
          checked={task.completed}
          onChange={(e) => onToggle(task.id, e.target.checked)}
          className="h-5 w-5 rounded border-gray-300"
        />
        <div className="flex-1">
          <h3 className={`text-lg font-semibold ${task.completed ? 'line-through text-gray-500' : ''}`}>
            {task.title}
          </h3>
          <p className="text-gray-600 mt-1">{task.description}</p>
          <p className="text-sm text-gray-400 mt-2">{timestamp}</p>
        </div>
        <div className="flex gap-2">
          <Link
            to={`/edit/${task.id}`}
            className="p-2 text-blue-600 hover:bg-blue-50 rounded-full"
          >
            <Edit size={20} />
          </Link>
          <button
            onClick={() => onDelete(task.id)}
            className="p-2 text-red-600 hover:bg-red-50 rounded-full"
          >
            <Trash2 size={20} />
          </button>
        </div>
      </div>
    </div>
  )
}

TaskCard.propTypes = {
  task: PropTypes.shape({
    id: PropTypes.number.isRequired,
    title: PropTypes.string.isRequired,
    description: PropTypes.string.isRequired,
    completed: PropTypes.bool.isRequired,
    timestamp: PropTypes.string.isRequired
  }).isRequired,
  onDelete: PropTypes.func.isRequired,
  onToggle: PropTypes.func.isRequired
}
