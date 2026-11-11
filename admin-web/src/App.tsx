import { useEffect, useState, type ReactNode } from 'react';
import { ArrowRight, ArrowUpRight, BarChart3, Bell, BookOpen, Check, FlaskConical, LayoutDashboard, LogOut, Menu, ShieldCheck, X, type LucideIcon } from 'lucide-react';
import { Link, Route, Routes, useLocation } from 'react-router-dom';
import { StatePanel } from './components/ui';
import { Dashboard } from './pages/Dashboard';
import { AnalysisDetail } from './pages/AnalysisDetail';
import { Insights } from './pages/Insights';
import { Notifications } from './pages/Notifications';

/** Sidebar order; the first entry is the workspace root. */
const sections: { path: string; label: string; icon: LucideIcon }[] = [
  { path: '', label: 'Overview', icon: LayoutDashboard },
  { path: 'insights', label: 'Insights', icon: BarChart3 },
  { path: 'notifications', label: 'Notifications', icon: Bell },
];
import { useAccess } from './hooks/useAccess';
import { demoGateway } from './services/demoGateway';
import { invalidWebAppId, missingConfig } from './services/firebaseConfig';
import { errorMessage, type AdminGateway, type AdminUser } from './services/gateway';

export function App() {
  return <Routes>
    <Route path="/demo/*" element={<AccessGate gateway={demoGateway} demo />} />
    <Route path="/*" element={<LiveEntry />} />
  </Routes>;
}

function Brand({ inverse = false }: { inverse?: boolean }) {
  return <span className={`brand ${inverse ? 'inverse' : ''}`}><span className="brand-mark"><BookOpen size={22} strokeWidth={1.7} /></span><span>Realtron<span className="brand-period">.</span></span></span>;
}

function LiveEntry() {
  const [connection, setConnection] = useState<AdminGateway | null>(null);
  const [initializationFailed, setInitializationFailed] = useState(false);
  const [retry, setRetry] = useState(0);
  const configured = !missingConfig.length && !invalidWebAppId;
  useEffect(() => {
    if (!configured) return;
    let active = true;
    setInitializationFailed(false);
    import('./services/firebaseGateway').then(({ getFirebaseGateway }) => {
      if (active) setConnection(getFirebaseGateway());
    }).catch(() => { if (active) setInitializationFailed(true); });
    return () => { active = false; };
  }, [configured, retry]);
  if (!configured) return <LoginFrame><span className="eyebrow">ADMIN WORKSPACE</span><h1>Your papers.<br />A clearer perspective.</h1>
    <p className="login-description">Monitor analysis activity, explore topic maps and review reference checks in one workspace.</p>
    <div className="setup-notice"><ShieldCheck size={20} /><div><strong>Connect your Firebase Web app</strong><p>{invalidWebAppId ? 'Use a Web app ID, not the Android app ID.' : 'Add your Web app configuration to admin-web/.env.local to enable Google sign-in.'}</p>
      {missingConfig.length > 0 && <code>{missingConfig.join(', ')}</code>}</div></div>
    <Link className="button primary full-width" to="/demo">Explore demo workspace<ArrowRight size={17} /></Link>
    <p className="login-small">Try all dashboard features with clearly labeled sample data. No Firebase setup needed.</p>
    <details className="setup-guide"><summary>How to connect the real project</summary><ol>
      <li>Firebase Console → Project settings → add a Web app to <code>realtron-874ac</code>.</li>
      <li>Copy <code>.env.example</code> to <code>.env.local</code>, fill in the Web app config and restart Vite.</li>
      <li>Enable Google sign-in and authorize <code>localhost</code>.</li>
      <li>Publish the project’s Firestore Rules and assign your account <code>role: admin</code>.</li>
    </ol></details>
  </LoginFrame>;
  if (initializationFailed) return <LoginFrame><StatePanel title="Couldn’t connect the workspace" retry={() => setRetry((value) => value + 1)}>Check your Firebase Web configuration and network connection.</StatePanel></LoginFrame>;
  if (!connection) return <LoginFrame><StatePanel title="Connecting workspace" loading /></LoginFrame>;
  return <AccessGate gateway={connection} />;
}

export function AccessGate({ gateway, demo = false }: { gateway: AdminGateway; demo?: boolean }) {
  const [retry, setRetry] = useState(0);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState('');
  const access = useAccess(gateway, retry);
  async function signIn() {
    setActionError(''); setBusy(true);
    try { await gateway.signIn(); } catch (error) { setActionError(errorMessage(error)); }
    finally { setBusy(false); }
  }
  async function signOut() {
    setActionError(''); setBusy(true);
    try { await gateway.signOut(); } catch (error) { setActionError(errorMessage(error)); }
    finally { setBusy(false); }
  }
  if (access.status === 'allowed') return <Workspace key={access.user.uid} gateway={gateway} user={access.user} demo={demo} />;
  if (access.status === 'loading') return <LoginFrame><StatePanel title="Checking workspace access" loading>Verifying your account and admin role.</StatePanel></LoginFrame>;
  if (access.status === 'error') return <LoginFrame><StatePanel title="Couldn’t verify access" retry={() => setRetry((value) => value + 1)}>{access.message}</StatePanel>
    <button className="button secondary full-width" disabled={busy} onClick={signOut}>Sign out</button>{actionError && <p role="alert" className="form-error">{actionError}</p>}</LoginFrame>;
  if (access.status === 'denied') return <LoginFrame><div className="access-symbol"><ShieldCheck size={28} /></div><h1>Admin access required.</h1>
    <p className="login-description">You’re signed in as <strong>{access.user.email || access.user.name}</strong>. This account has not been granted access to the admin workspace.</p>
    <div className="account-id"><span>Your user ID</span><code>{access.user.uid}</code></div>
    <p className="login-small">Ask the Firebase project owner to set your user document’s role to <code>admin</code>. Access updates automatically.</p>
    {actionError && <p role="alert" className="form-error">{actionError}</p>}
    <button className="button primary full-width" disabled={busy} onClick={signOut}><LogOut size={16} />Sign out / change account</button>
    <Link to="/demo" className="text-link centered">Explore the sample workspace<ArrowRight size={15} /></Link>
  </LoginFrame>;
  return <LoginFrame><span className="eyebrow">ADMIN WORKSPACE</span><h1>A little oversight.<br />A lot more clarity.</h1>
    <p className="login-description">Sign in to follow paper analyses and see what every reference stands on.</p>
    {actionError && <p role="alert" className="form-error">{actionError}</p>}
    <button className="button primary full-width" disabled={busy} onClick={signIn}><GoogleMark />{busy ? 'Signing in…' : 'Continue with Google'}</button>
    <p className="login-small"><ShieldCheck size={14} />Access is limited to approved Realtron administrators.</p>
    <Link to="/demo" className="text-link centered">Explore the sample workspace<ArrowRight size={15} /></Link>
  </LoginFrame>;
}

function LoginFrame({ children }: { children: ReactNode }) {
  return <main className="login-page"><section className="login-story"><Brand inverse />
    <div className="story-copy"><span className="story-overline">KNOW WHAT A PAPER STANDS ON</span><h2>Better context.<br />Stronger understanding.</h2><p>From the references behind a paper to the ideas that connect them.</p>
      <div className="story-features"><span><Check size={16} />Reference verification</span><span><Check size={16} />Topic exploration</span><span><Check size={16} />Analysis monitoring</span></div></div>
    <span className="story-footer">REALTRON / ACADEMIC VERIFIER</span></section>
    <section className="login-content"><div className="mobile-brand"><Brand /></div><div className="login-card">{children}</div><p className="login-footer">Realtron · Admin workspace</p></section></main>;
}

function GoogleMark() {
  return <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M21.6 12.2c0-.7-.1-1.4-.2-2.1H12v4h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.8 3-4.3 3-7.4ZM12 22c2.7 0 5-1 6.6-2.4l-3.2-2.5c-.9.6-2 1-3.4 1a6 6 0 0 1-5.7-4.2H3v2.6A10 10 0 0 0 12 22ZM6.3 14a6 6 0 0 1 0-4V7.4H3a10 10 0 0 0 0 9.2L6.3 14ZM12 6c1.5 0 2.8.5 3.9 1.5l2.9-2.8A9.5 9.5 0 0 0 12 2a10 10 0 0 0-9 5.4L6.3 10A6 6 0 0 1 12 6Z" /></svg>;
}

function Workspace({ gateway, user, demo }: { gateway: AdminGateway; user: AdminUser; demo: boolean }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [signingOut, setSigningOut] = useState(false);
  const [failure, setFailure] = useState('');
  const location = useLocation();
  const base = demo ? '/demo' : '/';
  const prefix = demo ? '/demo' : '';
  const detail = location.pathname.includes('/analyses/');
  const section = sections.find((item) => item.path && location.pathname.endsWith(`/${item.path}`)) ?? sections[0];
  async function leave() {
    setSigningOut(true); setFailure('');
    try { await gateway.signOut(); } catch (error) { setFailure(errorMessage(error)); setSigningOut(false); }
  }
  return <div className="workspace"><a className="skip-link" href="#main-content">Skip to content</a>
    {menuOpen && <button className="sidebar-scrim" aria-label="Close navigation" onClick={() => setMenuOpen(false)} />}
    <aside id="workspace-navigation" className={`sidebar ${menuOpen ? 'open' : ''}`}><Link to={base} className="brand-link" aria-label="Realtron overview" onClick={() => setMenuOpen(false)}><Brand /></Link>
      <span className="workspace-label">ADMIN WORKSPACE</span><div className="nav-caption">WORKSPACE</div>
      <nav aria-label="Main navigation">{sections.map(({ path, label, icon: Icon }) => {
        const current = section.path === path;
        return <Link key={label} to={path ? `${prefix}/${path}` : base} aria-current={current && !detail ? 'page' : undefined} className={`nav-link ${current ? 'active' : ''}`}
          onClick={() => setMenuOpen(false)}><Icon size={18} />{label}{current && <span className="nav-dot" />}</Link>;
      })}</nav>
      <div className="sidebar-context"><span className="sidebar-context-icon"><BookOpen size={19} /></span><h3>A clearer perspective.</h3><p>Follow the papers.<br />Understand the references.</p></div>
      <div className="sidebar-footer"><span className="avatar">{user.name[0]?.toUpperCase() || 'A'}</span><div><strong>{demo ? 'Demo workspace' : user.name}</strong><span>Administrator</span></div>
        {demo ? <Link to="/" aria-label="Exit demo" className="icon-button"><LogOut size={17} /></Link> : <button aria-label="Sign out" className="icon-button" disabled={signingOut} onClick={leave}><LogOut size={17} /></button>}</div>
    </aside>
    <div className="workspace-body"><header className="workspace-header"><div className="header-left"><button className="icon-button mobile-menu" aria-label={menuOpen ? 'Close navigation' : 'Open navigation'} aria-expanded={menuOpen} aria-controls="workspace-navigation" onClick={() => setMenuOpen(!menuOpen)}>{menuOpen ? <X size={20} /> : <Menu size={20} />}</button>
      <span className="breadcrumb">Workspace<span>/</span><strong>{detail ? 'Paper details' : section.label}</strong></span></div>
      <span className={`workspace-badge ${demo ? 'demo' : ''}`}>{demo ? <FlaskConical size={14} /> : <ShieldCheck size={14} />}{demo ? 'Demo workspace' : 'Admin access'}</span></header>
      {demo && <div className="demo-banner"><span><FlaskConical size={15} /><strong>Sample data</strong><span className="demo-description">Explore freely. This workspace is separate from Firebase.</span></span><Link to="/">Connect real data<ArrowUpRight size={14} /></Link></div>}
      {failure && <p role="alert" className="form-error workspace-error">{failure}</p>}
      <main className="main-content" id="main-content" tabIndex={-1}><Routes>
        <Route index element={<Dashboard gateway={gateway} demo={demo} />} />
        <Route path="analyses/:analysisId" element={<AnalysisDetail gateway={gateway} />} />
        <Route path="insights" element={<Insights gateway={gateway} demo={demo} />} />
        <Route path="notifications" element={<Notifications gateway={gateway} demo={demo} />} />
        <Route path="*" element={<StatePanel title="Page not found"><Link to={base} className="button secondary">Go to overview</Link></StatePanel>} />
      </Routes></main>
    </div>
  </div>;
}
