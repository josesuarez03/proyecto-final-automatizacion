import { render, screen } from '@testing-library/react';
import { EditTaskPage } from '../pages/EditTaskPage';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import React from 'react';

const mockNavigate = vi.fn();
const mockUpdateTask = vi.fn();

vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useNavigate: () => mockNavigate,
    useParams: () => ({ id: '1' }),
  };
});

vi.mock('../hooks/useTaskApi', () => ({
  useGetTask: () => ({
    data: { title: 'Sample Task', description: 'Sample description', id: '1' }
  }),
  useUpdateTask: () => ({ mutate: mockUpdateTask }),
}));

const renderWithProviders = (component) => {
  const queryClient = new QueryClient();
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>{component}</MemoryRouter>
    </QueryClientProvider>
  );
};

describe('EditTaskPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    renderWithProviders(<EditTaskPage />);
  });

  it('renders title correctly', () => {
    const title = screen.getByText('Editar Tarea');
    expect(title).toBeInTheDocument();
  });

  it('renders form fields', () => {
    const titleInput = screen.getByLabelText('Título');
    const descriptionInput = screen.getByLabelText('Descripción');
    
    expect(titleInput).toBeInTheDocument();
    expect(descriptionInput).toBeInTheDocument();
  });

  it('renders submit button', () => {
    const submitButton = screen.getByText('Actualizar Tarea');
    expect(submitButton).toBeInTheDocument();
  });
});