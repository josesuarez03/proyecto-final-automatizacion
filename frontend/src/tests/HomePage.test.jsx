import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { HomePage } from '../pages/HomePage';
import { describe, it, expect, vi } from 'vitest';
import React from 'react';

vi.mock('../hooks/useTaskApi', () => ({
  useGetTasks: vi.fn(() => ({ data: [] })),
  useDeleteTask: () => ({
    mutate: vi.fn(),
  }),
  useToggleTask: () => ({
    mutate: vi.fn(),
  }),
}));

const renderWithProviders = (component) => {
  const queryClient = new QueryClient();
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>{component}</MemoryRouter>
    </QueryClientProvider>
  );
};

describe('HomePage', () => {
  it('renders title correctly', () => {
    renderWithProviders(<HomePage />);
    expect(screen.getByText('Mis Tareas')).toBeInTheDocument();
  });

  it('renders create task button', () => {
    renderWithProviders(<HomePage />);
    const createButton = screen.getByText('Nueva Tarea');
    expect(createButton).toBeInTheDocument();
    expect(createButton.closest('a')).toHaveAttribute('href', '/create');
  });

  it('shows empty state when no tasks', async () => {
    const { useGetTasks } = await import('../hooks/useTaskApi'); // Usa import dinámico para ESM
    useGetTasks.mockReturnValueOnce({ data: [] }); // Devuelve un objeto con `data`

    renderWithProviders(<HomePage />);
    expect(screen.getByText('No hay tareas pendientes')).toBeInTheDocument();
  });
});
