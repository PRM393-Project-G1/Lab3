import { counts, parseAnalysis, parseReference, parseTopic, type AnalysisResults } from '../domain/analysis';
import type { AdminGateway } from './gateway';
import { normalizeDraft, parseAnnouncement, type AnnouncementRequest, type NotificationRecipient } from '../domain/notifications';

const demoRecipients: NotificationRecipient[] = [
  { uid: 'demo-linh', name: 'Linh Nguyen', hasDevice: true },
  { uid: 'demo-hung', name: 'Hung Tran', hasDevice: true },
  { uid: 'demo-khoa', name: 'Khoa Le', hasDevice: false },
];
const announcements: AnnouncementRequest[] = [];
const announcementObservers = new Set<(requests: AnnouncementRequest[]) => void>();

// Deliberately separate from Firebase: these illustrative records never reach a database.
const anchor = Date.now();
const sample = [
  ['1706.03762', 'Attention Is All You Need', ['Ashish Vaswani', 'Noam Shazeer', 'Niki Parmar'], 'done', 41, 2],
  ['1409.0473', 'Neural Machine Translation by Jointly Learning to Align and Translate', ['Dzmitry Bahdanau', 'Kyunghyun Cho', 'Yoshua Bengio'], 'processing', 0, 0],
  ['1508.04025', 'Effective Approaches to Attention-based Neural Machine Translation', ['Minh-Thang Luong', 'Hieu Pham', 'Christopher D. Manning'], 'failed', 0, 0],
  ['1409.3215', 'Sequence to Sequence Learning with Neural Networks', ['Ilya Sutskever', 'Oriol Vinyals', 'Quoc V. Le'], 'done', 31, 1],
  ['1512.03385', 'Deep Residual Learning for Image Recognition', ['Kaiming He', 'Xiangyu Zhang', 'Shaoqing Ren'], 'queued', 0, 0],
  ['1810.04805', 'BERT: Pre-training of Deep Bidirectional Transformers for Language Understanding', ['Jacob Devlin', 'Ming-Wei Chang', 'Kenton Lee'], 'done', 52, 3],
  ['1412.6980', 'Adam: A Method for Stochastic Optimization', ['Diederik P. Kingma', 'Jimmy Ba'], 'done', 36, 0],
  ['1607.06450', 'Layer Normalization', ['Jimmy Lei Ba', 'Jamie Ryan Kiros', 'Geoffrey E. Hinton'], 'cancelled', 0, 0],
  ['1301.3781', 'Efficient Estimation of Word Representations in Vector Space', ['Tomas Mikolov', 'Kai Chen', 'Greg Corrado'], 'done', 18, 0],
  ['1406.2661', 'Generative Adversarial Nets', ['Ian Goodfellow', 'Jean Pouget-Abadie', 'Mehdi Mirza'], 'done', 27, 1],
  ['1511.06434', 'Unsupervised Representation Learning with Deep Convolutional Generative Adversarial Networks', ['Alec Radford', 'Luke Metz', 'Soumith Chintala'], 'done', 24, 0],
  ['1502.03167', 'Batch Normalization: Accelerating Deep Network Training', ['Sergey Ioffe', 'Christian Szegedy'], 'failed', 0, 0],
] as const;

// Spread over about two weeks so the insight charts have a shape to show.
const fabricated: Record<string, number> = { '1810.04805': 2, '1406.2661': 1 };
const failures: Record<string, string> = {
  '1508.04025': "Couldn't extract topics. Check the Saffron service and try again from the user app.",
  '1502.03167': 'The server restarted. Try again.',
};
const analyses = sample.map(([id, title, authors, status, refs, issues], index) => {
  const requested = anchor - index * 3600000 * 29;
  const hallucinated = fabricated[id] ?? 0;
  return parseAnalysis(id, {
    paperTitle: title, paperAuthors: [...authors], status,
    createdAt: new Date(requested),
    finishedAt: status === 'done' ? new Date(requested + (3 + refs / 3) * 60000) : null,
    summary: { totalRefs: refs, verified: Math.max(0, refs - issues - hallucinated - (refs ? 2 : 0)), error: issues,
      warning: refs ? 1 : 0, unverified: refs ? 1 : 0, hallucinated },
    progress: { percent: status === 'processing' ? 64 : status === 'done' ? 100 : 0,
      stage: status === 'processing' ? 'fulltext' : 'references' },
    error: status === 'failed' ? failures[id] : null,
  });
});

function results(id: string): AnalysisResults {
  const analysis = analyses.find((item) => item.id === id);
  if (!analysis) throw Object.assign(new Error('Not found'), { code: 'not-found' });
  const { hallucinated, error } = analysis.counts;
  const references = Array.from({ length: analysis.totalRefs }, (_, index) => {
    const status = index < hallucinated ? 'hallucinated' : index < hallucinated + error ? 'error' : index === hallucinated + error ? 'warning'
      : index === hallucinated + error + 1 ? 'unverified' : 'verified';
    const titles = ['Sequence to Sequence Learning with Neural Networks', 'Neural Machine Translation by Jointly Learning to Align and Translate',
      'Adam: A Method for Stochastic Optimization', 'Layer Normalization', 'Deep Residual Learning for Image Recognition'];
    const reference = parseReference(`ref-${String(index + 1).padStart(3, '0')}`, {
      index: index + 1, title: titles[index % titles.length], authors: ['Sample reference author'], year: 2014 + index % 3,
      status, topicIds: [index < 3 ? 'attention' : index % 2 ? 'optimization' : 'representation'],
      issues: status === 'error' ? [{ type: 'year', message: 'Publication year differs from the source record.', cited: '2013', actual: '2014' }]
        : status === 'warning' ? [{ type: 'title', message: 'Minor title formatting difference.' }] : [],
      hallucination: status === 'hallucinated' ? { explanation: 'No publication with this title, venue and author list could be found.' } : null,
    });
    return reference;
  });
  const topics = analysis.status === 'done' ? [
    parseTopic('learning', { term: 'Machine learning', counts: counts({}) }),
    ...[['attention', 'Attention mechanisms'], ['optimization', 'Optimization'], ['representation', 'Representation learning']].map(([topicId, term]) =>
      parseTopic(topicId, { term, parentId: 'learning', refIds: references.filter((r) => r.topicIds.includes(topicId)).map((r) => r.id) })),
  ] : [];
  return { analysis, references, topics, weakRule: { threshold: 0.5, minRefs: 3 } };
}

export const demoGateway: AdminGateway = {
  watchAuth(next) { next({ uid: 'demo-admin', name: 'Demo administrator', email: 'admin@example.test' }); return () => {}; },
  watchRole(_uid, next) { next('admin'); return () => {}; },
  async signIn() {}, async signOut() {},
  watchAnalyses(next) { next({ analyses, fromCache: false }); return () => {}; },
  async getResults(id) { return results(id); },
  watchRecipients(next) { next(demoRecipients); return () => {}; },
  watchAnnouncements(next) { announcementObservers.add(next); next([...announcements]); return () => { announcementObservers.delete(next); }; },
  async queueAnnouncement(id, raw) {
    if (announcements.some((item) => item.id === id)) return;
    const draft = normalizeDraft(raw);
    const recipients = draft.audience === 'all' ? demoRecipients : demoRecipients.filter((user) => draft.recipientUids.includes(user.uid));
    const withDevice = recipients.filter((user) => user.hasDevice).length;
    announcements.unshift(parseAnnouncement(id, { ...draft, requestedBy: 'demo-admin', createdAt: new Date(), status: 'completed',
      counts: { recipients: recipients.length, inboxStored: recipients.length, pushAccepted: withDevice, withoutDevice: recipients.length - withDevice } }));
    announcementObservers.forEach((next) => next([...announcements]));
  },
};
