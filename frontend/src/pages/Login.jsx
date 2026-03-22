import { useState, useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { LogIn } from 'lucide-react'

export default function Login() {
  const { login, loginWithGoogle } = useAuth()
  const authRef = useRef({ loginWithGoogle })
  authRef.current = { loginWithGoogle }
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  // Load Google Sign-In (once)
  useEffect(() => {
    const clientId = import.meta.env.VITE_GOOGLE_CLIENT_ID
    if (!clientId) return
    const script = document.createElement('script')
    script.src = 'https://accounts.google.com/gsi/client'
    script.async = true
    script.onload = () => {
      window.google?.accounts.id.initialize({
        client_id: clientId,
        auto_select: false,
        callback: async (response) => {
          setError('')
          setLoading(true)
          try {
            await authRef.current.loginWithGoogle(response.credential)
          } catch (err) {
            setError(err.response?.data?.detail || 'Ошибка входа через Google')
          } finally {
            setLoading(false)
          }
        },
      })
      window.google?.accounts.id.renderButton(
        document.getElementById('google-login-btn'),
        { theme: 'filled_black', size: 'large', width: '100%', shape: 'pill', text: 'signin_with' }
      )
    }
    document.head.appendChild(script)
  }, [])

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await login(email, password)
    } catch (err) {
      setError(err.response?.data?.detail || 'Ошибка входа')
    } finally {
      setLoading(false)
    }
  }

  const showSocial = !!import.meta.env.VITE_GOOGLE_CLIENT_ID

  return (
    <div className="min-h-screen flex items-center justify-center px-6 relative overflow-hidden bg-[#060B11]">
      <div className="absolute inset-0 mesh-gradient" />
      <div className="absolute top-[20%] left-[30%] w-[400px] h-[400px] bg-emerald-500/[0.06] rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute inset-0 noise" />
      <div className="w-full max-w-md relative">
        <Link to="/" className="flex items-center justify-center gap-2 mb-8">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center">
            <LogIn size={16} className="text-white" />
          </div>
          <span className="text-2xl font-display font-bold gradient-text">Meepo</span>
        </Link>
        <div className="glass-card p-8">
          <h1 className="text-2xl font-display font-bold mb-6 text-center">Вход</h1>
          {error && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-red-400 text-sm mb-4">{error}</div>
          )}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm text-white/60 mb-1.5">Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)}
                className="input-field" placeholder="you@example.com" required />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1.5">Пароль</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)}
                className="input-field" placeholder="••••••••" required />
            </div>
            <button type="submit" disabled={loading}
              className="btn-primary w-full flex items-center justify-center gap-2 disabled:opacity-50">
              <LogIn size={18} />
              {loading ? 'Вход...' : 'Войти'}
            </button>
          </form>

          {showSocial && (
            <>
              <div className="flex items-center gap-3 my-5">
                <div className="flex-1 h-px bg-white/10"></div>
                <span className="text-white/30 text-xs uppercase">или</span>
                <div className="flex-1 h-px bg-white/10"></div>
              </div>
              <div className="space-y-3">
                <div id="google-login-btn" className="flex justify-center"></div>
              </div>
            </>
          )}

          <p className="text-center text-white/40 text-sm mt-4">
            <Link to="/reset-password" className="text-white/50 hover:text-emerald-400 hover:underline transition-colors">Забыли пароль?</Link>
          </p>
          <p className="text-center text-white/40 text-sm mt-2">
            Нет аккаунта? <Link to="/register" className="text-emerald-400 hover:underline">Зарегистрироваться</Link>
          </p>
        </div>
      </div>
    </div>
  )
}
