import { useCallback, useEffect, useMemo, useState } from 'react';
import { authApi } from '../api/auth';
import {
  clearSessionStorage,
  getStoredUser,
  getToken,
  storeToken,
  storeUser,
} from '../api/client';
import { AuthContext } from './auth-context';

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => getToken());
  const [user, setUser] = useState(() => getStoredUser());
  const [loading, setLoading] = useState(() => Boolean(getToken()));

  const clearSession = useCallback(() => {
    clearSessionStorage();
    setToken(null);
    setUser(null);
    setLoading(false);
  }, []);

  const applySession = useCallback((auth) => {
    storeToken(auth.accessToken);
    storeUser(auth.user);
    setToken(auth.accessToken);
    setUser(auth.user);
    setLoading(false);
  }, []);

  useEffect(() => {
    if (!token) {
      setLoading(false);
      return undefined;
    }

    let active = true;
    setLoading(true);

    authApi
      .me()
      .then((profile) => {
        if (!active) return;
        storeUser(profile);
        setUser(profile);
      })
      .catch(() => {
        if (active) clearSession();
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [token, clearSession]);

  useEffect(() => {
    const handleUnauthorized = () => clearSession();
    window.addEventListener('stockmate:unauthorized', handleUnauthorized);
    return () => window.removeEventListener('stockmate:unauthorized', handleUnauthorized);
  }, [clearSession]);

  const login = useCallback(
    async (email, password) => {
      const auth = await authApi.login({ email, password });
      applySession(auth);
      return auth;
    },
    [applySession],
  );

  const register = useCallback(
    async (name, email, password) => {
      const auth = await authApi.register({ name, email, password });
      applySession(auth);
      return auth;
    },
    [applySession],
  );

  const value = useMemo(
    () => ({
      user,
      token,
      loading,
      isAuthenticated: Boolean(token),
      login,
      register,
      logout: clearSession,
    }),
    [user, token, loading, login, register, clearSession],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
