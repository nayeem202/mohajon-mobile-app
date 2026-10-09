import { Injectable, signal } from '@angular/core';

export interface PaymentRow {
  paymentId: string;
  shopId: string;
  internalTransactionId: string;
  gatewayPaymentId: string;
  gatewayTransactionId: string;
  amount: string;
  status: string;
  errorMessage: string;
  createdAt: string;
}

@Injectable({ providedIn: 'root' })
export class PortalApiService {
  private readonly authBase =
    (window as any).__MOHAJON_ADMIN_CONFIG__?.authBaseUrl ?? 'http://localhost:8080';
  private readonly apiBase =
    (window as any).__MOHAJON_ADMIN_CONFIG__?.apiBaseUrl ?? 'http://localhost:8081';
  readonly token = signal(sessionStorage.getItem('mohajon.admin.token') ?? '');
  readonly adminName = signal(sessionStorage.getItem('mohajon.admin.name') ?? '');

  async login(email: string, password: string): Promise<void> {
    const session = await this.request(
      `${this.authBase}/api/v1/auth/login`,
      {
        method: 'POST',
        body: JSON.stringify({
          email,
          password,
          deviceId: 'mohajon-admin-web',
          deviceName: 'Mohajon Admin Portal',
        }),
      },
      false,
    );
    const token = session.accessToken as string;
    if (!token) throw new Error('Sign in did not return an access token.');
    this.token.set(token);
    this.adminName.set(session.user?.name ?? session.user?.displayName ?? email);
    sessionStorage.setItem('mohajon.admin.token', token);
    sessionStorage.setItem('mohajon.admin.name', this.adminName());
    const access = await this.get('/api/v1/platform-admin/access');
    if (access.platformAdmin !== true) {
      this.logout();
      throw new Error('This account is not allowed to use the Mohajon Admin Portal.');
    }
  }

  logout(): void {
    sessionStorage.removeItem('mohajon.admin.token');
    sessionStorage.removeItem('mohajon.admin.name');
    this.token.set('');
    this.adminName.set('');
  }

  get(path: string): Promise<any> {
    return this.request(`${this.apiBase}${path}`, { method: 'GET' });
  }
  post(path: string, body?: unknown): Promise<any> {
    return this.request(`${this.apiBase}${path}`, {
      method: 'POST',
      body: JSON.stringify(body ?? {}),
    });
  }

  async uploadImage(file: File): Promise<{ url: string }> {
    const form = new FormData();
    form.append('file', file);
    const response = await fetch(`${this.apiBase}/api/v1/files`, {
      method: 'POST',
      headers: this.token() ? { Authorization: `Bearer ${this.token()}` } : {},
      body: form,
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data.message ?? data.error ?? `Image upload failed (${response.status})`);
    }
    if (!data.url) throw new Error('Image upload did not return a file URL.');
    return data as { url: string };
  }

  fileUrl(path: string): string {
    return path ? `${this.apiBase}${path}` : '';
  }

  private async request(url: string, init: RequestInit, withToken = true): Promise<any> {
    const response = await fetch(url, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(withToken && this.token() ? { Authorization: `Bearer ${this.token()}` } : {}),
        ...(init.headers ?? {}),
      },
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok)
      throw new Error(data.message ?? data.error ?? `Request failed (${response.status})`);
    return data;
  }
}
