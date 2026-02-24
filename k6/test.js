import http from 'k6/http';
import { check, sleep } from 'k6';

/**
 * 운영 분석용 옵션
 * - 모든 percentile 출력
 * - endpoint / method 별 latency 분리
 * - TPS, dropped iteration까지 명확히 보이게
 */
// export let options = {
//     scenarios: {
//         load_test: {
//             executor: 'constant-arrival-rate',
//             rate: 6600,              // 목표 iteration/s (GET+POST 1쌍)
//             timeUnit: '1s',
//             duration: '3m',
//             preAllocatedVUs: 2000,
//             maxVUs: 8000,            // ⚠️ 한계 보려면 여유 있게
//         },
//     },

export let options = {
    scenarios: {
        load_test: {
            executor: 'constant-arrival-rate',
            rate: 250,              // 목표 iteration/s (GET+POST 1쌍)
            timeUnit: '1s',
            duration: '3m',
            preAllocatedVUs: 300,
            maxVUs: 1500,            // ⚠️ 한계 보려면 여유 있게
        },
    },

    // 🔹 percentile 전부 출력
    summaryTrendStats: [
        'min',
        'avg',
        'med',      // p50
        'p(75)',
        'p(90)',
        'p(95)',
        'p(99)',
        'max',
    ],

    thresholds: {
        http_req_failed: ['rate<0.01'],

        // 전체
        http_req_duration: ['p(95)<500'],

        // GET / POST 분리 기준 (태그 기반)
        'http_req_duration{endpoint:GET_products}': ['p(95)<300'],
        'http_req_duration{endpoint:POST_orders}': ['p(95)<800'],
    },
};

export default function () {
    /* =========================
       1️⃣ GET /products
       ========================= */
    const getRes = http.get(
        'https://backend.olive0.cloud/oliveyoung/api/products',
        {
            tags: {
                endpoint: 'GET_products',
                method: 'GET',
            },
        }
    );

    check(getRes, {
        'GET /products status 200': (r) => r.status === 200,
    });

    // 실사용자 think time (아주 짧게)
    sleep(0.01);

    /* =========================
       2️⃣ POST /orders/complete
       ========================= */
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

    const postRes = http.post(
        'https://backend.olive0.cloud/oliveyoung/api/orders/complete',
        payload,
        params
    );

    check(postRes, {
        'POST /orders/complete status 200': (r) => r.status === 200,
    });
}