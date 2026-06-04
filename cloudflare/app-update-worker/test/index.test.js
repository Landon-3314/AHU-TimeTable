import assert from 'node:assert/strict';
import test from 'node:test';

import worker from '../src/index.js';

const validManifest = {
  versionName: '0.3.6',
  versionCode: 2004,
  baseVersionCode: 4,
  releaseNotes: '安课 0.3.6 更新。',
  assets: [
    {
      abi: 'arm64-v8a',
      url: 'https://github.com/Landon-3314/AHU-TimeTable/releases/download/v0.3.6%2B4/timetable-0.3.6%2B4-arm64-v8a.apk',
      sha256: 'b'.repeat(64),
      size: 2048,
      versionCode: 2004,
    },
  ],
};

test('GET /latest returns the release manifest with no-store headers', async () => {
  const requestedUrls = [];
  const response = await withMockedFetch(
    [jsonResponse(validManifest)],
    requestedUrls,
    () => worker.fetch(new Request('https://update.277620035.xyz/latest')),
  );

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Cache-Control'), 'no-store, max-age=0');
  assert.equal(response.headers.get('CDN-Cache-Control'), 'no-store');
  assert.deepEqual(requestedUrls, [
    'https://github.com/Landon-3314/AHU-TimeTable/releases/latest/download/update.json',
  ]);
  assert.deepEqual(await response.json(), validManifest);
});

test('GET /update.json is an alias for the latest manifest', async () => {
  const response = await withMockedFetch(
    [jsonResponse(validManifest)],
    [],
    () => worker.fetch(new Request('https://update.277620035.xyz/update.json')),
  );

  assert.equal(response.status, 200);
  const manifest = await response.json();
  assert.equal(manifest.versionCode, 2004);
  assert.equal(manifest.baseVersionCode, 4);
  assert.equal(manifest.assets[0].versionCode, 2004);
});

test('returns 502 when latest release manifest download fails', async () => {
  const response = await withMockedFetch(
    [jsonResponse({ error: 'not found' }, 404)],
    [],
    () => worker.fetch(new Request('https://update.277620035.xyz/latest')),
  );

  assert.equal(response.status, 502);
  assert.equal((await response.json()).error, 'Unable to load update manifest');
});

test('returns 502 when update manifest is invalid', async () => {
  const response = await withMockedFetch(
    [jsonResponse({ versionName: '0.3.6', versionCode: 4, assets: [] })],
    [],
    () => worker.fetch(new Request('https://update.277620035.xyz/latest')),
  );

  assert.equal(response.status, 502);
  assert.equal((await response.json()).error, 'Unable to load update manifest');
});

test('returns 502 when split APK version metadata is invalid', async () => {
  for (const manifest of [
    { ...validManifest, baseVersionCode: 0 },
    {
      ...validManifest,
      assets: [{ ...validManifest.assets[0], versionCode: 0 }],
    },
  ]) {
    const response = await withMockedFetch(
      [jsonResponse(manifest)],
      [],
      () => worker.fetch(new Request('https://update.277620035.xyz/latest')),
    );

    assert.equal(response.status, 502);
    assert.equal((await response.json()).error, 'Unable to load update manifest');
  }
});

test('returns 405 for non-GET requests', async () => {
  const response = await worker.fetch(
    new Request('https://update.277620035.xyz/latest', { method: 'POST' }),
  );

  assert.equal(response.status, 405);
});

test('returns 404 for unknown paths', async () => {
  const response = await worker.fetch(
    new Request('https://update.277620035.xyz/missing'),
  );

  assert.equal(response.status, 404);
});

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function withMockedFetch(responses, requestedUrls, callback) {
  const originalFetch = globalThis.fetch;
  const originalConsoleError = console.error;
  const queue = [...responses];
  globalThis.fetch = async (url) => {
    requestedUrls.push(url.toString());
    const response = queue.shift();
    if (!response) {
      throw new Error('Unexpected fetch call');
    }
    return response;
  };
  console.error = () => {};
  try {
    return await callback();
  } finally {
    globalThis.fetch = originalFetch;
    console.error = originalConsoleError;
  }
}
