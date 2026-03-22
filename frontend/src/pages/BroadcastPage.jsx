import { useEffect, useState } from 'react'
import api from '../api'
import { Send, History, Radio, Users, Clock, CheckCircle, XCircle } from 'lucide-react'
import PageHeader from '../components/ui/PageHeader'
import Loader from '../components/ui/Loader'
import EmptyState from '../components/ui/EmptyState'

export default function BroadcastPage() {
  const [tab, setTab] = useState('create')
  const [message, setMessage] = useState('')
  const [sending, setSending] = useState(false)
  const [broadcasts, setBroadcasts] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  async function loadBroadcasts() {
    setLoading(true)
    try {
      const { data } = await api.get('/api/channel/broadcasts')
      setBroadcasts(data)
    } catch { /* ignore */ }
    setLoading(false)
  }

  function handleTab(t) {
    setTab(t)
    if (t === 'history') loadBroadcasts()
  }

  async function sendBroadcast(e) {
    e.preventDefault()
    if (!message.trim()) return
    setError('')
    setSending(true)
    try {
      await api.post('/api/channel/broadcast', { message: message.trim() })
      setSuccess('Рассылка запущена!')
      setMessage('')
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : 'Ошибка отправки')
    }
    setSending(false)
  }

  useEffect(() => {
    if (success) { const t = setTimeout(() => setSuccess(''), 3000); return () => clearTimeout(t) }
  }, [success])

  return (
    <div>
      <PageHeader title="Рассылки" />

      {/* Tabs */}
      <div className="flex gap-1 p-1 bg-white/[0.04] rounded-xl mb-6">
        <button onClick={() => handleTab('create')}
          className={`flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
            tab === 'create' ? 'bg-white/[0.08] text-white shadow-sm' : 'text-white/40 hover:text-white/60'
          }`}>
          <Send size={14} /> Создать
        </button>
        <button onClick={() => handleTab('history')}
          className={`flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
            tab === 'history' ? 'bg-white/[0.08] text-white shadow-sm' : 'text-white/40 hover:text-white/60'
          }`}>
          <History size={14} /> История
        </button>
      </div>

      {error && <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-red-400 text-sm mb-4">{error}</div>}
      {success && <div className="bg-green-500/10 border border-green-500/30 rounded-xl px-4 py-3 text-green-400 text-sm mb-4">{success}</div>}

      {/* Create tab */}
      {tab === 'create' && (
        <form onSubmit={sendBroadcast} className="glass-card p-6 space-y-5">
          <div>
            <h2 className="font-display font-semibold flex items-center gap-2 mb-4">
              <Send size={18} className="text-emerald-400" /> Новая рассылка
            </h2>
            <p className="text-sm text-white/40 mb-4">Сообщение будет отправлено всем контактам вашего канала.</p>
          </div>

          <div>
            <label className="block text-sm text-white/60 mb-1.5">Текст сообщения</label>
            <textarea value={message} onChange={e => setMessage(e.target.value)}
              className="input-field min-h-[150px] resize-y" placeholder="Введите текст рассылки..."
              required maxLength={4096} />
            <div className="text-xs text-white/20 text-right mt-1">{message.length}/4096</div>
          </div>

          <button type="submit" disabled={sending || !message.trim()}
            className="btn-primary flex items-center gap-2 disabled:opacity-50">
            <Send size={18} /> {sending ? 'Отправка...' : 'Отправить рассылку'}
          </button>
        </form>
      )}

      {/* History tab */}
      {tab === 'history' && (
        <div className="glass-card overflow-hidden">
          {loading ? <div className="p-6"><Loader /></div> : broadcasts.length === 0 ? (
            <div className="p-6">
              <EmptyState icon={History} title="Нет рассылок" text="Создайте первую рассылку для ваших контактов" />
            </div>
          ) : (
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/[0.06]">
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Дата</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Сообщение</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Отправлено</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Статус</th>
                </tr>
              </thead>
              <tbody>
                {broadcasts.map((b, i) => (
                  <tr key={i} className="border-b border-white/[0.04]">
                    <td className="px-4 py-3 text-sm text-white/50">{new Date(b.created_at).toLocaleString('ru')}</td>
                    <td className="px-4 py-3 text-sm text-white/70 max-w-xs truncate">{b.message}</td>
                    <td className="px-4 py-3 text-sm text-white/50">{b.sent_count ?? '—'}</td>
                    <td className="px-4 py-3">
                      {b.status === 'completed' ? (
                        <span className="inline-flex items-center gap-1 text-xs text-green-400">
                          <CheckCircle size={12} /> Завершена
                        </span>
                      ) : b.status === 'failed' ? (
                        <span className="inline-flex items-center gap-1 text-xs text-red-400">
                          <XCircle size={12} /> Ошибка
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-xs text-yellow-400">
                          <Clock size={12} /> В процессе
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  )
}
