import http from 'k6/http';
import { check } from 'k6';

/**
 * 운영 분석용 옵션
 * - POST /orders/complete 단일 엔드포인트
 * - rate = 곧 TPS
 * - dropped iteration / latency 한계 확인용
 */
export let options = {
    scenarios: {
        load_test: {
            executor: 'constant-arrival-rate',
            rate: 6600,              // 🎯 목표 POST TPS
            timeUnit: '1s',
            duration: '3m',
            preAllocatedVUs: 2000,
            maxVUs: 8000,            // 한계 확인용
        },
    },

    summaryTrendStats: [
        'min',
        'avg',
        'med',
        'p(75)',
        'p(90)',
        'p(95)',
        'p(99)',
        'max',
    ],

    thresholds: {
        http_req_failed: ['rate<0.01'],

        // POST 단일 기준
        http_req_duration: ['p(95)<800'],
        'http_req_duration{endpoint:POST_orders}': ['p(95)<800'],
    },
};

export default function () {
    const payload = JSON.stringify({
        productId: 12345,
        quantity: 2,
        isTodayDelivery: true,
        totalPrice: 45000,
        username: 'john_doe',
        phone: '010-1234-5678',
        deliveryTimeSlot: '14:00-16:00',
    });

    const params = {
        headers: { 'Content-Type': 'application/json' },
        tags: {
            endpoint: 'POST_orders',
            method: 'POST',
        },
    };

    const res = http.post(
        'https://backend.olive0.cloud/oliveyoung/api/orders/complete',
        payload,
        params
    );

    check(res, {
        'POST /orders/complete status 200': (r) => r.status === 200,
    });
}