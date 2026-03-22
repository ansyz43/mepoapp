import { useEffect, useState } from 'react'
import api from '../api'
import { Users, Search, Download, ChevronLeft, ChevronRight, User, ExternalLink } from 'lucide-react'
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

function profileLink(c) {
  if (c.platform === 'instagram' && c.instagram_username)
    return `https://instagram.com/${c.instagram_username}`
  return null
}

function displayName(c) {
  if (c.first_name || c.last_name) return [c.first_name, c.last_name].filter(Boolean).join(' ')
  if (c.instagram_username) return '@' + c.instagram_username
  return 'Пользователь #' + c.id
}

export default function Contacts() {
  const [contacts, setContacts] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const perPage = 20

  useEffect(() => { loadContacts() }, [])

  async function loadContacts() {
    try {
      const { data } = await api.get('/api/contacts')
      setContacts(data)
    } catch { /* ignore */ }
    setLoading(false)
  }

  async function exportCSV() {
    try {
      const { data } = await api.get('/api/contacts/export', { responseType: 'blob' })
      const url = URL.createObjectURL(new Blob([data]))
      const a = document.createElement('a')
      a.href = url
      a.download = 'contacts.csv'
      a.click()
      URL.revokeObjectURL(url)
    } catch { /* ignore */ }
  }

  const filtered = contacts.filter(c => {
    if (!search) return true
    const s = search.toLowerCase()
    return displayName(c).toLowerCase().includes(s) || (c.instagram_username && c.instagram_username.toLowerCase().includes(s))
  })

  const totalPages = Math.ceil(filtered.length / perPage)
  const paged = filtered.slice((page - 1) * perPage, page * perPage)

  if (loading) return <Loader />

  if (contacts.length === 0) return (
    <div>
      <PageHeader title="Контакты" />
      <EmptyState icon={Users} title="Нет контактов" text="Контакты появятся после начала диалогов с вашим каналом" />
    </div>
  )

  return (
    <div>
      <PageHeader title="Контакты" actions={
        <button onClick={exportCSV}
          className="flex items-center gap-2 text-sm px-4 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-white/70 hover:text-white transition-colors">
          <Download size={16} /> Экспорт CSV
        </button>
      } />

      <div className="glass-card overflow-hidden">
        <div className="p-4 border-b border-white/[0.06]">
          <div className="relative max-w-md">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30" />
            <input type="text" value={search} onChange={e => { setSearch(e.target.value); setPage(1) }}
              placeholder="Поиск по имени или username..." className="input-field !pl-9 !py-2 text-sm" />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/[0.06]">
                <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Контакт</th>
                <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Платформа</th>
                <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Сообщений</th>
                <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Первый контакт</th>
                <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Профиль</th>
              </tr>
            </thead>
            <tbody>
              {paged.map(c => {
                const link = profileLink(c)
                return (
                  <tr key={c.id} className="border-b border-white/[0.04] hover:bg-white/[0.02] transition-colors">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-xl bg-white/[0.06] flex items-center justify-center shrink-0">
                          <User size={16} className="text-white/40" />
                        </div>
                        <span className="text-sm font-medium">{displayName(c)}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      {c.platform === 'instagram' ? <IgBadge /> : <MsgBadge />}
                    </td>
                    <td className="px-4 py-3 text-sm text-white/50">{c.message_count ?? '—'}</td>
                    <td className="px-4 py-3 text-sm text-white/50">
                      {c.created_at ? new Date(c.created_at).toLocaleDateString('ru') : '—'}
                    </td>
                    <td className="px-4 py-3">
                      {link ? (
                        <a href={link} target="_blank" rel="noopener noreferrer"
                          className="text-pink-400 hover:text-pink-300 transition-colors">
                          <ExternalLink size={16} />
                        </a>
                      ) : <span className="text-white/20">—</span>}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-white/[0.06]">
            <span className="text-xs text-white/30">{filtered.length} контактов</span>
            <div className="flex items-center gap-2">
              <button onClick={() => setPage(Math.max(1, page - 1))} disabled={page === 1}
                className="p-1.5 rounded-lg hover:bg-white/5 text-white/40 disabled:opacity-30">
                <ChevronLeft size={16} />
              </button>
              <span className="text-sm text-white/60">Стр. {page}/{totalPages}</span>
              <button onClick={() => setPage(Math.min(totalPages, page + 1))} disabled={page === totalPages}
                className="p-1.5 rounded-lg hover:bg-white/5 text-white/40 disabled:opacity-30">
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
