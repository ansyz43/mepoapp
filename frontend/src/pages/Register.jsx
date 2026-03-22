import { useState, useEffect, useRef } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { UserPlus } from 'lucide-react'

export default function Register() {
  const { register, loginWithGoogle } = useAuth()
  const authRef = useRef({ loginWithGoogle })
  authRef.current = { loginWithGoogle }
  const [searchParams] = useSearchParams()
  const refCode = searchParams.get('ref') || ''
  const refCodeRef = useRef(refCode)
  refCodeRef.current = refCode
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

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
            await authRef.current.loginWithGoogle(response.credential, refCodeRef.current || undefined)
          } catch (err) {
            setError(err.response?.data?.detail || 'Ошибка регистрации через Google')
          } finally {
            setLoading(false)
          }
        },
      })
      window.google?.accounts.id.renderButton(
        document.getElementById('google-register-btn'),
        { theme: 'filled_black', size: 'large', width: '100%', shape: 'pill', text: 'signup_with' }
      )
    }
    document.head.appendChild(script)
  }, [])

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')
    if (password.length < 6) {
      setError('Пароль должен быть не менее 6 символов')
      return
    }
    setLoading(true)
    try {
      await register(email, password, name, refCode || undefined)
    } catch (err) {
      setError(err.response?.data?.detail || 'Ошибка регистрации')
    } finally {
      setLoading(false)
    }
  }

  const showSocial = !!import.meta.env.VITE_GOOGLE_CLIENT_ID

  return (
    <div className="min-h-screen flex items-center justify-center px-6 py-12 relative overflow-hidden bg-[#060B11]">
      <div className="absolute inset-0 mesh-gradient" />
      <div className="absolute bottom-[20%] right-[20%] w-[400px] h-[400px] bg-teal-500/[0.06] rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute inset-0 noise" />
      <div className="w-full max-w-md relative">
        <Link to="/" className="flex items-center justify-center gap-2 mb-8">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center">
            <UserPlus size={16} className="text-white" />
          </div>
          <span className="text-2xl font-display font-bold gradient-text">Meepo</span>
        </Link>
        <div className="glass-card p-8">
          <h1 className="text-2xl font-display font-bold mb-6 text-center">Регистрация</h1>
          {refCode && (
            <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-xl px-4 py-3 text-emerald-400 text-sm mb-4 text-center">
              Вас пригласили! После регистрации вы будете привязаны к реферальной сети
            </div>
          )}
          {error && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-red-400 text-sm mb-4">{error}</div>
          )}

          {showSocial && (
            <>
              <div className="space-y-3 mb-5">
                <div id="google-register-btn" className="flex justify-center"></div>
              </div>
              <div className="flex items-center gap-3 mb-5">
                <div className="flex-1 h-px bg-white/10"></div>
                <span className="text-white/30 text-xs uppercase">или</span>
                <div className="flex-1 h-px bg-white/10"></div>
              </div>
            </>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm text-white/60 mb-1.5">Ваше имя</label>
              <input type="text" value={name} onChange={e => setName(e.target.value)}
                className="input-field" placeholder="Анна Иванова" required />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1.5">Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)}
                className="input-field" placeholder="you@example.com" required />
            </div>
            <div>
              <label className="block text-sm text-white/60 mb-1.5">Пароль</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)}
                className="input-field" placeholder="Минимум 6 символов" required />
            </div>
            <button type="submit" disabled={loading}
              className="btn-primary w-full flex items-center justify-center gap-2 disabled:opacity-50">
              <UserPlus size={18} />
              {loading ? 'Создание...' : 'Создать аккаунт'}
            </button>
          </form>
          <p className="text-center text-white/40 text-sm mt-6">
            Уже есть аккаунт? <Link to="/login" className="text-emerald-400 hover:underline">Войти</Link>
          </p>
        </div>
      </div>
    </div>
  )
}
