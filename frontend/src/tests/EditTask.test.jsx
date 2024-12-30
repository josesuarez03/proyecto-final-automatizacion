import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { EditTaskPage } from './EditTaskPage'
import { BrowserRouter as Router } from 'react-router-dom'
import { useGetTask, useUpdateTask } from '../hooks/useTaskApi'
import { describe, it, expect, beforeEach, vi } from 'vitest'

// Mock de los hooks
vi.mock('../hooks/useTaskApi')

describe('EditTaskPage', () => {
  const mockNavigate = vi.fn()
  
  // Mock del hook useNavigate
  vi.mock('react-router-dom', () => ({
    useNavigate: () => mockNavigate,
    useParams: () => ({ id: '1' }),
  }))

  const mockTask = {
    id: '1',
    title: 'Test Task',
    description: 'Test description'
  }

  beforeEach(() => {
    useGetTask.mockReturnValue({ data: mockTask })
    useUpdateTask.mockReturnValue({ mutate: vi.fn() })
  })

  it('should render task form with initial data', () => {
    render(
      <Router>
        <EditTaskPage />
      </Router>
    )

    expect(screen.getByLabelText(/Title/)).toHaveValue(mockTask.title)
    expect(screen.getByLabelText(/Description/)).toHaveValue(mockTask.description)
  })

  it('should call the update task mutation on form submission', async () => {
    const mockMutate = vi.fn()
    useUpdateTask.mockReturnValue({ mutate: mockMutate })
    
    render(
      <Router>
        <EditTaskPage />
      </Router>
    )

    const titleInput = screen.getByLabelText(/Title/)
    const descriptionInput = screen.getByLabelText(/Description/)
    const submitButton = screen.getByText(/Actualizar Tarea/)

    fireEvent.change(titleInput, { target: { value: 'Updated Task' } })
    fireEvent.change(descriptionInput, { target: { value: 'Updated description' } })

    fireEvent.click(submitButton)

    // Verificar que la mutación se haya llamado con los datos correctos
    await waitFor(() => {
      expect(mockMutate).toHaveBeenCalledWith({
        ...mockTask,
        title: 'Updated Task',
        description: 'Updated description'
      })
    })
  })

  it('should navigate to the home page on success', async () => {
    const mockMutate = vi.fn()
    useUpdateTask.mockReturnValue({ mutate: mockMutate })

    render(
      <Router>
        <EditTaskPage />
      </Router>
    )

    const titleInput = screen.getByLabelText(/Title/)
    const descriptionInput = screen.getByLabelText(/Description/)
    const submitButton = screen.getByText(/Actualizar Tarea/)

    fireEvent.change(titleInput, { target: { value: 'Updated Task' } })
    fireEvent.change(descriptionInput, { target: { value: 'Updated description' } })

    fireEvent.click(submitButton)

    // Verificar que la navegación ocurra después de la mutación exitosa
    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith('/')
    })
  })

  it('should not render if the task is not found', () => {
    useGetTask.mockReturnValue({ data: null })
    
    render(
      <Router>
        <EditTaskPage />
      </Router>
    )

    expect(screen.queryByText(/Editar Tarea/)).toBeNull()
  })
})