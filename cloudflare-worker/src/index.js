const TMDB_ORIGIN = 'https://api.themoviedb.org';

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: corsHeaders() });
    if (request.method !== 'GET') return json({ message: 'Method not allowed' }, 405);
    if (!env.TMDB_ACCESS_TOKEN) return json({ message: 'TMDB_ACCESS_TOKEN secret is missing' }, 500);

    const incoming = new URL(request.url);
    if (!incoming.pathname.startsWith('/3/')) return json({ message: 'Only TMDB /3/* endpoints are allowed' }, 404);

    const target = new URL(`${TMDB_ORIGIN}${incoming.pathname}`);
    incoming.searchParams.forEach((value, key) => target.searchParams.set(key, value));

    const cache = caches.default;
    const cacheKey = new Request(incoming.toString(), { method: 'GET' });
    const cached = await cache.match(cacheKey);
    if (cached) return withCors(cached);

    const upstream = await fetch(target, {
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${env.TMDB_ACCESS_TOKEN}`,
      },
    });

    const response = new Response(upstream.body, upstream);
    response.headers.set('Cache-Control', upstream.ok ? 'public, max-age=300' : 'no-store');
    Object.entries(corsHeaders()).forEach(([key, value]) => response.headers.set(key, value));

    if (upstream.ok) ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  };
}

function withCors(response) {
  const copy = new Response(response.body, response);
  Object.entries(corsHeaders()).forEach(([key, value]) => copy.headers.set(key, value));
  return copy;
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', ...corsHeaders() },
  });
}
