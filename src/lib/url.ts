export interface NormalizedUrl {
  normalized: string;
  error: string | null;
}

export function isValidUrlScheme(url: URL): boolean {
  return url.protocol === 'http:' || url.protocol === 'https:';
}

export function normalizeUrl(input: string): NormalizedUrl {
  let parsed: URL;
  try {
    parsed = new URL(input.trim());
  } catch {
    return { normalized: '', error: 'Invalid URL format' };
  }

  if (!isValidUrlScheme(parsed)) {
    return { normalized: '', error: `Unsupported scheme: ${parsed.protocol}` };
  }

  let normalized = parsed.protocol.toLowerCase() + '//' + parsed.hostname.toLowerCase();

  if (parsed.port) {
    normalized += ':' + parsed.port;
  }

  let pathname = parsed.pathname;
  if (pathname.length > 1 && pathname.endsWith('/')) {
    pathname = pathname.replace(/\/+$/, '');
  }
  normalized += pathname;

  if (parsed.search) {
    normalized += parsed.search;
  }

  return { normalized, error: null };
}
