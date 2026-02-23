import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    tps_1500_test: {
      executor: 'constant-arrival-rate',
      rate: 6600,          // 🎯 목표 TPS
      timeUnit: '1s',
      duration: '5m',
      preAllocatedVUs: 1200,
      maxVUs: 2000,
    },
  },

  thresholds: {
    // ✅ 실패율 = 실패횟수 / 전체요청
    http_req_failed: ['rate<0.01'], // 실패율 < 1%

    // ✅ Latency 지표 (초 단위)
    http_req_duration: [
      'p(50)<0.2',   // P50 < 200ms
      'p(75)<0.5',   // P75 < 500ms
      'p(90)<1.5',   // P90 < 1.5s
      'p(95)<3',     // P95 < 3s
      'p(99)<6',     // P99 < 6s
    ],
  },
};

export default function () {
  const res = http.post(
    'https://backend.olive0.cloud/oliveyoung/api/orders/complete',
    JSON.stringify({
      productId: 12345,
      quantity: 2,
      isTodayDelivery: true,
      totalPrice: 45000,
      username: 'john_doe',
      phone: '010-1234-5678',
      deliveryTimeSlot: '14:00-16:00',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: '10s',
    }
  );

  // 🔥 200만 성공으로 간주 → 나머지는 전부 실패
  check(res, {
    'status is 200': (r) => r.status === 200,
  });
}