import '@testing-library/jest-dom'
import { vi } from 'vitest'

// Configuración global para las pruebas
window.ResizeObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn()
}))