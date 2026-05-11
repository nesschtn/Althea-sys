// Test de charge k6 - utilise dans la pipeline GitLab CI
// Exec local : k6 run -e TARGET_URL=http://... tests/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

const TARGET_URL = __ENV.TARGET_URL;
if (!TARGET_URL) {
  throw new Error('TARGET_URL non defini');
}

export const options = {
  stages: [
    { duration: '15s', target: 10 },  // montee en charge
    { duration: '30s', target: 30 },  // palier
    { duration: '15s', target: 50 },  // pic
    { duration: '10s', target: 0 },   // descente
  ],
  thresholds: {
    // Seuils = tests reussis ou echoues (utilises par CI)
    http_req_failed:   ['rate<0.01'],          // < 1% d'erreurs
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],
    checks:            ['rate>0.99'],
  },
};

export default function () {
  const res = http.get(TARGET_URL, { timeout: '10s' });
  check(res, {
    'status 200': (r) => r.status === 200,
    'contient projet': (r) => r.body && r.body.includes("Projet d'etude"),
    'header nginx':    (r) => (r.headers['Server'] || '').toLowerCase().includes('nginx'),
  });
  sleep(0.2);
}
