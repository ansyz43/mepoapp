import { Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './hooks/useAuth'
import { Component } from 'react'

import Landing from './pages/Landing'
import Login from './pages/Login'
import Register from './pages/Register'
import ResetPassword from './pages/ResetPassword'
import Dashboard from './pages/Dashboard'
import ChannelsPage from './pages/ChannelsPage'
import Conversations from './pages/Conversations'
import Contacts from './pages/Contacts'
import Profile from './pages/Profile'
import CatalogPage from './pages/CatalogPage'
import PartnerPage from './pages/PartnerPage'
import BroadcastPage from './pages/BroadcastPage'
import AdminPage from './pages/AdminPage'
import DashboardLayout from './components/DashboardLayout'

function PrivateRoute({ children }) {
  const { user, loading } = useAuth()
  if (loading) return null
  return user ? children : <Navigate to="/login" />
}

function PublicRoute({ children }) {
  const { user, loading } = useAuth()
  if (loading) return null
  return !user ? children : <Navigate to="/dashboard" />
}

class ErrorBoundary extends Component {
  state = { hasError: false }
  static getDerivedStateFromError() { return { hasError: true } }
  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-[#060B11]">
          <div className="text-center">
            <h1 className="text-2xl font-bold text-white mb-2">Что-то пошло не так</h1>
            <button onClick={() => window.location.reload()} className="text-emerald-400 hover:underline">
              Перезагрузить
            </button>
          </div>
        </div>
      )
    }
    return this.props.children
  }
}

export default function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <Routes>
          <Route path="/" element={<PublicRoute><Landing /></PublicRoute>} />
          <Route path="/login" element={<PublicRoute><Login /></PublicRoute>} />
          <Route path="/register" element={<PublicRoute><Register /></PublicRoute>} />
          <Route path="/reset-password" element={<PublicRoute><ResetPassword /></PublicRoute>} />
          <Route path="/dashboard" element={<PrivateRoute><DashboardLayout /></PrivateRoute>}>
            <Route index element={<Dashboard />} />
            <Route path="channels" element={<ChannelsPage />} />
            <Route path="conversations" element={<Conversations />} />
            <Route path="contacts" element={<Contacts />} />
            <Route path="broadcast" element={<BroadcastPage />} />
            <Route path="catalog" element={<CatalogPage />} />
            <Route path="partner" element={<PartnerPage />} />
            <Route path="profile" element={<Profile />} />
            <Route path="admin" element={<AdminPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </AuthProvider>
    </ErrorBoundary>
  )
}
