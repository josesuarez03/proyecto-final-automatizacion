import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { Layout } from './components/Layout'
import { HomePage } from './pages/HomePage'
import { CreateTaskPage } from './pages/CreateTaskPage'
import { EditTaskPage } from './pages/EditTaskPage'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const queryClient = new QueryClient()

const App = () => {
  return (
    <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <Layout>
            <Routes>
              <Route path="/" element={<HomePage />} />
              <Route path="/create" element={<CreateTaskPage />} />
              <Route path="/edit/:id" element={<EditTaskPage />} />
            </Routes>
          </Layout>
      </BrowserRouter>
    </QueryClientProvider>
  )
}

export default App