import { useEffect, useState, useRef } from 'react'
import api from '../api'
import { Copy, Check, Save, Trash2, Camera, Users, PlusCircle, Link2, ExternalLink, Settings, MessageCircle, Handshake, Radio } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'
import PageHeader from '../components/ui/PageHeader'
import Loader from '../components/ui/Loader'
import EmptyState from '../components/ui/EmptyState'
import Modal from '../components/ui/Modal'

// Instagram icon
function IgIcon({ size = 18, className = '' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
      <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/>
    </svg>
  )
}

// Messenger icon
function MsgIcon({ size = 18, className = '' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className}>
      <path d="M12 0C5.373 0 0 4.974 0 11.111c0 3.498 1.744 6.614 4.469 8.654V24l4.088-2.242c1.092.301 2.246.464 3.443.464 6.627 0 12-4.974 12-11.111S18.627 0 12 0zm1.191 14.963l-3.055-3.26-5.963 3.26L10.733 8.2l3.13 3.26 5.889-3.26-6.561 6.763z"/>
    </svg>
  )
}

export default function ChannelsPage() {
  const { loadProfile } = useAuth()
  const [tab, setTab] = useState('instagram')
  const [igChannel, setIgChannel] = useState(null)
  const [msgChannel, setMsgChannel] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [copied, setCopied] = useState(false)
  const [avatarUploading, setAvatarUploading] = useState(false)
  const [showDisconnect, setShowDisconnect] = useState(false)
  const fileInputRef = useRef(null)

  // Partners
  const [partners, setPartners] = useState([])
  const [addingCredits, setAddingCredits] = useState(null)
  const [creditsAmount, setCreditsAmount] = useState(5)

  // Instagram editable fields
  const [assistantName, setAssistantName] = useState('')
  const [sellerLink, setSellerLink] = useState('')
  const [greeting, setGreeting] = useState('')
  const [channelDescription, setChannelDescription] = useState('')
  const [allowPartners, setAllowPartners] = useState(false)

  // Messenger editable fields
  const [msgAssistantName, setMsgAssistantName] = useState('')
  const [msgSellerLink, setMsgSellerLink] = useState('')
  const [msgGreeting, setMsgGreeting] = useState('')
  const [msgChannelDescription, setMsgChannelDescription] = useState('')

  // Connect form
  const [connectCode, setConnectCode] = useState('')
  const [connecting, setConnecting] = useState(false)

  useEffect(() => { loadChannels() }, [])

  async function loadChannels() {
    try {
      const [igRes, msgRes] = await Promise.all([
        api.get('/api/channel/instagram').catch(() => ({ data: null })),
        api.get('/api/channel/messenger').catch(() => ({ data: null })),
      ])
      setIgChannel(igRes.data)
      setMsgChannel(msgRes.data)
      if (igRes.data) {
        setAssistantName(igRes.data.assistant_name || '')
        setSellerLink(igRes.data.seller_link || '')
        setGreeting(igRes.data.greeting_message || '')
        setChannelDescription(igRes.data.bot_description || igRes.data.channel_description || '')
        setAllowPartners(igRes.data.allow_partners || false)
        if (igRes.data.allow_partners) loadPartners()
      }
      if (msgRes.data) {
        setMsgAssistantName(msgRes.data.assistant_name || '')
        setMsgSellerLink(msgRes.data.seller_link || '')
        setMsgGreeting(msgRes.data.greeting_message || '')
        setMsgChannelDescription(msgRes.data.bot_description || msgRes.data.channel_description || '')
      }
    } catch { /* ignore */ }
    setLoading(false)
  }

  async function loadPartners() {
    try {
      const { data } = await api.get('/api/referral/my-partners')
      setPartners(data)
    } catch { /* ignore */ }
  }

  async function addCredits(partnerId) {
    try {
      await api.post('/api/referral/credits', { partner_id: partnerId, credits: creditsAmount })
      setSuccess(`Добавлено ${creditsAmount} кредитов`)
      setAddingCredits(null)
      setCreditsAmount(5)
      loadPartners()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : Array.isArray(d) ? d.map(e => e.msg).join('; ') : 'Ошибка')
    }
  }

  // ── Instagram actions ──

  async function connectInstagram(e) {
    e.preventDefault()
    setError('')
    setConnecting(true)
    try {
      await api.post('/api/channel/instagram/connect', { code: connectCode })
      setSuccess('Instagram подключён!')
      setConnectCode('')
      await loadChannels()
      await loadProfile()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : Array.isArray(d) ? d.map(e => e.msg).join('; ') : 'Ошибка подключения Instagram')
    }
    setConnecting(false)
  }

  async function saveIgSettings(e) {
    e.preventDefault()
    setError('')
    setSaving(true)
    try {
      await api.put('/api/channel/instagram', {
        assistant_name: assistantName,
        seller_link: sellerLink || null,
        greeting_message: greeting || null,
        bot_description: channelDescription || null,
        allow_partners: allowPartners,
      })
      setSuccess('Настройки сохранены!')
      await loadChannels()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : Array.isArray(d) ? d.map(e => e.msg).join('; ') : 'Ошибка сохранения')
    }
    setSaving(false)
  }

  async function disconnectIg() {
    try {
      await api.delete('/api/channel/instagram')
      setIgChannel(null)
      setSuccess('Instagram-канал отключён')
      setShowDisconnect(false)
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : Array.isArray(d) ? d.map(e => e.msg).join('; ') : 'Ошибка')
      setShowDisconnect(false)
    }
  }

  // ── Messenger actions ──

  async function connectMessenger(e) {
    e.preventDefault()
    setError('')
    setConnecting(true)
    try {
      await api.post('/api/channel/messenger/connect', { code: connectCode })
      setSuccess('Messenger подключён!')
      setConnectCode('')
      await loadChannels()
      await loadProfile()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : Array.isArray(d) ? d.map(e => e.msg).join('; ') : 'Ошибка подключения Messenger')
    }
    setConnecting(false)
  }

  async function saveMsgSettings(e) {
    e.preventDefault()
    setError('')
    setSaving(true)
    try {
      await api.put('/api/channel/messenger', {
        assistant_name: msgAssistantName,
        seller_link: msgSellerLink || null,
        greeting_message: msgGreeting || null,
        bot_description: msgChannelDescription || null,
      })
      setSuccess('Настройки Messenger сохранены!')
      await loadChannels()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : Array.isArray(d) ? d.map(e => e.msg).join('; ') : 'Ошибка сохранения')
    }
    setSaving(false)
  }

  async function disconnectMsg() {
    try {
      await api.delete('/api/channel/messenger')
      setMsgChannel(null)
      setSuccess('Messenger-канал отключён')
      setShowDisconnect(false)
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : Array.isArray(d) ? d.map(e => e.msg).join('; ') : 'Ошибка')
      setShowDisconnect(false)
    }
  }

  function copyLink() {
    const name = igChannel?.channel_name || igChannel?.bot_username
    if (name) {
      navigator.clipboard.writeText(`https://instagram.com/${name}`)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  async function handleAvatarChange(e) {
    const file = e.target.files?.[0]
    if (!file) return
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      setError('Только JPEG, PNG или WEBP')
      return
    }
    if (file.size > 2 * 1024 * 1024) {
      setError('Максимум 2 МБ')
      return
    }
    setAvatarUploading(true)
    setError('')
    try {
      const channelId = igChannel?.id || msgChannel?.id
      const formData = new FormData()
      formData.append('file', file)
      const { data } = await api.post(`/api/channel/${channelId}/avatar`, formData)
      if (tab === 'instagram') setIgChannel(data)
      else setMsgChannel(data)
      setSuccess('Аватарка загружена!')
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : Array.isArray(d) ? d.map(e => e.msg).join('; ') : 'Ошибка загрузки аватарки')
    }
    setAvatarUploading(false)
  }

  useEffect(() => {
    if (success) { const t = setTimeout(() => setSuccess(''), 3000); return () => clearTimeout(t) }
  }, [success])

  if (loading) return <Loader />

  // ── Platform tabs ──
  const tabBar = (
    <div className="flex gap-1 p-1 bg-white/[0.04] rounded-xl mb-6">
      <button onClick={() => { setTab('instagram'); setError('') }}
        className={`flex items-center gap-2 px-5 py-2.5 rounded-lg text-sm font-medium transition-all duration-200 ${
          tab === 'instagram'
            ? 'bg-white/[0.08] text-white shadow-sm'
            : 'text-white/40 hover:text-white/60'
        }`}>
        <IgIcon size={16} /> Instagram
      </button>
      <button onClick={() => { setTab('messenger'); setError('') }}
        className={`flex items-center gap-2 px-5 py-2.5 rounded-lg text-sm font-medium transition-all duration-200 ${
          tab === 'messenger'
            ? 'bg-white/[0.08] text-white shadow-sm'
            : 'text-white/40 hover:text-white/60'
        }`}>
        <MsgIcon size={16} /> Messenger
      </button>
    </div>
  )

  // ── Connect form (shared) ──
  function ConnectForm({ platform, icon: Icon, color, platformLabel }) {
    return (
      <div className="glass-card p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className={`w-12 h-12 rounded-2xl bg-${color}-500/10 border border-${color}-500/20 flex items-center justify-center`}>
            <Icon size={24} className={`text-${color}-400`} />
          </div>
          <div>
            <h2 className="font-display font-semibold">Подключить {platformLabel}</h2>
            <p className="text-sm text-white/40">Авторизуйтесь через Meta для подключения</p>
          </div>
        </div>

        <form onSubmit={platform === 'instagram' ? connectInstagram : connectMessenger} className="space-y-5">
          <div>
            <label className="block text-sm text-white/60 mb-1.5">Код авторизации</label>
            <input type="text" value={connectCode} onChange={e => setConnectCode(e.target.value)}
              className="input-field" placeholder="Вставьте код авторизации Meta..." required />
            <p className="text-xs text-white/30 mt-1">Получите код через авторизацию Meta/Facebook</p>
          </div>

          <div className={`bg-${color}-500/5 border border-${color}-500/20 rounded-xl p-4`}>
            <p className={`text-sm text-${color}-400 font-medium mb-2`}>Инструкция:</p>
            <ol className="text-xs text-white/50 space-y-1.5 list-decimal list-inside">
              <li>Перейдите по ссылке авторизации Meta</li>
              <li>Выберите вашу бизнес-страницу {platformLabel}</li>
              <li>Предоставьте необходимые разрешения</li>
              <li>Скопируйте полученный код и вставьте выше</li>
            </ol>
          </div>

          <button type="submit" disabled={connecting}
            className="btn-primary w-full flex items-center justify-center gap-2 disabled:opacity-50">
            <span className="relative z-10 flex items-center gap-2">
              <Icon size={18} /> {connecting ? 'Подключение...' : `Подключить ${platformLabel}`}
            </span>
          </button>
        </form>
      </div>
    )
  }

  // ── Settings form (shared structure) ──
  function ChannelSettings({ channel, onSave, onDisconnect, platformLabel, icon: Icon, color,
    aName, setAName, sLink, setSLink, greet, setGreet, desc, setDesc, showPartners }) {
    const channelName = channel?.channel_name || channel?.bot_username
    return (
      <div>
        <PageHeader title="Каналы" actions={
          <div className="flex items-center gap-2">
            <span className={`w-2.5 h-2.5 rounded-full ${channel.is_active ? 'bg-green-400 shadow-[0_0_8px_rgba(74,222,128,0.4)]' : 'bg-red-400'}`} />
            <span className="text-sm text-white/60">{channel.is_active ? 'Активен' : 'Неактивен'}</span>
          </div>
        } />
        {tabBar}

        {error && <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-red-400 text-sm mb-4">{error}</div>}
        {success && <div className="bg-green-500/10 border border-green-500/30 rounded-xl px-4 py-3 text-green-400 text-sm mb-4">{success}</div>}

        {/* Channel link card */}
        {channelName && (
          <div className={`glass-card p-5 mb-6 border-l-4 border-l-${color}-500`}>
            <div className="flex items-center gap-2 mb-3">
              <Link2 size={18} className={`text-${color}-400`} />
              <span className="text-sm font-medium text-white/60">Ваш {platformLabel}</span>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <span className={`text-lg font-semibold text-${color}-400 break-all`}>
                {channelName}
              </span>
              <div className="flex items-center gap-2">
                {tab === 'instagram' && (
                  <button onClick={copyLink}
                    className="flex items-center gap-1.5 text-sm px-3 py-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-white/70 hover:text-white transition-colors">
                    {copied ? <Check size={14} className="text-green-400" /> : <Copy size={14} />}
                    {copied ? 'Скопировано' : 'Копировать'}
                  </button>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Settings form */}
        <form onSubmit={onSave} className="glass-card p-6 space-y-6">
          <div>
            <h2 className="font-display font-semibold flex items-center gap-2 mb-5">
              <Settings size={18} className={`text-${color}-400`} />
              Основные настройки
            </h2>

            {/* Avatar */}
            {tab === 'instagram' && (
              <div className="flex items-center gap-4 mb-5">
                <div className="relative group cursor-pointer" onClick={() => fileInputRef.current?.click()}>
                  {channel.avatar_url ? (
                    <img src={channel.avatar_url + (channel.avatar_url.includes('?') ? '&' : '?') + 't=' + Date.now()} alt="Аватар" className="w-20 h-20 rounded-2xl object-cover" />
                  ) : (
                    <div className="w-20 h-20 rounded-2xl bg-white/[0.06] flex items-center justify-center">
                      <Radio size={32} className="text-white/30" />
                    </div>
                  )}
                  <div className="absolute inset-0 bg-black/50 rounded-2xl flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                    <Camera size={20} className="text-white" />
                  </div>
                  {avatarUploading && (
                    <div className="absolute inset-0 bg-black/60 rounded-2xl flex items-center justify-center">
                      <div className="w-6 h-6 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    </div>
                  )}
                </div>
                <div>
                  <p className="text-sm text-white/60">Аватарка ассистента</p>
                  <p className="text-xs text-white/30">Нажмите для загрузки (JPEG, PNG, WEBP, до 2 МБ)</p>
                </div>
                <input ref={fileInputRef} type="file" accept="image/jpeg,image/png,image/webp"
                  className="hidden" onChange={handleAvatarChange} />
              </div>
            )}

            <div>
              <label className="block text-sm text-white/60 mb-1.5">Имя ассистента</label>
              <input type="text" value={aName} onChange={e => setAName(e.target.value)}
                className="input-field" placeholder="Ассистент Анны" required />
              <p className="text-xs text-white/30 mt-1">Как ассистент будет представляться пользователям</p>
            </div>
          </div>

          <div className="border-t border-white/[0.06]" />

          <div className="space-y-5">
            <h2 className="font-display font-semibold flex items-center gap-2">
              <MessageCircle size={18} className={`text-${color}-400`} />
              Контент
            </h2>

            <div>
              <label className="block text-sm text-white/60 mb-1.5">Описание</label>
              <textarea value={desc} onChange={e => setDesc(e.target.value)}
                className="input-field min-h-[80px] resize-y" placeholder="Персональный помощник по продукции FitLine" maxLength={512} />
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1.5">Приветственное сообщение</label>
              <textarea value={greet} onChange={e => setGreet(e.target.value)}
                className="input-field min-h-[100px] resize-y" placeholder="Привет! Я ассистент..." />
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1.5">Ваша ссылка</label>
              <input type="url" value={sLink} onChange={e => setSLink(e.target.value)}
                className="input-field" placeholder="https://your-link.com" />
              <p className="text-xs text-white/30 mt-1">Ассистент будет давать эту ссылку заинтересованным клиентам</p>
            </div>
          </div>

          {showPartners && (
            <>
              <div className="border-t border-white/[0.06]" />
              <div>
                <h2 className="font-display font-semibold flex items-center gap-2 mb-4">
                  <Handshake size={18} className="text-emerald-400" />
                  Партнёрская программа
                </h2>
                <div className="flex items-center justify-between py-2 px-1">
                  <div>
                    <div className="text-sm text-white/80">Разрешить партнёров</div>
                    <div className="text-xs text-white/30">Другие пользователи смогут стать партнёрами вашего канала</div>
                  </div>
                  <button type="button" onClick={() => setAllowPartners(!allowPartners)}
                    className={`toggle-switch ${allowPartners ? 'active' : ''}`} />
                </div>
              </div>
            </>
          )}

          <div className="border-t border-white/[0.06]" />

          <div className="flex flex-col-reverse sm:flex-row items-start sm:items-center justify-between gap-3">
            <button type="button" onClick={() => setShowDisconnect(true)}
              className="flex items-center gap-2 text-sm text-red-400 hover:text-red-300 transition-colors">
              <Trash2 size={16} /> Отключить канал
            </button>
            <button type="submit" disabled={saving} className="btn-primary flex items-center gap-2 disabled:opacity-50 w-full sm:w-auto justify-center">
              <Save size={18} /> {saving ? 'Сохранение...' : 'Сохранить'}
            </button>
          </div>
        </form>

        {/* Disconnect Modal */}
        <Modal
          open={showDisconnect}
          onClose={() => setShowDisconnect(false)}
          title={`Отключить ${platformLabel}?`}
          actions={
            <>
              <button onClick={() => setShowDisconnect(false)} className="btn-secondary !py-2 !px-5 text-sm">Отмена</button>
              <button onClick={onDisconnect} className="bg-red-500/20 hover:bg-red-500/30 text-red-400 font-medium py-2 px-5 rounded-xl text-sm transition-colors">
                Отключить
              </button>
            </>
          }
        >
          Все переписки и контакты канала будут удалены. Это действие нельзя отменить.
        </Modal>
      </div>
    )
  }

  // ── INSTAGRAM TAB ──
  if (tab === 'instagram') {
    if (!igChannel) {
      return (
        <div>
          <PageHeader title="Каналы" />
          {tabBar}
          {error && <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-red-400 text-sm mb-4">{error}</div>}
          {success && <div className="bg-green-500/10 border border-green-500/30 rounded-xl px-4 py-3 text-green-400 text-sm mb-4">{success}</div>}
          <ConnectForm platform="instagram" icon={IgIcon} color="pink" platformLabel="Instagram" />
        </div>
      )
    }

    return (
      <ChannelSettings
        channel={igChannel}
        onSave={saveIgSettings}
        onDisconnect={disconnectIg}
        platformLabel="Instagram"
        icon={IgIcon}
        color="emerald"
        aName={assistantName}
        setAName={setAssistantName}
        sLink={sellerLink}
        setSLink={setSellerLink}
        greet={greeting}
        setGreet={setGreeting}
        desc={channelDescription}
        setDesc={setChannelDescription}
        showPartners
      />
    )
  }

  // ── MESSENGER TAB ──
  if (!msgChannel) {
    return (
      <div>
        <PageHeader title="Каналы" />
        {tabBar}
        {error && <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-red-400 text-sm mb-4">{error}</div>}
        {success && <div className="bg-green-500/10 border border-green-500/30 rounded-xl px-4 py-3 text-green-400 text-sm mb-4">{success}</div>}
        <ConnectForm platform="messenger" icon={MsgIcon} color="blue" platformLabel="Messenger" />
      </div>
    )
  }

  return (
    <ChannelSettings
      channel={msgChannel}
      onSave={saveMsgSettings}
      onDisconnect={disconnectMsg}
      platformLabel="Messenger"
      icon={MsgIcon}
      color="blue"
      aName={msgAssistantName}
      setAName={setMsgAssistantName}
      sLink={msgSellerLink}
      setSLink={setMsgSellerLink}
      greet={msgGreeting}
      setGreet={setMsgGreeting}
      desc={msgChannelDescription}
      setDesc={setMsgChannelDescription}
      showPartners={false}
    />
  )
}
