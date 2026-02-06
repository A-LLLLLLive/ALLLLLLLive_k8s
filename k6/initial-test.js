import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    ingress_stress: {
      executor: 'constant-arrival-rate',
      rate: 1500,           // ⭐ 초당 1500 req (확 체감 구간)
      timeUnit: '1s',
      duration: '3m',
      preAllocatedVUs: 300,
      maxVUs: 800,
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.02'],
  },
};

const payload = JSON.stringify({
  message: 'alive-alive-alive-alive-alive',
  data: 'x'.repeat(10 * 1024), // ⭐ 10KB payload → 네트워크 + CPU 압박
});

export default function () {
  const url = 'http://localhost:80'; // ❗ localhost ❌
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
    },
  };

  const res = http.post(url, payload, params);

  check(res, {
    'status 200': (r) => r.status === 200,
  });

  // ❗ sleep 거의 안 줌 → VU가 계속 쏨
  sleep(0.001);
}
