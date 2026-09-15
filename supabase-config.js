// Fill these in from your Supabase project: Project Settings -> API.
// The anon (public) key is safe to ship to the browser — every table it can
// touch is still gated by the Row Level Security policies in supabase/schema.sql.
const SUPABASE_URL = "https://qepcwjgxskyifmydrnsr.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlcGN3amd4c2t5aWZteWRybnNyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0Mzg5NjQsImV4cCI6MjEwNTAxNDk2NH0.RGBM2dphkNehMVOk-6Zs2KmUJXsxz2TNSwWnCD51X5c";

const SUPABASE_CONFIGURED = !SUPABASE_URL.includes("YOUR-PROJECT-REF");
const sb = SUPABASE_CONFIGURED ? supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY) : null;
