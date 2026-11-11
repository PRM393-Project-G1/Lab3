import { useEffect, useState } from 'react';
import type { AdminGateway, AdminUser, Unsubscribe } from '../services/gateway';
import { errorMessage } from '../services/gateway';

export type Access =
  | { status: 'loading' }
  | { status: 'signed-out' }
  | { status: 'denied'; user: AdminUser }
  | { status: 'allowed'; user: AdminUser }
  | { status: 'error'; message: string };

/** Tear down role observers on account changes; stale callbacks cannot grant access. */
export function useAccess(gateway: AdminGateway, retry: number): Access {
  const [access, setAccess] = useState<Access>({ status: 'loading' });
  useEffect(() => {
    let active = true;
    let roleVersion = 0;
    let stopRole: Unsubscribe | undefined;
    setAccess({ status: 'loading' });
    const stopAuth = gateway.watchAuth((user) => {
      const version = ++roleVersion;
      stopRole?.();
      stopRole = undefined;
      if (!active) return;
      if (!user) { setAccess({ status: 'signed-out' }); return; }
      setAccess({ status: 'loading' });
      stopRole = gateway.watchRole(user.uid, (role) => {
        if (active && version === roleVersion) setAccess({ status: role === 'admin' ? 'allowed' : 'denied', user });
      }, (error) => {
        if (active && version === roleVersion) setAccess({ status: 'error', message: errorMessage(error) });
      });
    }, (error) => {
      ++roleVersion;
      stopRole?.();
      if (active) setAccess({ status: 'error', message: errorMessage(error) });
    });
    return () => { active = false; ++roleVersion; stopRole?.(); stopAuth(); };
  }, [gateway, retry]);
  return access;
}
