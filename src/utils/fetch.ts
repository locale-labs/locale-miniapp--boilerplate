/**
 * Helper to perform authenticated requests to Supabase or other APIs.
 * Automatically injects the Bearer token into the Authorization header.
 */
export async function authenticatedFetch(
  url: string,
  token: string | null,
  options: RequestInit = {},
  apiKey?: string
): Promise<Response> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string>),
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  if (apiKey && !headers['apikey']) {
    headers['apikey'] = apiKey;
  }

  return fetch(url, {
    ...options,
    headers,
  });
}
