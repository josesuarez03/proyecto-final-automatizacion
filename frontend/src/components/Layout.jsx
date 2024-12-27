import { Link } from 'react-router-dom'
import PropTypes from 'prop-types'

export const Layout = ({ children }) => (
  <div className="min-h-screen bg-gray-100">
    <nav className="bg-white shadow-sm">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <Link to="/" className="text-xl font-bold text-blue-600">
          Task Manager
        </Link>
      </div>
    </nav>
    <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {children}
    </main>
  </div>
)

Layout.propTypes = {
  children: PropTypes.node.isRequired
}
