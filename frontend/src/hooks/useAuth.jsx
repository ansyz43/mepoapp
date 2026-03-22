import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import api, { setAccessToken } from '../api'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  const loadProfile = useCallback(async () => {
    try {
      const { data } = await api.get('/api/profile')
      setUser(data)
    } catch {
      setUser(null)
      setAccessToken(null)
      localStorage.removeItem('refresh_token')
    }
  }, [])

  useEffect(() => {
    const rt = localStorage.getItem('refresh_token')
    if (!rt) { setLoading(false); return }
    api.post('/api/auth/refresh', { refresh_token: rt })
      .then(r => {
        setAccessToken(r.data.access_token)
        localStorage.setItem('refresh_token', r.data.refresh_token)
        return loadProfile()
      })
      .catch(() => {
        setAccessToken(null)
        localStorage.removeItem('refresh_token')
      })
      .finally(() => setLoading(false))
  }, [loadProfile])

  async function login(email, password) {
    const { data } = await api.post('/api/auth/login', { email, password })
    setAccessToken(data.access_token)
    localStorage.setItem('refresh_token', data.refresh_token)
    await loadProfile()
  }

  async function register(email, password, name, refCode) {
    const { data } = await api.post('/api/auth/register', { email, password, name, ref_code: refCode })
    setAccessToken(data.access_token)
    localStorage.setItem('refresh_token', data.refresh_token)
    await loadProfile()
  }

  async function loginWithGoogle(credential, refCode) {
    const { data } = await api.post('/api/auth/google', { id_token: credential, ref_code: refCode })
    setAccessToken(data.access_token)
    localStorage.setItem('refresh_token', data.refresh_token)
    await loadProfile()
  }

  async function logout() {
    try { await api.post('/api/auth/logout') } catch { /* ignore */ }
    setAccessToken(null)
    localStorage.removeItem('refresh_token')
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, loading, login, register, loginWithGoogle, logout, loadProfile }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  return useContext(AuthContext)
}
