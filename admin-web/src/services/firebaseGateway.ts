import { initializeApp, type FirebaseOptions } from 'firebase/app';
import { GoogleAuthProvider, getAuth, onAuthStateChanged, signInWithPopup, signOut } from 'firebase/auth';
import { collection, doc, getDoc, getDocs, getFirestore, limit, onSnapshot, orderBy, query, runTransaction, serverTimestamp, updateDoc } from 'firebase/firestore';
import { fetchAndActivate, getRemoteConfig, getValue, isSupported } from 'firebase/remote-config';
import { date, parseAnalysis, parseReference, parseTopic, type WeakRule } from '../domain/analysis';
import type { AdminGateway } from './gateway';
import { invalidWebAppId, missingConfig, requiredConfig } from './firebaseConfig';
import { normalizeDraft, parseAnnouncement, validateDraft } from '../domain/notifications';
import { parseWorker } from '../domain/workers';
import { parseUser } from '../domain/users';
import { normalizeAction, parseAction, validateAction } from '../domain/actions';

let gateway: AdminGateway | undefined;

/** Initialize only after setup is complete; demo mode never calls this function. */
export function getFirebaseGateway(): AdminGateway {
  if (gateway) return gateway;
  if (missingConfig.length || invalidWebAppId) throw new Error('Firebase Web app configuration is required.');
  const options: FirebaseOptions = {
    apiKey: requiredConfig.VITE_FIREBASE_API_KEY,
    authDomain: requiredConfig.VITE_FIREBASE_AUTH_DOMAIN,
    projectId: requiredConfig.VITE_FIREBASE_PROJECT_ID,
    appId: requiredConfig.VITE_FIREBASE_APP_ID,
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
    storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  };
  const app = initializeApp(options, 'realtron-admin-web');
  const auth = getAuth(app);
  const db = getFirestore(app);

  async function weakRule(): Promise<WeakRule> {
    const defaults = { threshold: 0.5, minRefs: 3 };
    try {
      if (!await isSupported()) return defaults;
      const config = getRemoteConfig(app);
      config.defaultConfig = { weak_topic_threshold: 0.5, weak_topic_min_refs: 3 };
      config.settings.fetchTimeoutMillis = 5000;
      config.settings.minimumFetchIntervalMillis = 60000;
      await fetchAndActivate(config);
      const threshold = getValue(config, 'weak_topic_threshold').asNumber();
      const minRefs = getValue(config, 'weak_topic_min_refs').asNumber();
      return { threshold: Number.isFinite(threshold) && threshold >= 0 && threshold <= 1 ? threshold : defaults.threshold,
        minRefs: Number.isFinite(minRefs) && minRefs >= 1 ? Math.floor(minRefs) : defaults.minRefs };
    } catch { return defaults; }
  }

  gateway = {
    watchAuth: (next, error) => onAuthStateChanged(auth, (user) => next(user ? {
      uid: user.uid, name: user.displayName || user.email || 'Administrator', email: user.email,
    } : null), error),
    watchRole: (uid, next, error) => onSnapshot(doc(db, 'users', uid), (snapshot) => {
      next(snapshot.data()?.role === 'admin' ? 'admin' : 'user');
    }, error),
    async signIn() {
      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: 'select_account' });
      const { user } = await signInWithPopup(auth, provider);
      // Provision only the caller's profile, always as user. Rules deny self-promotion.
      await runTransaction(db, async (transaction) => {
        const profile = doc(db, 'users', user.uid);
        if (!(await transaction.get(profile)).exists()) {
          transaction.set(profile, { role: 'user', displayName: user.displayName,
            photoUrl: user.photoURL, createdAt: serverTimestamp() });
        }
      });
    },
    signOut: () => signOut(auth),
    watchUsers: (next, error) => onSnapshot(collection(db, 'adminUserDirectory'), (snapshot) =>
      next(snapshot.docs.map((item) => parseUser(item.id, item.data()))), error),
    // The directory now lists admins too; announcements only ever go to regular users.
    watchRecipients: (next, error) => onSnapshot(collection(db, 'adminUserDirectory'), (snapshot) => next(snapshot.docs
      .map((item) => parseUser(item.id, item.data())).filter((user) => user.role === 'user')
      .map(({ uid, name, hasDevice }) => ({ uid, name, hasDevice })).sort((a, b) => a.name.localeCompare(b.name))), error),
    watchAnnouncements: (next, error) => onSnapshot(query(collection(db, 'adminNotificationRequests'), orderBy('createdAt', 'desc'), limit(30)),
      (snapshot) => next(snapshot.docs.map((item) => parseAnnouncement(item.id, item.data()))), error),
    async queueAnnouncement(id, raw) {
      const draft = normalizeDraft(raw);
      const problem = validateDraft(draft);
      if (problem) throw new Error(problem);
      const uid = auth.currentUser?.uid;
      if (!uid) throw Object.assign(new Error('Sign in first.'), { code: 'auth/user-signed-out' });
      // A transaction creates once, and a retry of the same operation only reads.
      // Unlike an offline setDoc, it cannot silently queue a send for much later.
      await runTransaction(db, async (transaction) => {
        const reference = doc(db, 'adminNotificationRequests', id);
        const existing = await transaction.get(reference);
        if (existing.exists()) {
          const data = existing.data();
          const stored = normalizeDraft({ ...data, sendAt: date(data.sendAt) ?? undefined } as typeof draft);
          if (data.requestedBy !== uid || JSON.stringify(stored) !== JSON.stringify(draft)) {
            throw new Error('This request ID belongs to a different message.');
          }
          return;
        }
        transaction.set(reference, { ...draft, requestedBy: uid, status: 'queued', createdAt: serverTimestamp() });
      }, { maxAttempts: 3 });
    },
    async cancelAnnouncement(id) {
      const uid = auth.currentUser?.uid;
      if (!uid) throw Object.assign(new Error('Sign in first.'), { code: 'auth/user-signed-out' });
      // Rules accept this only while the request is still queued.
      await updateDoc(doc(db, 'adminNotificationRequests', id), { status: 'cancelled', cancelledBy: uid, cancelledAt: serverTimestamp() });
    },
    watchAnalyses: (next, error) => onSnapshot(collection(db, 'analyses'), { includeMetadataChanges: true }, (snapshot) => {
      next({ analyses: snapshot.docs.map((item) => parseAnalysis(item.id, item.data())),
        fromCache: snapshot.metadata.fromCache });
    }, error),
    getWeakRule: weakRule,
    watchWorkers: (next, error) => onSnapshot(collection(db, 'workerStatus'), (snapshot) => next(snapshot.docs.map((item) => parseWorker(item.id, item.data()))), error),
    watchActions: (next, error) => onSnapshot(query(collection(db, 'adminActions'), orderBy('createdAt', 'desc'), limit(50)),
      (snapshot) => next(snapshot.docs.map((item) => parseAction(item.id, item.data()))), error),
    async requestAction(id, raw) {
      const draft = normalizeAction(raw);
      const uid = auth.currentUser?.uid;
      if (!uid) throw Object.assign(new Error('Sign in first.'), { code: 'auth/user-signed-out' });
      const problem = validateAction(draft, uid);
      if (problem) throw new Error(problem);
      // Same pattern as announcements: create once, a retry of this ID only reads.
      await runTransaction(db, async (transaction) => {
        const reference = doc(db, 'adminActions', id);
        const existing = await transaction.get(reference);
        if (existing.exists()) {
          const data = existing.data();
          if (data.requestedBy !== uid || data.type !== draft.type || data.target !== draft.target) throw new Error('This request ID belongs to a different action.');
          return;
        }
        transaction.set(reference, { ...draft, requestedBy: uid, status: 'queued', createdAt: serverTimestamp() });
      }, { maxAttempts: 3 });
    },
    async getResults(id) {
      const [paper, references, topics, rule] = await Promise.all([
        getDoc(doc(db, 'analyses', id)),
        getDocs(collection(db, 'analyses', id, 'references')),
        getDocs(collection(db, 'analyses', id, 'topics')),
        weakRule(),
      ]);
      if (!paper.exists()) throw Object.assign(new Error('Analysis not found.'), { code: 'not-found' });
      return { analysis: parseAnalysis(paper.id, paper.data()),
        references: references.docs.map((item) => parseReference(item.id, item.data())),
        topics: topics.docs.map((item) => parseTopic(item.id, item.data())), weakRule: rule };
    },
  };
  return gateway;
}
