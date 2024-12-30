import { render, screen} from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import { HomePage } from '../pages/HomePage'
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { useGetTasks } from '../hooks/useTaskApi'

const mockTasks = [
  { id: 1, title: 'Tarea 1', description: 'Descripción 1', completed: false },
  { id: 2, title: 'Tarea 2', description: 'Descripción 2', completed: true }
]

vi.mock('../hooks/useTaskApi', () => ({
  useGetTasks: () => ({ data: mockTasks }),
  useDeleteTask: () => ({ 
    mutate: vi.fn()
  }),
  useToggleTask: () => ({
    mutate: vi.fn()
  })
}))

const renderWithProviders = (component) => {
  const queryClient = new QueryClient()
  return render(
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        {component}
      </BrowserRouter>
    </QueryClientProvider>
  )
}

describe('HomePage', () => {
  beforeEach(() => {
    renderWithProviders(<HomePage />)
  })

  it('renders title correctly', () => {
    expect(screen.getByText('Mis Tareas')).toBeInTheDocument()
  })

  it('renders create task button', () => {
    const createButton = screen.getByText('Nueva Tarea')
    expect(createButton).toBeInTheDocument()
    expect(createButton.closest('a')).toHaveAttribute('href', '/create')
  })

  it('renders task list', () => {
    mockTasks.forEach(task => {
      expect(screen.getByText(task.title)).toBeInTheDocument()
      expect(screen.getByText(task.description)).toBeInTheDocument()
    })
  })

  it('shows empty state when no tasks', () => {
    vi.mocked(useGetTasks).mockReturnValueOnce({ data: [] })
    renderWithProviders(<HomePage />)
    expect(screen.getByText('No hay tareas pendientes')).toBeInTheDocument()
  })
})