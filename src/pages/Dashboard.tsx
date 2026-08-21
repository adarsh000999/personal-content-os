import { useState, useEffect, useCallback, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { supabase } from '@/lib/supabase';
import { normalizeUrl } from '@/lib/url';
import { LogOut, Link2, Loader2, AlertCircle, CheckCircle2 } from 'lucide-react';

interface ContentItem {
  id: string;
  original_url: string;
  title: string | null;
  processing_status: string;
  created_at: string;
}

const STATUS_COLORS: Record<string, string> = {
  PENDING: 'bg-yellow-100 text-yellow-800',
  EXTRACTING: 'bg-blue-100 text-blue-800',
  ANALYZING: 'bg-indigo-100 text-indigo-800',
  COMPLETED: 'bg-green-100 text-green-800',
  PARTIALLY_COMPLETED: 'bg-teal-100 text-teal-800',
  EXTRACTION_FAILED: 'bg-red-100 text-red-800',
  AI_FAILED: 'bg-orange-100 text-orange-800',
};

export default function Dashboard() {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();

  const [url, setUrl] = useState('');
  const [capturing, setCapturing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [items, setItems] = useState<ContentItem[]>([]);
  const [loadingFeed, setLoadingFeed] = useState(true);

  const fetchContent = useCallback(async () => {
    setLoadingFeed(true);
    const { data, error: fetchError } = await supabase
      .from('content')
      .select('id, original_url, title, processing_status, created_at')
      .eq('user_id', user?.id)
      .order('created_at', { ascending: false })
      .limit(50);

    if (fetchError) {
      setError(fetchError.message);
    } else {
      setItems(data ?? []);
    }
    setLoadingFeed(false);
  }, [user?.id]);

  useEffect(() => {
    fetchContent();
  }, [fetchContent]);

  const handleSignOut = async () => {
    await signOut();
    navigate('/login');
  };

  const handleCapture = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(null);

    const { normalized, error: normError } = normalizeUrl(url);
    if (normError) {
      setError(normError);
      return;
    }

    setCapturing(true);
    try {
      const { error: rpcError } = await supabase.rpc('capture_url', {
        p_original_url: url.trim(),
        p_normalized_url: normalized,
      });

      if (rpcError) {
        if (rpcError.code === '23505') {
          setError('This URL has already been captured.');
        } else {
          setError(rpcError.message);
        }
        return;
      }

      setSuccess('URL captured and queued for processing.');
      setUrl('');
      await fetchContent();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An unexpected error occurred.');
    } finally {
      setCapturing(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-3xl mx-auto px-4 py-4 flex items-center justify-between">
          <h1 className="text-lg font-bold text-gray-900">Personal Content OS</h1>
          <div className="flex items-center gap-4">
            <span className="text-sm text-gray-500 hidden sm:inline">{user?.email}</span>
            <button
              onClick={handleSignOut}
              className="flex items-center gap-1.5 text-sm text-gray-600 hover:text-gray-900 transition-colors"
            >
              <LogOut className="w-4 h-4" />
              Sign Out
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-3xl mx-auto px-4 py-8">
        <section className="mb-8">
          <h2 className="text-sm font-semibold text-gray-700 mb-3">Capture a URL</h2>
          <form onSubmit={handleCapture} className="space-y-3">
            <div className="flex gap-2">
              <div className="relative flex-1">
                <Link2 className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  type="url"
                  value={url}
                  onChange={(e) => setUrl(e.target.value)}
                  placeholder="https://example.com/article"
                  required
                  disabled={capturing}
                  className="w-full pl-10 pr-3 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent disabled:opacity-50"
                />
              </div>
              <button
                type="submit"
                disabled={capturing || !url.trim()}
                className="flex items-center gap-2 px-4 py-2.5 bg-gray-900 text-white text-sm font-medium rounded-lg hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                {capturing ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
                {capturing ? 'Capturing...' : 'Capture'}
              </button>
            </div>

            {error && (
              <div className="flex items-center gap-2 text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                {error}
              </div>
            )}

            {success && (
              <div className="flex items-center gap-2 text-sm text-green-700 bg-green-50 border border-green-200 rounded-lg px-3 py-2">
                <CheckCircle2 className="w-4 h-4 shrink-0" />
                {success}
              </div>
            )}
          </form>
        </section>

        <section>
          <h2 className="text-sm font-semibold text-gray-700 mb-3">Captured Content</h2>

          {loadingFeed ? (
            <div className="flex items-center justify-center py-12">
              <Loader2 className="w-5 h-5 text-gray-400 animate-spin" />
            </div>
          ) : items.length === 0 ? (
            <p className="text-sm text-gray-400 py-12 text-center">
              No content captured yet. Paste a URL above to get started.
            </p>
          ) : (
            <ul className="space-y-2">
              {items.map((item) => (
                <li
                  key={item.id}
                  className="bg-white border border-gray-200 rounded-lg p-4 flex items-start justify-between gap-4"
                >
                  <div className="min-w-0 flex-1">
                    <a
                      href={item.original_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-sm font-medium text-gray-900 hover:underline truncate block"
                    >
                      {item.title || item.original_url}
                    </a>
                    {!item.title && (
                      <p className="text-xs text-gray-400 truncate mt-0.5">{item.original_url}</p>
                    )}
                    <p className="text-xs text-gray-400 mt-1">
                      {new Date(item.created_at).toLocaleString()}
                    </p>
                  </div>
                  <span
                    className={`text-xs font-medium px-2 py-1 rounded-full whitespace-nowrap ${
                      STATUS_COLORS[item.processing_status] || 'bg-gray-100 text-gray-600'
                    }`}
                  >
                    {item.processing_status}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </main>
    </div>
  );
}
