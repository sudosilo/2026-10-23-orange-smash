export const config = { runtime: 'edge' };

const JSON_HEADERS = { 'content-type': 'application/json' };
const LRCLIB = 'https://lrclib.net/api';
const UA = 'LyricSmash/1.0';

export default async function handler(request) {
  const params = new URL(request.url).searchParams;
  const q = (params.get('q') || '').trim();
  const title = (params.get('title') || '').trim();
  const artist = (params.get('artist') || '').trim();
  const duration = params.get('duration');

  try {
    if (title && artist) {
      const getUrl = LRCLIB + '/get?track_name=' + encodeURIComponent(title) +
        '&artist_name=' + encodeURIComponent(artist) +
        (duration ? '&duration=' + encodeURIComponent(Math.round(Number(duration))) : '');
      const direct = await fetch(getUrl, { headers: { 'User-Agent': UA } });
      if (direct.ok) {
        const row = await direct.json();
        if (row && row.syncedLyrics) return reply({ results: [shape(row)] });
      }
      const fallback = await search('track_name=' + encodeURIComponent(title) + '&artist_name=' + encodeURIComponent(artist));
      return reply({ results: fallback });
    }

    if (!q) return reply({ error: 'missing q, or title and artist', results: [] }, 400);
    return reply({ results: await search('q=' + encodeURIComponent(q)) });
  } catch (err) {
    return reply({ error: 'lrclib request failed', results: [] });
  }
}

async function search(queryString) {
  const res = await fetch(LRCLIB + '/search?' + queryString, { headers: { 'User-Agent': UA } });
  if (!res.ok) return [];
  const rows = await res.json();
  return (Array.isArray(rows) ? rows : [])
    .filter(r => r && r.syncedLyrics)
    .slice(0, 15)
    .map(shape);
}

function shape(r) {
  return {
    id: r.id,
    title: r.trackName,
    artist: r.artistName,
    album: r.albumName,
    durationSeconds: r.duration,
    synced: r.syncedLyrics
  };
}

function reply(body, status) {
  return new Response(JSON.stringify(body), { status: status || 200, headers: JSON_HEADERS });
}
