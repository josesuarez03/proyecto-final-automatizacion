import { render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import { CreateTaskPage } from '../pages/CreateTaskPage'
import { useCreateTask } from '../hooks/useTaskApi'
import { describe, it, expect, beforeEach, vi } from 'vitest'
import React from 'react'

vi.mock('../hooks/useTaskApi', () => ({
  useCreateTask: vi.fn(() => ({ mutate: vi.fn() }))
}))

vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom')
  return {
    ...actual,
    useNavigate: vi.fn()
  }
})

function renderWithProviders(component) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false
      }
    }
  })
  
  return render(
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        {component}
      </BrowserRouter>
    </QueryClientProvider>
  )
}

describe('CreateTaskPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    renderWithProviders(<CreateTaskPage />)
  })

  it('renders title correctly', () => {
    const title = screen.getByText('Nueva Tarea')
    expect(title).toBeInTheDocument()
  })

  it('renders form fields', () => {
    const titleInput = screen.getByLabelText('Título')
    const descriptionInput = screen.getByLabelText('Descripción')
    
    expect(titleInput).toBeInTheDocument()
    expect(descriptionInput).toBeInTheDocument()
  })

  it('renders submit button', () => {
    const submitButton = screen.getByText('Crear Tarea')
    expect(submitButton).toBeInTheDocument()
  })
})
