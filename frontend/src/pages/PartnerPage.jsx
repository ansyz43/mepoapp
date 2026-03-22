import { useEffect, useState } from 'react'
import api from '../api'
import { Copy, Check, Handshake, Users, CreditCard, Activity, ExternalLink } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'
import PageHeader from '../components/ui/PageHeader'
import Loader from '../components/ui/Loader'
import EmptyState from '../components/ui/EmptyState'
import ReferralTree from '../components/ReferralTree'

export default function PartnerPage() {
  const { user } = useAuth()
  const [tab, setTab] = useState('links')
  const [partner, setPartner] = useState(null)
  const [tree, setTree] = useState(null)
  const [cashback, setCashback] = useState([])
  const [sessions, setSessions] = useState([])
  const [loading, setLoading] = useState(true)
  const [copied, setCopied] = useState(null)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    try {
      const { data } = await api.get('/api/referral/partner')
      setPartner(data)
    } catch { /* ignore */ }
    setLoading(false)
  }

  async function loadTree() {
    try { const { data } = await api.get('/api/referral/my-tree'); setTree(data) } catch { /* ignore */ }
  }

  async function loadCashback() {
    try { const { data } = await api.get('/api/referral/my-cashback'); setCashback(data) } catch { /* ignore */ }
  }

  async function loadSessions() {
    try { const { data } = await api.get('/api/referral/sessions'); setSessions(data) } catch { /* ignore */ }
  }

  function handleTab(t) {
    setTab(t)
    if (t === 'tree' && !tree) loadTree()
    if (t === 'cashback' && cashback.length === 0) loadCashback()
    if (t === 'sessions' && sessions.length === 0) loadSessions()
  }

  function copyText(text, key) {
    navigator.clipboard.writeText(text)
    setCopied(key)
    setTimeout(() => setCopied(null), 2000)
  }

  if (loading) return <Loader />

  if (!partner) return (
    <div>
      <PageHeader title="Партнёрская программа" />
      <EmptyState icon={Handshake} title="Вы не партнёр"
        text="Перейдите в каталог каналов, чтобы стать партнёром" />
    </div>
  )

  const refLink = partner.ref_code
    ? `${window.location.origin}/register?ref=${partner.ref_code}`
    : null

  const channelName = partner.channel_name || partner.bot_username || 'Канал'

  return (
    <div>
      <PageHeader title="Партнёрская программа" />

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <div className="stat-card">
          <div className="stat-value">{partner.referral_count ?? 0}</div>
          <div className="stat-label">Рефералов</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{partner.credits_balance ?? 0}</div>
          <div className="stat-label">Кредитов</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{partner.total_cashback ?? 0} ₽</div>
          <div className="stat-label">Заработано</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{channelName}</div>
          <div className="stat-label">Канал</div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 p-1 bg-white/[0.04] rounded-xl mb-6">
        {[
          { key: 'links', label: 'Ссылки', icon: ExternalLink },
          { key: 'tree', label: 'Дерево', icon: Users },
          { key: 'cashback', label: 'Кэшбек', icon: CreditCard },
          { key: 'sessions', label: 'Сессии', icon: Activity },
        ].map(t => (
          <button key={t.key} onClick={() => handleTab(t.key)}
            className={`flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
              tab === t.key ? 'bg-white/[0.08] text-white shadow-sm' : 'text-white/40 hover:text-white/60'
            }`}>
            <t.icon size={14} /> {t.label}
          </button>
        ))}
      </div>

      {/* Links tab */}
      {tab === 'links' && (
        <div className="glass-card p-6 space-y-5">
          <h2 className="font-display font-semibold">Ваши реферальные ссылки</h2>

          {refLink && (
            <div>
              <label className="block text-sm text-white/60 mb-1.5">Ссылка на регистрацию</label>
              <div className="flex items-center gap-2">
                <input type="text" value={refLink} readOnly className="input-field flex-1" />
                <button onClick={() => copyText(refLink, 'ref')}
                  className="flex items-center gap-1.5 px-3 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 text-white/70 text-sm transition-colors whitespace-nowrap">
                  {copied === 'ref' ? <Check size={14} className="text-green-400" /> : <Copy size={14} />}
                  {copied === 'ref' ? 'Скопировано' : 'Копировать'}
                </button>
              </div>
            </div>
          )}

          {partner.ref_code && (
            <div>
              <label className="block text-sm text-white/60 mb-1.5">Реферальный код</label>
              <div className="flex items-center gap-2">
                <input type="text" value={partner.ref_code} readOnly className="input-field flex-1" />
                <button onClick={() => copyText(partner.ref_code, 'code')}
                  className="flex items-center gap-1.5 px-3 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 text-white/70 text-sm transition-colors whitespace-nowrap">
                  {copied === 'code' ? <Check size={14} className="text-green-400" /> : <Copy size={14} />}
                  {copied === 'code' ? 'Скопировано' : 'Копировать'}
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Tree tab */}
      {tab === 'tree' && (
        <div className="glass-card p-6">
          <h2 className="font-display font-semibold mb-4">Дерево рефералов</h2>
          {tree ? <ReferralTree data={tree} /> : (
            <EmptyState icon={Users} title="Нет рефералов" text="Пригласите партнёров по вашей ссылке" />
          )}
        </div>
      )}

      {/* Cashback tab */}
      {tab === 'cashback' && (
        <div className="glass-card overflow-hidden">
          <div className="p-5 border-b border-white/[0.06]">
            <h2 className="font-display font-semibold">История кэшбека</h2>
          </div>
          {cashback.length === 0 ? (
            <div className="p-6">
              <EmptyState icon={CreditCard} title="Нет начислений" text="Кэшбек появится когда ваши рефералы начнут пользоваться сервисом" />
            </div>
          ) : (
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/[0.06]">
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Дата</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Сумма</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Тип</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Описание</th>
                </tr>
              </thead>
              <tbody>
                {cashback.map((c, i) => (
                  <tr key={i} className="border-b border-white/[0.04]">
                    <td className="px-4 py-3 text-sm text-white/50">{new Date(c.created_at).toLocaleDateString('ru')}</td>
                    <td className="px-4 py-3 text-sm font-medium text-emerald-400">+{c.amount} ₽</td>
                    <td className="px-4 py-3 text-sm text-white/50">{c.type}</td>
                    <td className="px-4 py-3 text-sm text-white/40">{c.description || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* Sessions tab */}
      {tab === 'sessions' && (
        <div className="glass-card overflow-hidden">
          <div className="p-5 border-b border-white/[0.06]">
            <h2 className="font-display font-semibold">Сессии рефералов</h2>
          </div>
          {sessions.length === 0 ? (
            <div className="p-6">
              <EmptyState icon={Activity} title="Нет сессий" text="Сессии появятся когда пользователи перейдут по вашей ссылке" />
            </div>
          ) : (
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/[0.06]">
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Дата</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">IP</th>
                  <th className="text-left px-4 py-3 text-xs text-white/40 font-medium">Статус</th>
                </tr>
              </thead>
              <tbody>
                {sessions.map((s, i) => (
                  <tr key={i} className="border-b border-white/[0.04]">
                    <td className="px-4 py-3 text-sm text-white/50">{new Date(s.created_at).toLocaleString('ru')}</td>
                    <td className="px-4 py-3 text-sm text-white/50">{s.ip || '—'}</td>
                    <td className="px-4 py-3">
                      <span className={`text-xs px-2 py-0.5 rounded-full ${
                        s.registered ? 'bg-green-500/10 text-green-400' : 'bg-yellow-500/10 text-yellow-400'
                      }`}>{s.registered ? 'Зарегистрирован' : 'Переход'}</span>
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
