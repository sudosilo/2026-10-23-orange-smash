export const config = { runtime: 'edge' };

// Public Supabase settings for the page. The anon key is meant to be public; row level security protects the data.
export default function handler() {
  return new Response(JSON.stringify({
    supabaseUrl: process.env.SUPABASE_URL || null,
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || null
  }), { status: 200, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });
}
