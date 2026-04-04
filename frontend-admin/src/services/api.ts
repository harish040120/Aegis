// src/services/api.ts

const ML_API_BASE = 'http://localhost:8010';
const HUB_API_BASE = 'http://localhost:3015';

export async function apiGet(path: string, type: 'ML' | 'HUB' = 'ML') {
  const baseUrl = type === 'ML' ? ML_API_BASE : HUB_API_BASE;
  const res = await fetch(`${baseUrl}${path}`);
  if (!res.ok) throw new Error(`API error ${res.status}: ${res.statusText}`);
  return res.json();
}

export async function apiPost(path: string, body: any, type: 'ML' | 'HUB' = 'ML') {
  const baseUrl = type === 'ML' ? ML_API_BASE : HUB_API_BASE;
  const res = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  if (!res.ok) throw new Error(`API error ${res.status}: ${res.statusText}`);
  return res.json();
}

export async function apiPatch(path: string, body: any, type: 'ML' | 'HUB' = 'ML') {
  const baseUrl = type === 'ML' ? ML_API_BASE : HUB_API_BASE;
  const res = await fetch(`${baseUrl}${path}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  if (!res.ok) throw new Error(`API error ${res.status}: ${res.statusText}`);
  return res.json();
}
