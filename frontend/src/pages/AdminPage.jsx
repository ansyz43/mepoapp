import { useEffect, useState } from 'react'
import api from '../api'
import { Shield, Users, Radio, BarChart3, Search, Trash2, ToggleLeft, ToggleRight, Eye, ChevronLeft, ChevronRight } from 'lucide-react'
import PageHeader from '../components/ui/PageHeader'
import Loader from '../components/ui/Loader'
import EmptyState from '../components/ui/EmptyState'
import StatCard from '../components/ui/StatCard'
import Modal from '../components/ui/Modal'

export default function AdminPage() {
  const [tab, setTab] = useState('stats')
  const [stats, setStats] = useState(null)
  const [users, setUsers] = useState([])
  const [channels, setChannels] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  // User detail
  const [selectedUser, setSelectedUser] = useState(null)
  const [userSearch, setUserSearch] = useState('')
  const [userPage, setUserPage] = useState(1)

  // Channel detail
  const [channelSearch, setChannelSearch] = useState('')
  const [deleteChannel, setDeleteChannel] = useState(null)

  // Conversations viewer
  const [viewContact, setViewContact] = useState(null)
  const [contactMessages, setContactMessages] = useState([])

  useEffect(() => { loadStats() }, [])

  async function loadStats() {
    try { const { data } = await api.get('/api/admin/stats'); setStats(data) } catch { /* ignore */ }
    setLoading(false)
  }

  async function loadUsers() {
    try { const { data } = await api.get('/api/admin/users'); setUsers(data) } catch { /* ignore */ }
  }

  async function loadChannels() {
    try { const { data } = await api.get('/api/admin/channels'); setChannels(data) } catch { /* ignore */ }
  }

  function handleTab(t) {
    setTab(t)
    if (t === 'users' && users.length === 0) loadUsers()
    if (t === 'channels' && channels.length === 0) loadChannels()
  }

  async function toggleUser(id) {
    try {
      await api.patch(`/api/admin/users/${id}/toggle`)
      setSuccess('Статус обновлён')
      loadUsers()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : 'Ошибка')
    }
  }

  async function removeUser(id) {
    try {
      await api.delete(`/api/admin/users/${id}`)
      setSuccess('Пользователь удалён')
      setSelectedUser(null)
      loadUsers()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : 'Ошибка')
    }
  }

  async function removeChannel(id) {
    try {
      await api.delete(`/api/admin/channels/${id}`)
      setSuccess('Канал удалён')
      setDeleteChannel(null)
      loadChannels()
    } catch (err) {
      const d = err.response?.data?.detail
      setError(typeof d === 'string' ? d : 'Ошибка')
    }
  }

  async function viewConversation(contactId) {
    try {
      const { data } = await api.get(`/api/admin/conversations/${contactId}`)
      setContactMessages(data)
      setViewContact(contactId)
    } catch { /* ignore */ }
  }

  useEffect(() => {
    if (success) { const t = setTimeout(() => setSuccess(''), 3000); return () => clearTimeout(t) }
  }, [success])

  if (loading) return <Loader />

  const perPage = 20
  const filteredUsers = users.filter(u =>
    !userSearch || u.email?.toLowerCase().includes(userSearch.toLowerCase()) || u.name?.toLowerCase().includes(userSearch.toLowerCase())
  )
  const totalUserPages = Math.ceil(filteredUsers.length / perPage)
  const pagedUsers = filteredUsers.slice((userPage - 1) * perPage, userPage * perPage)

  const filteredChannels = channels.filter(ch =>
    !channelSearch || (ch.channel_name || ch.bot_username || '').toLowerCase().includes(channelSearch.toLowerCase())
  )

  return (
    <div>
      <PageHeader title="Админ-панель" />

      {error && <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-red-400 text-sm mb-4">{error}</div>}
      {success && <div className="bg-green-500/10 border border-green-500/30 rounded-xl px-4 py-3 text-green-400 text-sm mb-4">{success}</div>}

      {/* Tabs */}
      <div className="flex gap-1 p-1 bg-white/[0.04] rounded-xl mb-6">
        {[
          { key: 'stats', label: 'Статистика', icon: BarChart3 },
          { key: 'users', label: 'Пользователи', icon: Users },
          { key: 'channels', label: 'Каналы', icon: Radio },
        ].map(t => (
          <button key={t.key} onClick={() => handleTab(t.key)}
            className={`flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
              tab === t.key ? 'bg-white/[0.08] text-white shadow-sm' : 'text-white/40 hover:text-white/60'
            }`}>
            <t.icon size={14} /> {t.label}
          </button>
        ))}
      </div>

      {/* Stats tab */}
      {tab === 'stats' && stats && (
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard icon={Users} label="Пользователей" value={stats.total_users ?? 0} />
          <StatCard icon={Radio} label="Каналов" value={stats.total_channels ?? stats.total_bots ?? 0} />
          <StatCard icon={Users} label="Контактов" value={stats.total_contacts ?? 0} />
          <StatCard icon={BarChart3} label="Сообщений" value={stats.total_messages ?? 0} />
        </div>
      )}

      {/* Users tab */}
      {tab === 'users' && (
        <div className="glass-card overflow-hidden">
          <div className="p-4 border-b border-white/[0.06]">
            <div className="relative max-w-md">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30" />
              <input type="text" value={userSearch} onChange={e => { setUserSearch(e.target.value); setUserPage(1) }}
                placeholder="Поиск по email или имени..." className="input-field !pl-9 !py-2 text-sm" />
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/[0.06]">
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">ID</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Email</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Имя</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Каналы</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Статус</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Действия</th>
                </tr>
              </thead>
              <tbody>
                {pagedUsers.map(u => (
                  <tr key={u.id} className="border-b border-white/[0.04] hover:bg-white/[0.02] transition-colors">
                    <td className="px-4 py-3 text-sm text-white/50">{u.id}</td>
                    <td className="px-4 py-3 text-sm">{u.email}</td>
                    <td className="px-4 py-3 text-sm text-white/70">{u.name || '—'}</td>
                    <td className="px-4 py-3 text-sm text-white/50">{u.channels_count ?? u.bots_count ?? 0}</td>
                    <td className="px-4 py-3">
                      <span className={`text-xs px-2 py-0.5 rounded-full ${
                        u.is_active ? 'bg-green-500/10 text-green-400' : 'bg-red-500/10 text-red-400'
                      }`}>{u.is_active ? 'Активен' : 'Заблокирован'}</span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <button onClick={() => toggleUser(u.id)}
                          className="text-white/40 hover:text-white/70 transition-colors" title={u.is_active ? 'Заблокировать' : 'Разблокировать'}>
                          {u.is_active ? <ToggleRight size={18} className="text-green-400" /> : <ToggleLeft size={18} />}
                        </button>
                        <button onClick={() => setSelectedUser(u)}
                          className="text-white/40 hover:text-white/70 transition-colors" title="Подробнее">
                          <Eye size={16} />
                        </button>
                        <button onClick={() => removeUser(u.id)}
                          className="text-white/40 hover:text-red-400 transition-colors" title="Удалить">
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {totalUserPages > 1 && (
            <div className="flex items-center justify-between px-4 py-3 border-t border-white/[0.06]">
              <span className="text-xs text-white/30">{filteredUsers.length} пользователей</span>
              <div className="flex items-center gap-2">
                <button onClick={() => setUserPage(Math.max(1, userPage - 1))} disabled={userPage === 1}
                  className="p-1.5 rounded-lg hover:bg-white/5 text-white/40 disabled:opacity-30">
                  <ChevronLeft size={16} />
                </button>
                <span className="text-sm text-white/60">Стр. {userPage}/{totalUserPages}</span>
                <button onClick={() => setUserPage(Math.min(totalUserPages, userPage + 1))} disabled={userPage === totalUserPages}
                  className="p-1.5 rounded-lg hover:bg-white/5 text-white/40 disabled:opacity-30">
                  <ChevronRight size={16} />
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Channels tab */}
      {tab === 'channels' && (
        <div className="glass-card overflow-hidden">
          <div className="p-4 border-b border-white/[0.06]">
            <div className="relative max-w-md">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-white/30" />
              <input type="text" value={channelSearch} onChange={e => setChannelSearch(e.target.value)}
                placeholder="Поиск каналов..." className="input-field !pl-9 !py-2 text-sm" />
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/[0.06]">
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">ID</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Название</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Платформа</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Владелец</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Контактов</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Действия</th>
                </tr>
              </thead>
              <tbody>
                {filteredChannels.map(ch => (
                  <tr key={ch.id} className="border-b border-white/[0.04] hover:bg-white/[0.02] transition-colors">
                    <td className="px-4 py-3 text-sm text-white/50">{ch.id}</td>
                    <td className="px-4 py-3 text-sm font-medium">{ch.channel_name || ch.bot_username || `#${ch.id}`}</td>
                    <td className="px-4 py-3">
                      <span className={`text-xs px-2 py-0.5 rounded-full ${
                        ch.platform === 'instagram' ? 'bg-pink-500/10 text-pink-400' : 'bg-blue-500/10 text-blue-400'
                      }`}>{ch.platform === 'instagram' ? 'Instagram' : 'Messenger'}</span>
                    </td>
                    <td className="px-4 py-3 text-sm text-white/50">{ch.owner_email || ch.user_id}</td>
                    <td className="px-4 py-3 text-sm text-white/50">{ch.contacts_count ?? 0}</td>
                    <td className="px-4 py-3">
                      <button onClick={() => setDeleteChannel(ch)}
                        className="text-white/40 hover:text-red-400 transition-colors" title="Удалить">
                        <Trash2 size={16} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* User detail modal */}
      <Modal
        open={!!selectedUser}
        onClose={() => setSelectedUser(null)}
        title={`Пользователь #${selectedUser?.id}`}
        actions={
          <button onClick={() => setSelectedUser(null)} className="btn-secondary !py-2 !px-5 text-sm">Закрыть</button>
        }
      >
        {selectedUser && (
          <div className="space-y-3 text-sm">
            <div><span className="text-white/40">Email:</span> <span className="text-white">{selectedUser.email}</span></div>
            <div><span className="text-white/40">Имя:</span> <span className="text-white">{selectedUser.name || '—'}</span></div>
            <div><span className="text-white/40">Регистрация:</span> <span className="text-white">
              {selectedUser.created_at ? new Date(selectedUser.created_at).toLocaleString('ru') : '—'}
            </span></div>
            <div><span className="text-white/40">Каналов:</span> <span className="text-white">{selectedUser.channels_count ?? selectedUser.bots_count ?? 0}</span></div>
            <div><span className="text-white/40">Роль:</span> <span className="text-white">{selectedUser.is_admin ? 'Администратор' : 'Пользователь'}</span></div>
          </div>
        )}
      </Modal>

      {/* Delete channel modal */}
      <Modal
        open={!!deleteChannel}
        onClose={() => setDeleteChannel(null)}
        title="Удалить канал?"
        actions={
          <>
            <button onClick={() => setDeleteChannel(null)} className="btn-secondary !py-2 !px-5 text-sm">Отмена</button>
            <button onClick={() => removeChannel(deleteChannel.id)}
              className="bg-red-500/20 hover:bg-red-500/30 text-red-400 font-medium py-2 px-5 rounded-xl text-sm transition-colors">
              Удалить
            </button>
          </>
        }
      >
        <p className="text-sm text-white/60">
          Канал <strong className="text-white">{deleteChannel?.channel_name || deleteChannel?.bot_username}</strong> и все его данные будут удалены.
        </p>
      </Modal>

      {/* View conversation modal */}
      <Modal
        open={!!viewContact}
        onClose={() => { setViewContact(null); setContactMessages([]) }}
        title="Переписка"
        actions={
          <button onClick={() => { setViewContact(null); setContactMessages([]) }} className="btn-secondary !py-2 !px-5 text-sm">Закрыть</button>
        }
      >
        <div className="max-h-[60vh] overflow-y-auto custom-scrollbar space-y-2">
          {contactMessages.length === 0 ? (
            <p className="text-sm text-white/40 text-center py-4">Нет сообщений</p>
          ) : contactMessages.map((m, i) => (
            <div key={i} className={`flex ${m.role === 'assistant' ? 'justify-start' : 'justify-end'}`}>
              <div className={`max-w-[85%] rounded-2xl px-3 py-2 text-sm ${
                m.role === 'assistant' ? 'bg-white/[0.06] text-white/80' : 'bg-emerald-500/20 text-emerald-100'
              }`}>
                {m.content}
                {m.created_at && <div className="text-[10px] text-white/20 mt-1">{new Date(m.created_at).toLocaleString('ru')}</div>}
              </div>
            </div>
          ))}
        </div>
      </Modal>
    </div>
  )
}
