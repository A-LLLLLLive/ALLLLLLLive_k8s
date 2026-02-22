import http from 'k6/http';

export const options = {
  scenarios: {
    tps_1500_test: {
      executor: 'constant-arrival-rate',
      rate: 1500,          // 🔥 TPS = 1500
      timeUnit: '1s',
      duration: '5m',      // 테스트 시간
      preAllocatedVUs: 300,
      maxVUs: 800,
    },
  },
};

export default function () {
  http.post(
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
    }
  );
}