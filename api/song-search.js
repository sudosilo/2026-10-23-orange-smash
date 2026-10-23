export const config = { runtime: 'edge' };

const JSON_HEADERS = { 'content-type': 'application/json' };

export default async function handler(request) {
  const params = new URL(request.url).searchParams;
  const text = (params.get('q') || '').trim();
  const bpm = parseFloat(params.get('bpm'));
  const spread = Math.min(10, Math.max(0.5, parseFloat(params.get('spread')) || 2));

  if (!text && !(bpm > 0)) return reply({ error: 'missing q or bpm', results: [] }, 400);

  let query = text;
  if (bpm > 0) {
    const lo = Math.floor(bpm - spread), hi = Math.ceil(bpm + spread);
    query = (text ? text + ' ' : '') + 'bpm_min:"' + lo + '" bpm_max:"' + hi + '"';
  }

  try {
    const res = await fetch('https://api.deezer.com/search?limit=40&q=' + encodeURIComponent(query));
    if (!res.ok) return reply({ error: 'deezer http ' + res.status, results: [] });
    const data = await res.json();
    if (data && data.error) return reply({ error: 'deezer: ' + (data.error.message || 'error'), results: [] });
    const seen = new Set();
    const results = (Array.isArray(data.data) ? data.data : [])
      .filter(r => r && r.title && r.artist)
      .filter(r => {
        const k = (r.title_short || r.title).toLowerCase() + '|' + r.artist.name.toLowerCase();
        if (seen.has(k)) return false;
        seen.add(k);
        return true;
      })
      .map(r => ({
        id: r.id,
        title: r.title_short || r.title,
        artist: r.artist.name,
        album: r.album ? r.album.title : null,
        durationSeconds: r.duration || null
      }));
    return reply({ query, results });
  } catch (err) {
    return reply({ error: 'deezer unreachable', results: [] });
  }
}

function reply(body, status) {
  return new Response(JSON.stringify(body), { status: status || 200, headers: JSON_HEADERS });
}
