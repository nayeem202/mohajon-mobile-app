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
  private readonly refreshToken = signal(sessionStorage.getItem('mohajon.admin.refresh-token') ?? '');
  readonly adminName = signal(sessionStorage.getItem('mohajon.admin.name') ?? '');
  private refreshInFlight: Promise<boolean> | null = null;

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
    this.refreshToken.set(session.refreshToken ?? '');
    this.adminName.set(session.user?.name ?? session.user?.displayName ?? email);
    sessionStorage.setItem('mohajon.admin.token', token);
    if (session.refreshToken) {
      sessionStorage.setItem('mohajon.admin.refresh-token', session.refreshToken);
    } else {
      sessionStorage.removeItem('mohajon.admin.refresh-token');
    }
    sessionStorage.setItem('mohajon.admin.name', this.adminName());
    const access = await this.get('/api/v1/platform-admin/access');
    if (access.platformAdmin !== true) {
      this.logout();
      throw new Error('This account is not allowed to use the Mohajon Admin Portal.');
    }
  }

  requestPasswordReset(email: string): Promise<any> {
    return this.request(
      `${this.authBase}/api/v1/auth/forgot-password`,
      { method: 'POST', body: JSON.stringify({ email }) },
      false,
    );
  }

  resetPassword(email: string, code: string, newPassword: string): Promise<any> {
    return this.request(
      `${this.authBase}/api/v1/auth/reset-password`,
      { method: 'POST', body: JSON.stringify({ email, code, newPassword }) },
      false,
    );
  }

  logout(): void {
    sessionStorage.removeItem('mohajon.admin.token');
    sessionStorage.removeItem('mohajon.admin.refresh-token');
    sessionStorage.removeItem('mohajon.admin.name');
    this.token.set('');
    this.refreshToken.set('');
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
    let response = await this.fetchRequest(url, init, withToken);
    if (response.status === 401 && withToken && this.refreshToken()) {
      const refreshed = await this.refreshSession();
      if (refreshed) response = await this.fetchRequest(url, init, true);
      else {
        this.logout();
        throw new Error('Your admin session expired. Please sign in again.');
      }
    }
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      if (response.status === 401 && withToken) {
        this.logout();
        throw new Error('Your admin session is no longer valid. Please sign in again.');
      }
      throw new Error(data.message ?? data.error ?? `Request failed (${response.status})`);
    }
    return data;
  }

  private async fetchRequest(url: string, init: RequestInit, withToken: boolean): Promise<Response> {
    return fetch(url, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(withToken && this.token() ? { Authorization: `Bearer ${this.token()}` } : {}),
        ...(init.headers ?? {}),
      },
    });
  }

  private refreshSession(): Promise<boolean> {
    if (this.refreshInFlight) return this.refreshInFlight;
    const refreshToken = this.refreshToken();
    if (!refreshToken) return Promise.resolve(false);

    this.refreshInFlight = (async () => {
      try {
        const response = await fetch(`${this.authBase}/api/v1/auth/refresh`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refreshToken }),
        });
        if (!response.ok) return false;
        const session = await response.json();
        if (!session.accessToken || !session.refreshToken) return false;
        this.token.set(session.accessToken);
        this.refreshToken.set(session.refreshToken);
        sessionStorage.setItem('mohajon.admin.token', session.accessToken);
        sessionStorage.setItem('mohajon.admin.refresh-token', session.refreshToken);
        if (session.user?.name || session.user?.displayName) {
          this.adminName.set(session.user.name ?? session.user.displayName);
          sessionStorage.setItem('mohajon.admin.name', this.adminName());
        }
        return true;
      } catch {
        return false;
      } finally {
        this.refreshInFlight = null;
      }
    })();
    return this.refreshInFlight;
  }
}
