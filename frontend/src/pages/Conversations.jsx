import { useEffect, useState, useRef } from 'react'
import api from '../api'
import { MessageCircle, Search, Download, ChevronLeft, Send, User } from 'lucide-react'
import PageHeader from '../components/ui/PageHeader'
import Loader from '../components/ui/Loader'
import EmptyState from '../components/ui/EmptyState'

function IgBadge() {
  return <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-pink-500/10 text-pink-400 text-xs font-medium">
    <svg width={10} height={10} viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/></svg>
    IG
  </span>
}

function MsgBadge() {
  return <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-blue-500/10 text-blue-400 text-xs font-medium">
    <svg width={10} height={10} viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.373 0 0 4.974 0 11.111c0 3.498 1.744 6.614 4.469 8.654V24l4.088-2.242c1.092.301 2.246.464 3.443.464 6.627 0 12-4.974 12-11.111S18.627 0 12 0zm1.191 14.963l-3.055-3.26-5.963 3.26L10.733 8.2l3.13 3.26 5.889-3.26-6.561 6.763z"/></svg>
    MSG
  </span>
}

function displayName(c) {
  if (c.first_name || c.last_name) return [c.first_name, c.last_name].filter(Boolean).join(' ')
  if (c.instagram_username) return '@' + c.instagram_username
  return 'Пользователь #' + c.id
}

export default function Conversations() {
  const [contacts, setContacts] = useState([])
  const [selected, setSelected] = useState(null)
  const [messages, setMessages] = useState([])
  const [loading, setLoading] = useState(true)
  const [msgLoading, setMsgLoading] = useState(false)
  const [search, setSearch] = useState('')
  const [platform, setPlatform] = useState('all')
  const chatEnd = useRef(null)

  useEffect(() => { loadContacts() }, [])

  async function loadContacts() {
    try {
      const { data } = await api.get('/api/conversations')
      setContacts(data)
    } catch { /* ignore */ }
    setLoading(false)
  }

  async function selectContact(c) {
    setSelected(c)
    setMsgLoading(true)
    try {
      const { data } = await api.get(`/api/conversations/${c.id}`)
      setMessages(data)
      setTimeout(() => chatEnd.current?.scrollIntoView({ behavior: 'smooth' }), 100)
    } catch { /* ignore */ }
    setMsgLoading(false)
  }

  async function exportChat() {
    if (!selected) return
    try {
      const { data } = await api.get(`/api/conversations/${selected.id}/export`, { responseType: 'blob' })
      const url = URL.createObjectURL(new Blob([data]))
      const a = document.createElement('a')
      a.href = url
      a.download = `chat_${selected.id}.txt`
      a.click()
      URL.revokeObjectURL(url)
    } catch { /* ignore */ }
  }

  const filtered = contacts.filter(c => {
    const matchSearch = !search || displayName(c).toLowerCase().includes(search.toLowerCase())
    const matchPlatform = platform === 'all' || c.platform === platform
    return matchSearch && matchPlatform
  })

  if (loading) return <Loader />

  return (
    <div>
      <PageHeader title="Переписки" />

      <div className="glass-card overflow-hidden" style={{ height: 'calc(100vh - 180px)', minHeight: 500 }}>
        <div className="flex h-full">
          {/* Left: contact list */}
          <div className={`${selected ? 'hidden md:flex' : 'flex'} flex-col w-full md:w-80 border-r border-white/[0.06]`}>
            <div className="p-3 border-b border-white/[0.06] space-y-2">
              <div className="relative">
                <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30" />
                <input type="text" value={search} onChange={e => setSearch(e.target.value)}
                  placeholder="Поиск..." className="input-field !pl-9 !py-2 text-sm" />
              </div>
              <div className="flex gap-1">
                {['all', 'instagram', 'facebook_messenger'].map(p => (
                  <button key={p} onClick={() => setPlatform(p)}
                    className={`text-xs px-2.5 py-1 rounded-lg transition-colors ${
                      platform === p ? 'bg-white/10 text-white' : 'text-white/40 hover:text-white/60'
                    }`}>
                    {p === 'all' ? 'Все' : p === 'instagram' ? 'IG' : 'MSG'}
                  </button>
                ))}
              </div>
            </div>

            <div className="flex-1 overflow-y-auto custom-scrollbar">
              {filtered.length === 0 ? (
                <div className="p-6 text-center text-white/30 text-sm">Нет переписок</div>
              ) : filtered.map(c => (
                <button key={c.id} onClick={() => selectContact(c)}
                  className={`w-full text-left px-4 py-3 flex items-center gap-3 border-b border-white/[0.04] transition-colors hover:bg-white/[0.04] ${
                    selected?.id === c.id ? 'bg-white/[0.06]' : ''
                  }`}>
                  <div className="w-10 h-10 rounded-xl bg-white/[0.06] flex items-center justify-center shrink-0">
                    <User size={18} className="text-white/40" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium truncate">{displayName(c)}</span>
                      {c.platform === 'instagram' ? <IgBadge /> : <MsgBadge />}
                    </div>
                    {c.last_message && (
                      <p className="text-xs text-white/30 truncate mt-0.5">{c.last_message}</p>
                    )}
                  </div>
                  {c.last_message_at && (
                    <span className="text-[10px] text-white/20 shrink-0">
                      {new Date(c.last_message_at).toLocaleDateString('ru')}
                    </span>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Right: messages */}
          <div className={`${selected ? 'flex' : 'hidden md:flex'} flex-col flex-1`}>
            {selected ? (
              <>
                <div className="flex items-center gap-3 px-4 py-3 border-b border-white/[0.06]">
                  <button onClick={() => setSelected(null)} className="md:hidden text-white/60 hover:text-white">
                    <ChevronLeft size={20} />
                  </button>
                  <div className="w-9 h-9 rounded-xl bg-white/[0.06] flex items-center justify-center">
                    <User size={16} className="text-white/40" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium truncate">{displayName(selected)}</div>
                    <div className="text-xs text-white/30">{selected.platform === 'instagram' ? 'Instagram' : 'Messenger'}</div>
                  </div>
                  <button onClick={exportChat} className="text-white/40 hover:text-white/60" title="Экспорт">
                    <Download size={18} />
                  </button>
                </div>

                <div className="flex-1 overflow-y-auto custom-scrollbar p-4 space-y-3">
                  {msgLoading ? (
                    <div className="flex items-center justify-center h-full"><Loader /></div>
                  ) : messages.length === 0 ? (
                    <div className="text-center text-white/30 text-sm py-10">Нет сообщений</div>
                  ) : messages.map((m, i) => (
                    <div key={i} className={`flex ${m.role === 'assistant' ? 'justify-start' : 'justify-end'}`}>
                      <div className={`max-w-[80%] rounded-2xl px-4 py-2.5 text-sm whitespace-pre-wrap ${
                        m.role === 'assistant'
                          ? 'bg-white/[0.06] text-white/80 rounded-bl-md'
                          : 'bg-emerald-500/20 text-emerald-100 rounded-br-md'
                      }`}>
                        {m.content}
                        {m.created_at && (
                          <div className="text-[10px] text-white/20 mt-1">
                            {new Date(m.created_at).toLocaleString('ru')}
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                  <div ref={chatEnd} />
                </div>
              </>
            ) : (
              <EmptyState icon={MessageCircle} title="Выберите переписку" text="Выберите контакт слева для просмотра сообщений" />
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
