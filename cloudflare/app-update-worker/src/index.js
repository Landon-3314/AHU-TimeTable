const GITHUB_LATEST_MANIFEST_URL =
  'https://github.com/Landon-3314/AHU-TimeTable/releases/latest/download/update.json';

const JSON_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Cache-Control': 'no-store, max-age=0',
  'CDN-Cache-Control': 'no-store',
  'Content-Type': 'application/json; charset=utf-8',
};

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (request.method !== 'GET') {
      return json({ error: 'Method Not Allowed' }, 405);
    }

    if (!['/', '/latest', '/update.json'].includes(url.pathname)) {
      return json({ error: 'Not Found' }, 404);
    }

    try {
      const manifest = await loadLatestManifest();
      return json(manifest);
    } catch (error) {
      console.error('[timetable-update-api] manifest load failed', error);
      return json({ error: 'Unable to load update manifest' }, 502);
    }
  },
};

async function loadLatestManifest() {
  const manifest = await fetchJson(GITHUB_LATEST_MANIFEST_URL, {
    Accept: 'application/json',
    'User-Agent': 'TimetableUpdateWorker',
  });
  validateManifest(manifest);
  return manifest;
}

async function fetchJson(url, headers) {
  const response = await fetch(url, { headers });
  if (!response.ok) {
    throw new Error(`Request failed: ${url} (${response.status})`);
  }
  return response.json();
}

function validateManifest(manifest) {
  if (
    !manifest ||
    typeof manifest.versionName !== 'string' ||
    manifest.versionName.trim() === '' ||
    !Number.isInteger(manifest.versionCode) ||
    manifest.versionCode <= 0 ||
    !Array.isArray(manifest.assets) ||
    manifest.assets.length === 0
  ) {
    throw new Error('Invalid update manifest');
  }

  for (const asset of manifest.assets) {
    validateAsset(asset);
  }
}

function validateAsset(asset) {
  if (
    !asset ||
    typeof asset.abi !== 'string' ||
    asset.abi.trim() === '' ||
    typeof asset.url !== 'string' ||
    !isHttpsUrl(asset.url) ||
    typeof asset.sha256 !== 'string' ||
    !/^[a-fA-F0-9]{64}$/.test(asset.sha256.trim()) ||
    !Number.isInteger(asset.size) ||
    asset.size <= 0 ||
    !validMirrorUrls(asset.mirrorUrls)
  ) {
    throw new Error('Invalid update asset');
  }
}

function validMirrorUrls(mirrorUrls) {
  if (mirrorUrls === undefined) {
    return true;
  }
  return (
    Array.isArray(mirrorUrls) &&
    mirrorUrls.every((mirrorUrl) => {
      return typeof mirrorUrl === 'string' && isHttpsUrl(mirrorUrl);
    })
  );
}

function isHttpsUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname !== '';
  } catch {
    return false;
  }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: JSON_HEADERS,
  });
}
