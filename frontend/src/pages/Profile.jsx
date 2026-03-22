import { useState } from 'react'
import api from '../api'
import { useAuth } from '../hooks/useAuth'
import { Save, Lock, User } from 'lucide-react'
import PageHeader from '../components/ui/PageHeader'

export default function Profile() {
  const { user, loadProfile } = useAuth()
  const [name, setName] = useState(user?.name || '')
  const [oldPass, setOldPass] = useState('')
  const [newPass, setNewPass] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  async function saveName(e) {
    e.preventDefault()
    setError(''); setSaving(true)
    try {
      await api.put('/api/profile', { name })
      setSuccess('Имя обновлено!')
      await loadProfile()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : 'Ошибка')
    }
    setSaving(false)
  }

  async function changePass(e) {
    e.preventDefault()
    if (newPass.length < 6) { setError('Пароль минимум 6 символов'); return }
    setError(''); setSaving(true)
    try {
      await api.put('/api/profile/password', { old_password: oldPass, new_password: newPass })
      setSuccess('Пароль изменён!')
      setOldPass(''); setNewPass('')
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : 'Ошибка')
    }
    setSaving(false)
  }

  return (
    <div>
      <PageHeader title="Профиль" />

      {error && <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-red-400 text-sm mb-4">{error}</div>}
      {success && <div className="bg-green-500/10 border border-green-500/30 rounded-xl px-4 py-3 text-green-400 text-sm mb-4">{success}</div>}

      <div className="glass-card p-6 mb-6">
        <h2 className="font-display font-semibold flex items-center gap-2 mb-5">
          <User size={18} className="text-emerald-400" /> Основная информация
        </h2>
        <form onSubmit={saveName} className="space-y-4">
          <div>
            <label className="block text-sm text-white/60 mb-1.5">Email</label>
            <input type="text" value={user?.email || ''} disabled className="input-field !bg-white/[0.02] !text-white/30" />
          </div>
          <div>
            <label className="block text-sm text-white/60 mb-1.5">Имя</label>
            <input type="text" value={name} onChange={e => setName(e.target.value)} className="input-field" required />
          </div>
          <button type="submit" disabled={saving} className="btn-primary flex items-center gap-2 disabled:opacity-50">
            <Save size={18} /> Сохранить
          </button>
        </form>
      </div>

      <div className="glass-card p-6">
        <h2 className="font-display font-semibold flex items-center gap-2 mb-5">
          <Lock size={18} className="text-emerald-400" /> Изменить пароль
        </h2>
        <form onSubmit={changePass} className="space-y-4">
          <div>
            <label className="block text-sm text-white/60 mb-1.5">Текущий пароль</label>
            <input type="password" value={oldPass} onChange={e => setOldPass(e.target.value)} className="input-field" required />
          </div>
          <div>
            <label className="block text-sm text-white/60 mb-1.5">Новый пароль</label>
            <input type="password" value={newPass} onChange={e => setNewPass(e.target.value)} className="input-field" required minLength={6} />
          </div>
          <button type="submit" disabled={saving} className="btn-primary flex items-center gap-2 disabled:opacity-50">
            <Lock size={18} /> Сменить пароль
          </button>
        </form>
      </div>
    </div>
  )
}
