import { createClient } from '@supabase/supabase-js';
import type { Database } from '../../../shared/database.types';

const supabaseUrl = 'https://hokfbsubpcckffqhxfoj.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhva2Zic3VicGNja2ZmcWh4Zm9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNDQxMDcsImV4cCI6MjA1OTYyMDEwN30.hX7bTti8Hb4Zs7gMf2aLq6y99r_KOXVEJHBaqkA5lgQ';

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey);

