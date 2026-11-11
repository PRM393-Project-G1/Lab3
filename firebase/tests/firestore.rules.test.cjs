const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { before, beforeEach, after, test } = require('node:test');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const {
  collection, doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, serverTimestamp,
} = require('firebase/firestore');

let environment;
let admin;
let user;

before(async () => {
  // Deliberately refuse to run without the local emulator.
  const address = process.env.FIRESTORE_EMULATOR_HOST;
  if (!address) throw new Error('Run through npm run test:rules; an emulator is required.');
  const [host, port] = address.split(':');
  environment = await initializeTestEnvironment({
    projectId: 'demo-realtron-admin',
    firestore: {
      host, port: Number(port),
      rules: readFileSync(join(__dirname, '../firestore.rules'), 'utf8'),
    },
  });
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, 'users/admin'), { role: 'admin' }),
      setDoc(doc(db, 'users/user'), { role: 'user' }),
      setDoc(doc(db, 'analyses/1706.03762'), { status: 'done' }),
      setDoc(doc(db, 'analyses/1706.03762/references/ref-001'), { status: 'verified' }),
      setDoc(doc(db, 'analyses/1706.03762/topics/topic-1'), { term: 'Attention' }),
      setDoc(doc(db, 'users/user/library/1706.03762'), { customTitle: 'My paper' }),
    ]);
  });
  admin = environment.authenticatedContext('admin').firestore();
  user = environment.authenticatedContext('user').firestore();
});

after(async () => { await environment?.cleanup(); });

beforeEach(async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/admin'), { role: 'admin' });
  });
});

test('only admin can list all analysis documents', async () => {
  await assertSucceeds(getDocs(collection(admin, 'analyses')));
  await assertFails(getDocs(collection(user, 'analyses')));
  const anonymous = environment.unauthenticatedContext().firestore();
  await assertFails(getDocs(collection(anonymous, 'analyses')));
  await assertFails(getDoc(doc(anonymous, 'analyses/1706.03762')));
  const missingRole = environment.authenticatedContext('missing-profile').firestore();
  await assertFails(getDocs(collection(missingRole, 'analyses')));
});

test('users retain lookup, reference and topic access for the existing app', async () => {
  await assertSucceeds(getDoc(doc(user, 'analyses/1706.03762')));
  await assertSucceeds(getDocs(collection(user, 'analyses/1706.03762/references')));
  await assertSucceeds(getDocs(collection(user, 'analyses/1706.03762/topics')));
});

test('clients cannot create or modify analyses, even as admin', async () => {
  for (const db of [admin, user]) {
    await assertFails(setDoc(doc(db, 'analyses/client-created'), { status: 'done' }));
    await assertFails(updateDoc(doc(db, 'analyses/1706.03762'), { status: 'failed' }));
    await assertFails(deleteDoc(doc(db, 'analyses/1706.03762')));
    await assertFails(setDoc(doc(db, 'analyses/1706.03762/topics/injected'), { term: 'Fake' }));
  }
});

test('a client cannot grant itself admin or change an assigned role', async () => {
  await assertFails(updateDoc(doc(user, 'users/user'), { role: 'admin' }));
  const newcomer = environment.authenticatedContext('newcomer').firestore();
  await assertFails(setDoc(doc(newcomer, 'users/newcomer'), { role: 'admin' }));
  await assertSucceeds(setDoc(doc(newcomer, 'users/newcomer'), { role: 'user' }));
  await assertSucceeds(updateDoc(doc(admin, 'users/admin'), { displayName: 'Admin' }));
  await assertFails(updateDoc(doc(admin, 'users/admin'), { role: 'user' }));
});

test('admin monitoring does not expose another user profile or library', async () => {
  await assertFails(getDoc(doc(admin, 'users/user')));
  await assertFails(getDocs(collection(admin, 'users/user/library')));
  await assertSucceeds(getDocs(collection(user, 'users/user/library')));
});

test('revoked role loses permission on the next collection request', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'users/admin'), { role: 'user' });
  });
  await assertFails(getDocs(collection(admin, 'analyses')));
});

const announcement = (overrides = {}) => ({
  title: 'Project update', body: 'A useful message', audience: 'all', recipientUids: [],
  requestedBy: 'admin', status: 'queued', createdAt: serverTimestamp(), ...overrides,
});

test('only admin can create and read an announcement request', async () => {
  const path = 'adminNotificationRequests/rules-announcement-valid-1234';
  await assertSucceeds(setDoc(doc(admin, path), announcement()));
  await assertSucceeds(getDocs(collection(admin, 'adminNotificationRequests')));
  await assertFails(getDoc(doc(user, path)));
  await assertFails(setDoc(doc(user, 'adminNotificationRequests/rules-user-forged-request-1234'), announcement({ requestedBy: 'user' })));
  await assertFails(setDoc(doc(environment.unauthenticatedContext().firestore(), 'adminNotificationRequests/rules-anonymous-request-1234'), announcement()));
});

test('selected audience, server timestamp and immutable payload are enforced', async () => {
  const path = 'adminNotificationRequests/rules-selected-announcement-1234';
  await assertSucceeds(setDoc(doc(admin, path), announcement({ audience: 'selected', recipientUids: ['user'] })));
  await assertFails(updateDoc(doc(admin, path), { title: 'Changed content' }));
  await assertFails(updateDoc(doc(admin, path), { status: 'completed', counts: { pushAccepted: 100 } }));
  await assertFails(deleteDoc(doc(admin, path)));
  const invalid = [
    { requestedBy: 'someone-else' }, { status: 'completed' }, { createdAt: new Date(2000, 0, 1) },
    { title: '' }, { body: 'x'.repeat(501) }, { audience: 'all', recipientUids: ['user'] },
    { audience: 'selected', recipientUids: [] }, { audience: 'selected', recipientUids: ['user', 'user'] },
    { counts: { pushAccepted: 100 } }, { recipientUids: 'not-an-array' },
  ];
  for (let i = 0; i < invalid.length; i++) {
    await assertFails(setDoc(doc(admin, `adminNotificationRequests/rules-invalid-request-number-${i}`), announcement(invalid[i])));
  }
});

test('directory is admin-readable and server-writable without exposing profiles', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'adminUserDirectory/user'), { displayName: 'User', hasDevice: true });
  });
  await assertSucceeds(getDocs(collection(admin, 'adminUserDirectory')));
  await assertFails(getDocs(collection(user, 'adminUserDirectory')));
  await assertFails(setDoc(doc(admin, 'adminUserDirectory/injected'), { displayName: 'Fake' }));
  await assertFails(getDoc(doc(admin, 'users/user')));
});
