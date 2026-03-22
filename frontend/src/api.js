import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '',
  withCredentials: true,
})

let accessToken = null
let refreshPromise = null

export function setAccessToken(token) { accessToken = token }
export function getAccessToken() { return accessToken }

api.interceptors.request.use(config => {
  if (accessToken) config.headers.Authorization = `Bearer ${accessToken}`
  return config
})

api.interceptors.response.use(
  res => res,
  async error => {
    const orig = error.config
    if (error.response?.status === 401 && !orig._retry) {
      orig._retry = true
      try {
        if (!refreshPromise) {
          const rt = localStorage.getItem('refresh_token')
          if (!rt) throw new Error('No refresh token')
          refreshPromise = api.post('/api/auth/refresh', { refresh_token: rt })
            .then(r => {
              accessToken = r.data.access_token
              localStorage.setItem('refresh_token', r.data.refresh_token)
              return accessToken
            })
            .finally(() => { refreshPromise = null })
        }
        const token = await refreshPromise
        orig.headers.Authorization = `Bearer ${token}`
        return api(orig)
      } catch {
        accessToken = null
        localStorage.removeItem('refresh_token')
        window.location.href = '/login'
        return Promise.reject(error)
      }
    }
    return Promise.reject(error)
  }
)

export default api
