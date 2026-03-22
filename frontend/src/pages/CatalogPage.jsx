import { useEffect, useState } from 'react'
import api from '../api'
import { Radio, Search, ExternalLink, Handshake } from 'lucide-react'
import PageHeader from '../components/ui/PageHeader'
import Loader from '../components/ui/Loader'
import EmptyState from '../components/ui/EmptyState'
import Modal from '../components/ui/Modal'

export default function CatalogPage() {
  const [channels, setChannels] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [signupChannel, setSignupChannel] = useState(null)
  const [signing, setSigning] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  useEffect(() => { loadCatalog() }, [])

  async function loadCatalog() {
    try {
      const { data } = await api.get('/api/referral/catalog')
      setChannels(data)
    } catch { /* ignore */ }
    setLoading(false)
  }

  async function signupPartner() {
    if (!signupChannel) return
    setError('')
    setSigning(true)
    try {
      await api.post('/api/referral/partner', { channel_id: signupChannel.id })
      setSuccess('Вы стали партнёром!')
      setSignupChannel(null)
      loadCatalog()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : 'Ошибка')
    }
    setSigning(false)
  }

  const filtered = channels.filter(c => {
    if (!search) return true
    const s = search.toLowerCase()
    const name = c.channel_name || c.bot_username || ''
    const desc = c.bot_description || c.channel_description || ''
    return name.toLowerCase().includes(s) || desc.toLowerCase().includes(s)
  })

  if (loading) return <Loader />

  return (
    <div>
      <PageHeader title="Каталог каналов" />

      {success && <div className="bg-green-500/10 border border-green-500/30 rounded-xl px-4 py-3 text-green-400 text-sm mb-4">{success}</div>}

      <div className="mb-6">
        <div className="relative max-w-md">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30" />
          <input type="text" value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Поиск каналов..." className="input-field !pl-9 !py-2.5" />
        </div>
      </div>

      {filtered.length === 0 ? (
        <EmptyState icon={Radio} title="Каналов пока нет" text="Каталог каналов с партнёрской программой" />
      ) : (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(ch => (
            <div key={ch.id} className="glass-card p-5 flex flex-col">
              <div className="flex items-center gap-3 mb-3">
                {ch.avatar_url ? (
                  <img src={ch.avatar_url} alt="" className="w-12 h-12 rounded-2xl object-cover" />
                ) : (
                  <div className="w-12 h-12 rounded-2xl bg-white/[0.06] flex items-center justify-center">
                    <Radio size={20} className="text-white/30" />
                  </div>
                )}
                <div className="min-w-0">
                  <div className="text-sm font-semibold truncate">{ch.channel_name || ch.bot_username || `Канал #${ch.id}`}</div>
                  <div className="text-xs text-white/30">{ch.platform === 'instagram' ? 'Instagram' : 'Messenger'}</div>
                </div>
              </div>

              {(ch.bot_description || ch.channel_description) && (
                <p className="text-xs text-white/40 mb-4 line-clamp-3">{ch.bot_description || ch.channel_description}</p>
              )}

              <div className="mt-auto">
                <button onClick={() => setSignupChannel(ch)}
                  className="w-full flex items-center justify-center gap-2 text-sm py-2.5 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 font-medium transition-colors">
                  <Handshake size={16} /> Стать партнёром
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      <Modal
        open={!!signupChannel}
        onClose={() => { setSignupChannel(null); setError('') }}
        title="Стать партнёром"
        actions={
          <>
            <button onClick={() => { setSignupChannel(null); setError('') }} className="btn-secondary !py-2 !px-5 text-sm">Отмена</button>
            <button onClick={signupPartner} disabled={signing}
              className="bg-emerald-500/20 hover:bg-emerald-500/30 text-emerald-400 font-medium py-2 px-5 rounded-xl text-sm transition-colors disabled:opacity-50">
              {signing ? 'Подключение...' : 'Подтвердить'}
            </button>
          </>
        }
      >
        {error && <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-red-400 text-sm mb-3">{error}</div>}
        <p className="text-sm text-white/60">
          Вы хотите стать партнёром канала <strong className="text-white">{signupChannel?.channel_name || signupChannel?.bot_username}</strong>?
          Вы сможете привлекать клиентов и получать кэшбек.
        </p>
      </Modal>
    </div>
  )
}
