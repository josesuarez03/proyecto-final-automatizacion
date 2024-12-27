import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

const BASE_URL = '/api'

const api = {
  getTasks: () => fetch(`${BASE_URL}/tasks`).then(res => res.json()),
  createTask: (task) => fetch(`${BASE_URL}/tasks`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(task)
  }).then(res => res.json()),
  updateTask: (task) => fetch(`${BASE_URL}/tasks/${task.id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(task)
  }).then(res => res.json()),
  deleteTask: (id) => fetch(`${BASE_URL}/tasks/${id}`, {
    method: 'DELETE'
  }).then(res => res.json()),
  toggleComplete: (id, completed) => fetch(`${BASE_URL}/tasks/${id}/toggle`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ completed })
  }).then(res => res.json())
}

export const useGetTasks = () => {
  return useQuery({
    queryKey: ['tasks'],
    queryFn: api.getTasks
  })
}

export const useGetTask = (id) => {
  return useQuery({
    queryKey: ['task', id],
    queryFn: () => api.getTasks().then(tasks => tasks.find(t => t.id === parseInt(id))),
    enabled: !!id
  })
}

export const useCreateTask = () => {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: api.createTask,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] })
    }
  })
}

export const useUpdateTask = () => {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: api.updateTask,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] })
    }
  })
}

export const useDeleteTask = () => {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: api.deleteTask,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] })
    }
  })
}

export const useToggleTask = () => {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, completed }) => api.toggleComplete(id, completed),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] })
    }
  })
}